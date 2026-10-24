import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/accounts/data/accounts_repository.dart';
import 'package:personal_finance/features/categories/presentation/appearance_pickers.dart';

/// Archives or restores [account] and confirms with an undo snackbar.
Future<void> setAccountArchived(
  BuildContext context,
  WidgetRef ref,
  Account account, {
  required bool archived,
}) async {
  final l = context.l10n;
  final repo = ref.read(accountsRepositoryProvider);
  try {
    await repo.setArchived(account.id, archived: archived);
  } on Exception catch (e) {
    if (context.mounted) showSnack(context, l.commonError(e.toString()));
    return;
  }
  if (!context.mounted) return;
  showSnack(
    context,
    archived ? l.accountsArchivedSnack : l.accountsUnarchivedSnack,
    action: SnackBarAction(
      label: l.commonUndo,
      onPressed: () => repo.setArchived(account.id, archived: !archived),
    ),
  );
}

/// Deletes [account] after confirmation. Accounts with transactions cannot
/// be deleted; the user is offered to archive them instead. Returns true
/// when the account was deleted.
Future<bool> deleteAccountFlow(
  BuildContext context,
  WidgetRef ref,
  Account account,
) async {
  final l = context.l10n;
  final repo = ref.read(accountsRepositoryProvider);
  final usage = await repo.usage(account.id);
  if (!context.mounted) return false;
  if (usage.inUse) {
    final archive = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.accountsCannotDeleteTitle),
        content: Text(
          usage.transactions > 0
              ? l.accountsDeleteInUse(usage.transactions)
              : l.accountsDeleteInUseRules(usage.recurringRules),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.commonCancel),
          ),
          if (!account.archived)
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.accountsArchive),
            ),
        ],
      ),
    );
    if ((archive ?? false) && context.mounted) {
      await setAccountArchived(context, ref, account, archived: true);
    }
    return false;
  }
  final confirm = ref.read(settingsProvider).get(EntrySettings.confirmDelete);
  if (confirm) {
    final ok = await confirmDialog(
      context,
      title: l.commonDeleteConfirm(account.name),
      message: l.accountsDeleteMessage,
    );
    if (!ok) return false;
  }
  try {
    await repo.delete(account.id);
  } on Exception catch (e) {
    if (context.mounted) showSnack(context, l.commonError(e.toString()));
    return false;
  }
  if (context.mounted) {
    showSnack(
      context,
      l.accountsDeleted,
      action: SnackBarAction(
        label: l.commonUndo,
        onPressed: () => repo.restore(account.id),
      ),
    );
  }
  return true;
}
