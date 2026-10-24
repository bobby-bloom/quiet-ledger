import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/breakpoints.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/attachments/receipt_store.dart';
import 'package:personal_finance/core/csv/file_output.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/platform/capabilities.dart';
import 'package:personal_finance/features/export/data/backup_keys.dart';
import 'package:personal_finance/features/export/data/backup_service.dart';
import 'package:personal_finance/features/export/data/bundle_service.dart';
import 'package:personal_finance/features/export/data/safety_copies.dart';
import 'package:personal_finance/features/export/presentation/restore_flow.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

String safetyReasonLabel(AppLocalizations l, SafetyReason? r) => switch (r) {
  SafetyReason.restore => l.backupSafetyReasonRestore,
  SafetyReason.reset => l.backupSafetyReasonReset,
  SafetyReason.importUndo => l.backupSafetyReasonImportUndo,
  SafetyReason.merge => l.backupSafetyReasonMerge,
  SafetyReason.purge => l.backupSafetyReasonPurge,
  SafetyReason.restoreCopy => l.backupSafetyReasonRestoreCopy,
  null => l.backupSafetyTitle,
};

/// `/more/export/safety`: the on-device safety copies, with restore, save
/// elsewhere and delete.
class SafetyCopiesScreen extends ConsumerStatefulWidget {
  const SafetyCopiesScreen({super.key});

  @override
  ConsumerState<SafetyCopiesScreen> createState() => _SafetyCopiesScreenState();
}

class _SafetyCopiesScreenState extends ConsumerState<SafetyCopiesScreen> {
  bool _busy = false;

  Future<void> _guard(Future<void> Function() op) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await op();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _when(SafetyCopyInfo c) {
    final dates = ref.read(dateFormatsProvider);
    final t = c.createdAt.toLocal();
    return '${dates.medium(t)} ${dates.time(t)}';
  }

  Future<void> _restore(SafetyCopyInfo c) => _guard(() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmDialog(
      context,
      title: l.backupSafetyRestore,
      message: l.backupSafetyRestoreConfirm(_when(c)),
      confirmLabel: l.backupSafetyRestore,
    );
    if (!ok || !mounted) return;
    try {
      final rows = await restoreSafetyCopy(ref.read, c.id);
      await refreshAfterDataReplace(ref);
      messenger.showSnackBar(
        SnackBar(content: Text(l.backupSafetyRestored(rows))),
      );
    } on SafetyCopyException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.backupSafetyFailed('${e.cause}'))),
      );
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.exportRestoreFailed('$e'))),
      );
    }
  });

  Future<void> _save(SafetyCopyInfo c, Rect? origin) => _guard(() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final db = ref.read(databaseProvider);
      // Leaving the device: with the receipt files (still on disk; no
      // guarded action deletes them) and encrypted like any other backup.
      final zip = await withReceiptFiles(
        db,
        await safetyCopyBytes(db, c.id),
        ref.read(receiptStoreProvider),
      );
      final backup = await createVerifiedBackup(ref.read, zip: zip);
      final stamp = DateFormat('yyyyMMdd-HHmmss').format(c.createdAt.toLocal());
      await saveOrShareBytes(
        bytes: backup.bytes,
        fileName: 'personal-finance-safety-$stamp${backup.extension}',
        mimeType: backup.mimeType,
        capabilities: ref.read(platformCapabilitiesProvider),
        sharePositionOrigin: origin,
      );
    } on BackupPasswordMissingException {
      messenger.showSnackBar(SnackBar(content: Text(l.backupPasswordMissing)));
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.exportFailed('$e'))));
    }
  });

  Future<void> _delete(SafetyCopyInfo c) => _guard(() async {
    final l = context.l10n;
    final ok = await confirmDialog(
      context,
      title: l.backupSafetyDelete,
      message: l.backupSafetyDeleteConfirm(_when(c)),
      confirmLabel: l.backupSafetyDelete,
    );
    if (!ok) return;
    await deleteSafetyCopy(ref.read(databaseProvider), c.id);
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final copies = ref.watch(safetyCopiesProvider);
    final locale = ref.watch(formatLocaleProvider);
    final number = NumberFormat.decimalPattern(locale);
    final gutter = WindowSize.of(context).isCompact
        ? Space.phoneGutter
        : Space.desktopGutter;
    return Scaffold(
      appBar: AppBar(title: Text(l.backupSafetyTitle)),
      body: SafeArea(
        top: false,
        child: AsyncView(
          value: copies,
          data: (list) => ListView(
            padding: EdgeInsets.fromLTRB(gutter, Space.xs, gutter, Space.xxl),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l.backupSafetyDesc,
                        style: context.text.bodyMedium?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: Space.md),
                      if (list.isEmpty)
                        EmptyState(
                          icon: Icons.shield_outlined,
                          message: l.backupSafetyEmpty,
                        )
                      else
                        SectionCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              for (final (i, c) in list.indexed) ...[
                                if (i > 0) const Divider(height: 1),
                                _CopyTile(
                                  title: safetyReasonLabel(l, c.reason),
                                  subtitle:
                                      '${_when(c)}\n'
                                      '${l.backupSafetyRows(number.format(c.rowCount), formatBytes(c.sizeBytes, locale))}',
                                  busy: _busy,
                                  onRestore: () => _restore(c),
                                  onSave: (origin) => _save(c, origin),
                                  onDelete: () => _delete(c),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Action { restore, save, delete }

class _CopyTile extends StatelessWidget {
  const _CopyTile({
    required this.title,
    required this.subtitle,
    required this.busy,
    required this.onRestore,
    required this.onSave,
    required this.onDelete,
  });

  final String title;
  final String subtitle;
  final bool busy;
  final VoidCallback onRestore;
  final void Function(Rect? origin) onSave;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ListTile(
      leading: const Icon(Icons.shield_outlined),
      title: Text(title),
      subtitle: Text(subtitle),
      isThreeLine: true,
      trailing: Builder(
        builder: (btn) => PopupMenuButton<_Action>(
          enabled: !busy,
          tooltip: l.backupSafetyActions,
          onSelected: (a) {
            switch (a) {
              case _Action.restore:
                onRestore();
              case _Action.save:
                final box = btn.findRenderObject() as RenderBox?;
                onSave(
                  box == null
                      ? null
                      : box.localToGlobal(Offset.zero) & box.size,
                );
              case _Action.delete:
                onDelete();
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: _Action.restore,
              child: Text(l.backupSafetyRestore),
            ),
            PopupMenuItem(value: _Action.save, child: Text(l.backupSafetySave)),
            PopupMenuItem(
              value: _Action.delete,
              child: Text(l.backupSafetyDelete),
            ),
          ],
        ),
      ),
    );
  }
}
