import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/core/attachments/receipt_store.dart';
import 'package:personal_finance/core/csv/file_output.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/ledger/lookups.dart';
import 'package:personal_finance/core/platform/capabilities.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/export/data/backup_service.dart';
import 'package:personal_finance/features/export/data/bundle_service.dart';
import 'package:personal_finance/features/export/domain/bundle_manifest.dart';
import 'package:personal_finance/features/export/presentation/export_labels.dart';

/// File name for a manual backup.
String backupFileName(DateTime now) =>
    'personal-finance-backup-${DateFormat('yyyyMMdd-HHmmss').format(now)}.zip';

/// Creates a verified backup and hands it to save/share/download. Returns
/// the save outcome, or null on error (a snackbar is shown).
Future<SaveResult?> createBackup(
  BuildContext context,
  WidgetRef ref, {
  Rect? origin,
}) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    final backup = await createVerifiedBackup(ref.read);
    final r = await saveOrShareBytes(
      bytes: backup.bytes,
      fileName: backupFileName(DateTime.now()),
      mimeType: 'application/zip',
      capabilities: ref.read(platformCapabilitiesProvider),
      sharePositionOrigin: origin,
    );
    if (r.ok) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            backup.manifest.missingFiles.isEmpty
                ? l.exportBackupDone(backup.manifest.totalRows)
                : l.backupMissingReceipts(backup.manifest.missingFiles.length),
          ),
        ),
      );
    }
    return r;
  } on Object catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text(l.exportFailed('$e'))));
    return null;
  }
}

/// Pick → validate → summary → confirm (destructive, optional safety
/// backup) → restore in one transaction → refresh.
Future<void> startRestore(
  BuildContext context,
  WidgetRef ref, {
  Rect? origin,
}) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final picked = await pickFileBytes(extensions: const ['zip']);
  if (picked == null || !context.mounted) return;

  final db = ref.read(databaseProvider);
  BundleContents contents;
  try {
    contents = readBundle(db, picked.bytes);
  } on BundleException catch (e) {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.error_outline, color: ctx.colors.error),
        title: Text(l.exportErrTitle),
        content: Text(bundleErrorMessage(l, e)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.commonClose),
          ),
        ],
      ),
    );
    return;
  }
  if (!context.mounted) return;

  final backupFirst = await showDialog<bool>(
    context: context,
    builder: (ctx) => _RestoreSummaryDialog(
      manifest: contents.manifest,
      fileName: picked.name,
      thisDevice: contents.manifest.deviceId == ref.read(deviceIdProvider),
    ),
  );
  if (backupFirst == null || !context.mounted) {
    messenger?.showSnackBar(SnackBar(content: Text(l.exportRestoreAborted)));
    return;
  }

  if (backupFirst) {
    final saved = await createBackup(context, ref, origin: origin);
    if (saved == null || !saved.ok) {
      messenger?.showSnackBar(SnackBar(content: Text(l.exportRestoreAborted)));
      return;
    }
  }
  if (!context.mounted) return;

  final navigator = Navigator.of(context, rootNavigator: true);
  // Modal progress while the transaction runs.
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator.adaptive(),
            const SizedBox(width: Space.md),
            Expanded(child: Text(l.exportWorking)),
          ],
        ),
      ),
    ),
  ).ignore();
  try {
    final rows = await restoreBundle(
      db,
      contents,
      clock: ref.read(hlcClockProvider),
      receipts: ref.read(receiptStoreProvider),
    );
    navigator.pop();
    await refreshAfterDataReplace(ref);
    messenger?.showSnackBar(SnackBar(content: Text(l.exportRestoreDone(rows))));
  } on Object catch (e) {
    navigator.pop();
    messenger?.showSnackBar(
      SnackBar(content: Text(l.exportRestoreFailed('$e'))),
    );
  }
}

/// Refreshes state after all data was replaced (restore/reset): drift
/// streams re-query on their own (the restore marks all tables updated);
/// this also re-subscribes the shared lookups and mirrors bootstrap
/// settings (theme, language...) to shared preferences for the next start.
Future<void> refreshAfterDataReplace(WidgetRef ref) async {
  ref
    ..invalidate(accountsProvider)
    ..invalidate(accountGroupsProvider)
    ..invalidate(categoriesProvider)
    ..invalidate(tagsProvider)
    ..invalidate(customFieldDefsProvider)
    ..invalidate(accountBalancesProvider);
  final prefs = ref.read(sharedPreferencesProvider);
  if (prefs == null) return;
  final snapshot = await loadSettings(ref.read(databaseProvider));
  for (final def in allSettings.where((d) => d.bootstrap)) {
    if (def.key == DataSettings.storageLocation.key) continue;
    if (snapshot.isSet(def)) {
      await prefs.setString(
        def.key,
        jsonEncode(def.encodeValue(snapshot.get(def))),
      );
    } else {
      await prefs.remove(def.key);
    }
  }
}

/// Shows the bundle summary. Pops `true`/`false` (= save a safety backup
/// first) when confirmed, null when cancelled.
class _RestoreSummaryDialog extends ConsumerStatefulWidget {
  const _RestoreSummaryDialog({
    required this.manifest,
    required this.fileName,
    required this.thisDevice,
  });

  final BundleManifest manifest;
  final String fileName;
  final bool thisDevice;

  @override
  ConsumerState<_RestoreSummaryDialog> createState() =>
      _RestoreSummaryDialogState();
}

class _RestoreSummaryDialogState extends ConsumerState<_RestoreSummaryDialog> {
  bool _backupFirst = true;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final dates = ref.watch(dateFormatsProvider);
    final m = widget.manifest;
    final created = m.createdAt.toLocal();
    final locale = ref.watch(formatLocaleProvider);
    final number = NumberFormat.decimalPattern(locale);

    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: Space.sm),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: context.text.bodyMedium,
            ),
          ),
        ],
      ),
    );

    return AlertDialog(
      icon: Icon(Icons.settings_backup_restore, color: context.colors.error),
      title: Text(l.exportRestoreTitle),
      scrollable: true,
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.fileName,
              style: context.mono,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: Space.sm),
            row(
              l.exportRestoreCreated,
              '${dates.medium(created)} ${dates.time(created)}',
            ),
            row(l.exportRestoreAppVersion, m.appVersion),
            row(
              l.exportRestoreDevice,
              widget.thisDevice
                  ? l.exportRestoreThisDevice
                  : l.exportRestoreOtherDevice,
            ),
            const Divider(height: Space.lg),
            row(l.navAccounts, number.format(m.rowsOf('accounts'))),
            row(l.navTransactions, number.format(m.rowsOf('transactions'))),
            row(l.navCategories, number.format(m.rowsOf('categories'))),
            row(l.exportRestoreTotalRows, number.format(m.totalRows)),
            if (m.fileCount > 0)
              row(
                l.backupReceipts,
                l.backupReceiptsValue(
                  m.fileCount,
                  formatBytes(m.fileBytes, locale),
                ),
              ),
            if (m.missingFiles.isNotEmpty) ...[
              const SizedBox(height: Space.xs),
              Text(
                l.backupRestoreMissing(m.missingFiles.length),
                style: context.text.bodySmall?.copyWith(
                  color: context.finance.warning,
                ),
              ),
            ],
            const SizedBox(height: Space.md),
            Container(
              padding: const EdgeInsets.all(Space.sm),
              decoration: BoxDecoration(
                color: context.colors.errorContainer,
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_outlined,
                    color: context.colors.onErrorContainer,
                  ),
                  const SizedBox(width: Space.xs),
                  Expanded(
                    child: Text(
                      l.exportRestoreWarning,
                      style: context.text.bodyMedium?.copyWith(
                        color: context.colors.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.xs),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _backupFirst,
              onChanged: (v) => setState(() => _backupFirst = v ?? false),
              title: Text(l.exportRestoreBackupFirst),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: context.colors.error,
            foregroundColor: context.colors.onError,
          ),
          onPressed: () => Navigator.pop(context, _backupFirst),
          child: Text(l.exportRestoreConfirm),
        ),
      ],
    );
  }
}
