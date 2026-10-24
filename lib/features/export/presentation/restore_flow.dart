import 'dart:convert';
import 'dart:typed_data';

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
import 'package:personal_finance/features/export/data/auto_export.dart';
import 'package:personal_finance/features/export/data/backup_keys.dart';
import 'package:personal_finance/features/export/data/backup_service.dart';
import 'package:personal_finance/features/export/data/bundle_service.dart';
import 'package:personal_finance/features/export/data/safety_copies.dart';
import 'package:personal_finance/features/export/domain/backup_crypto.dart';
import 'package:personal_finance/features/export/domain/bundle_manifest.dart';
import 'package:personal_finance/features/export/presentation/backup_password_screen.dart';
import 'package:personal_finance/features/export/presentation/export_labels.dart';

/// File name for a manual backup (`.zip`, or `.pfbackup` when encrypted).
/// Differs from the scheduled backups' names, so retention never deletes a
/// backup saved by hand into the backup folder.
String backupFileName(DateTime now, [String extension = '.zip']) =>
    'personal-finance-manual-${DateFormat('yyyyMMdd-HHmmss').format(now)}'
    '$extension';

/// Creates a verified backup and hands it to save/share/download. Returns
/// the save outcome, or null on error (a snackbar is shown). When a backup
/// password is required but missing, the password setup opens instead.
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
      fileName: backupFileName(DateTime.now(), backup.extension),
      mimeType: backup.mimeType,
      capabilities: ref.read(platformCapabilitiesProvider),
      sharePositionOrigin: origin,
    );
    if (r.ok) {
      await recordVerifiedBackup(ref.read);
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
  } on BackupPasswordMissingException {
    messenger?.showSnackBar(SnackBar(content: Text(l.backupPasswordMissing)));
    if (context.mounted) await startBackupPasswordSetup(context, ref);
    return null;
  } on Object catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text(l.exportFailed('$e'))));
    return null;
  }
}

/// Lets the user pick a backup file. Mobile pickers know no MIME type for
/// `.pfbackup`, so there any file is offered and the content decides.
Future<PickedFile?> pickBackupFile(WidgetRef ref) => pickFileBytes(
  extensions: ref.read(platformCapabilitiesProvider).isMobile
      ? null
      : const ['zip', 'pfbackup'],
);

/// Opens [file] (picked when null) without restoring and reports whether
/// it is a complete, readable backup ("Check a backup").
Future<void> checkBackupFile(
  BuildContext context,
  WidgetRef ref, {
  PickedFile? file,
}) async {
  final l = context.l10n;
  final picked = file ?? await pickBackupFile(ref);
  if (picked == null || !context.mounted) return;
  final contents = await openPickedBackup(context, ref, picked.bytes);
  if (contents == null || !context.mounted) return;
  final m = contents.manifest;
  final dates = ref.read(dateFormatsProvider);
  final created = m.createdAt.toLocal();
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(Icons.verified_outlined, color: ctx.colors.primary),
      title: Text(l.backupCheckOk),
      content: Text(
        l.backupCheckOkDesc(
          picked.name,
          '${dates.medium(created)} ${dates.time(created)}',
          m.totalRows,
          m.fileCount,
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l.commonClose),
        ),
      ],
    ),
  );
}

/// Opens a picked backup: plain bundles directly, encrypted ones with the
/// keys on this device or, failing that, the password / recovery key the
/// user types (asked again after a wrong one). Shows errors; null when it
/// cannot be opened or the user gives up.
Future<BundleContents?> openPickedBackup(
  BuildContext context,
  WidgetRef ref,
  Uint8List bytes,
) async {
  final l = context.l10n;
  Future<void> fail(String message) => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(Icons.error_outline, color: ctx.colors.error),
      title: Text(l.exportErrTitle),
      content: Text(message),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l.commonClose),
        ),
      ],
    ),
  );

  BackupUnlock? unlock;
  String? wrong;
  for (;;) {
    try {
      return await openBackup(
        ref.read,
        bytes,
        password: unlock?.password,
        recoveryKey: unlock?.recoveryKey,
      );
    } on BundleException catch (e) {
      if (context.mounted) await fail(bundleErrorMessage(l, e));
      return null;
    } on BackupCryptoException catch (e) {
      if (!context.mounted) return null;
      if (e.error != BackupCryptoError.wrongKey) {
        await fail(switch (e.error) {
          BackupCryptoError.newerVersion => l.exportErrNewerFormat,
          BackupCryptoError.damaged => l.backupErrDamaged,
          _ => l.exportErrNotBundle,
        });
        return null;
      }
      unlock = await askBackupUnlock(context, error: wrong);
      if (unlock == null) return null;
      wrong = l.backupUnlockWrong;
    } on Object catch (e) {
      // Never an unhandled error for a file the user picked.
      if (context.mounted) await fail(l.commonError('$e'));
      return null;
    }
  }
}

/// Pick → validate → summary → confirm (destructive, optional backup saved
/// elsewhere) → safety copy on this device → restore in one transaction →
/// refresh. Without a safety copy nothing is restored.
/// [file] skips the file picker (a backup from the backup folder).
Future<void> startRestore(
  BuildContext context,
  WidgetRef ref, {
  Rect? origin,
  PickedFile? file,
}) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final picked = file ?? await pickBackupFile(ref);
  if (picked == null || !context.mounted) return;

  final db = ref.read(databaseProvider);
  final contents = await openPickedBackup(context, ref, picked.bytes);
  if (contents == null || !context.mounted) return;
  final newer = await rowsChangedAfter(db, contents);
  if (!context.mounted) return;

  final backupFirst = await showDialog<bool>(
    context: context,
    builder: (ctx) => _RestoreSummaryDialog(
      manifest: contents.manifest,
      fileName: picked.name,
      newerRows: newer,
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
    final rows = await withSafetyCopy(
      ref.read,
      SafetyReason.restore,
      () => restoreBundle(
        db,
        contents,
        clock: ref.read(hlcClockProvider),
        receipts: ref.read(receiptStoreProvider),
      ),
    );
    navigator.pop();
    await refreshAfterDataReplace(ref);
    messenger?.showSnackBar(SnackBar(content: Text(l.exportRestoreDone(rows))));
  } on SafetyCopyException catch (e) {
    navigator.pop();
    messenger?.showSnackBar(
      SnackBar(content: Text(l.backupSafetyFailed('${e.cause}'))),
    );
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
    required this.newerRows,
    required this.fileName,
    required this.thisDevice,
  });

  final BundleManifest manifest;

  /// Rows changed on this device after the backup was made.
  final int newerRows;
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
            if (widget.newerRows > 0) ...[
              const SizedBox(height: Space.xs),
              Text(
                l.backupRestoreNewer(widget.newerRows),
                style: context.text.bodyMedium?.copyWith(
                  color: context.finance.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
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
