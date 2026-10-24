import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/ledger_repository.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/transactions/data/templates_repository.dart';
import 'package:personal_finance/features/transactions/data/txn_actions.dart';
import 'package:personal_finance/features/transactions/presentation/quick_add.dart';

/// Shows a SnackBar with an Undo action. Replaces any visible SnackBar.
void showUndoSnackBar(
  ScaffoldMessengerState? messenger,
  String message, {
  required Future<void> Function() onUndo,
  required String undoLabel,
}) {
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: undoLabel,
          onPressed: () => unawaited(onUndo()),
        ),
      ),
    );
}

void showInfoSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
}

/// Deletes [ids] after confirmation (Settings › Entry › Confirm delete) and
/// offers undo. Returns whether anything was deleted.
Future<bool> deleteTransactionsWithUndo(
  BuildContext context,
  WidgetRef ref,
  List<String> ids,
) async {
  if (ids.isEmpty) return false;
  final l = context.l10n;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final confirm = ref.read(settingsProvider).get(EntrySettings.confirmDelete);
  if (confirm) {
    final ok = await confirmDialog(
      context,
      title: l.txnDeleteConfirmTitle(ids.length),
      message: l.txnDeleteConfirmBody,
    );
    if (!ok) return false;
  }
  final actions = ref.read(txnActionsProvider);
  try {
    final deleted = await actions.delete(ids);
    showUndoSnackBar(
      messenger,
      l.txnDeleted(deleted.length),
      undoLabel: l.commonUndo,
      onUndo: () => actions.undoDelete(deleted),
    );
    return true;
  } on Object catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text(l.commonError('$e'))));
    return false;
  }
}

/// Opens quick add pre-filled with a copy of [id] dated today.
Future<void> duplicateInQuickAdd(
  BuildContext context,
  WidgetRef ref,
  String id,
) async {
  final actions = ref.read(txnActionsProvider);
  final key = await actions.editableId(id);
  if (key == null) return;
  final draft = await ref.read(ledgerRepositoryProvider).draftFor(key);
  if (draft == null || !context.mounted) return;
  await showQuickAdd(context, initial: duplicateDraft(draft));
}

/// A copy of [d] for "duplicate": today's date, cleared bookkeeping.
TxnDraft duplicateDraft(TxnDraft d) => d.copyWith(
  date: dateOnly(DateTime.now()),
  status: d.status == TxnStatus.planned ? TxnStatus.cleared : d.status,
  recurringRuleId: null,
  importBatchId: null,
  importRowRef: null,
  dedupeHash: null,
);

/// Toggles cleared/pending with undo.
Future<void> toggleClearedWithUndo(
  BuildContext context,
  WidgetRef ref,
  String id,
) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final actions = ref.read(txnActionsProvider);
  final snap = await actions.toggleCleared(id);
  showUndoSnackBar(
    messenger,
    l.txnStatusChanged,
    undoLabel: l.commonUndo,
    onUndo: () => actions.restoreSnapshot(snap),
  );
}

/// Sets [status] on [ids] with undo.
Future<void> setStatusWithUndo(
  BuildContext context,
  WidgetRef ref,
  List<String> ids,
  TxnStatus status,
) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final actions = ref.read(txnActionsProvider);
  final snap = await actions.bulkUpdate(ids, status: status);
  showUndoSnackBar(
    messenger,
    ids.length == 1 ? l.txnStatusChanged : l.txnBulkUpdated(ids.length),
    undoLabel: l.commonUndo,
    onUndo: () => actions.restoreSnapshot(snap),
  );
}

/// Asks for a name and stores transaction [id] as a template.
Future<void> saveAsTemplate(
  BuildContext context,
  WidgetRef ref,
  String id,
) async {
  final l = context.l10n;
  final actions = ref.read(txnActionsProvider);
  final key = await actions.editableId(id);
  if (key == null) return;
  final draft = await ref.read(ledgerRepositoryProvider).draftFor(key);
  if (draft == null || !context.mounted) return;
  final name = await promptName(
    context,
    title: l.txnSaveAsTemplate,
    label: l.txnTemplateName,
    initial: draft.payee ?? '',
  );
  if (name == null || !context.mounted) return;
  await ref.read(templatesRepositoryProvider).create(name, draft);
  if (context.mounted) showInfoSnackBar(context, l.txnTemplateSaved);
}

/// Text prompt dialog; returns the trimmed text or null when cancelled.
Future<String?> promptName(
  BuildContext context, {
  required String title,
  required String label,
  String initial = '',
  String? confirmLabel,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _NameDialog(
      title: title,
      label: label,
      initial: initial,
      confirmLabel: confirmLabel,
    ),
  );
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.title,
    required this.label,
    required this.initial,
    this.confirmLabel,
  });

  final String title;
  final String label;
  final String initial;
  final String? confirmLabel;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _c = TextEditingController(text: widget.initial)
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initial.length,
    );
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _c.text.trim();
    if (v.isEmpty) {
      setState(() => _error = context.l10n.txnNameRequired);
      return;
    }
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _c,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(labelText: widget.label, errorText: _error),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.confirmLabel ?? l.commonSave),
        ),
      ],
    );
  }
}
