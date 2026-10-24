import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/platform/capabilities.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/export/data/data_tools.dart';
import 'package:personal_finance/features/export/data/safety_copies.dart';
import 'package:personal_finance/features/export/presentation/restore_flow.dart';
import 'package:personal_finance/features/rules/presentation/rerun_rules_dialog.dart';
import 'package:personal_finance/features/security/data/secret_store.dart';
import 'package:personal_finance/features/security/presentation/lock_setup.dart';
import 'package:personal_finance/features/settings/data/data_maintenance.dart';
import 'package:personal_finance/features/settings/data/storage_files.dart';
import 'package:personal_finance/features/settings/presentation/setting_tiles.dart';
import 'package:personal_finance/features/settings/presentation/settings_catalog.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

/// Live database statistics (refreshed when the screen is rebuilt).
final dbStatisticsProvider = FutureProvider.autoDispose<DbStats>(
  (ref) => dbStatistics(ref.watch(databaseProvider)),
);

void _snack(BuildContext context, String text) {
  ScaffoldMessenger.maybeOf(context)
      ?.showSnackBar(SnackBar(content: Text(text)));
}

/// Settings › Data rows: storage location (desktop), statistics, search
/// index, re-run rules, reset app. Generic settings of the section are
/// rendered after these by the section view.
List<Widget> dataSectionRows(
  BuildContext context,
  WidgetRef ref,
  Widget Function(String id, Widget child) wrap,
) {
  final l = context.l10n;
  final caps = ref.watch(platformCapabilitiesProvider);
  return [
    if (caps.customStorageLocation)
      wrap(DataSettings.storageLocation.key, const _StorageLocationRow()),
    wrap(SettingsActions.statistics, const _StatisticsRow()),
    wrap(
      SettingsActions.rebuildSearch,
      _ActionRow(
        icon: Icons.manage_search,
        title: l.settingsUiRebuildIndex,
        subtitle: l.settingsUiRebuildIndexDesc,
        run: () async {
          await rebuildSearchIndex(ref.read(databaseProvider));
          return l.settingsUiRebuildDone;
        },
      ),
    ),
    wrap(
      SettingsActions.purgeDeleted,
      SettingRow(
        leading: Icon(
          Icons.cleaning_services_outlined,
          color: context.colors.onSurfaceVariant,
        ),
        title: l.settingsUiPurge,
        subtitle: l.settingsUiPurgeDesc(
          ref.watch(
            settingsProvider.select((s) => s.get(DataSettings.tombstoneDays)),
          ),
        ),
        onTap: () => _purge(context, ref),
      ),
    ),
    wrap(
      SettingsActions.rerunRules,
      SettingRow(
        leading: Icon(
          Icons.auto_fix_high_outlined,
          color: context.colors.onSurfaceVariant,
        ),
        title: l.settingsUiRerunRules,
        subtitle: l.settingsUiRerunRulesDesc,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => showRerunRulesDialog(context),
      ),
    ),
    wrap(
      SettingsActions.resetApp,
      SettingRow(
        leading: Icon(
          Icons.delete_forever_outlined,
          color: context.colors.error,
        ),
        title: l.settingsUiResetApp,
        titleColor: context.colors.error,
        subtitle: l.settingsUiResetAppDesc,
        onTap: () => _resetApp(context, ref),
      ),
    ),
  ];
}

Future<void> _purge(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final days = ref.read(settingsProvider).get(DataSettings.tombstoneDays);
  final ok = await confirmDialog(
    context,
    title: l.settingsUiPurge,
    message: l.settingsUiPurgeMessage(days),
    confirmLabel: l.settingsUiPurgeConfirm,
  );
  if (!ok || !context.mounted) return;
  try {
    final n = await purgeTombstones(
      ref.read(databaseProvider),
      Duration(days: days),
    );
    ref.invalidate(dbStatisticsProvider);
    if (context.mounted) _snack(context, l.settingsUiPurgeDone(n));
  } on Object catch (e) {
    if (context.mounted) _snack(context, l.commonError(e.toString()));
  }
}

/// Type-to-confirm reset: wipes the database (export's `resetAppData`) and
/// the lock credential, clears the bootstrap-mirrored preferences, then
/// returns to onboarding. The database file and its key stay (the file is
/// still encrypted with it); device id and storage location are kept. By
/// default a safety copy is taken first and kept; unticking it wipes the
/// safety copies as well (a real "delete everything").
Future<void> _resetApp(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  if (!await confirmIdentity(context, ref)) return;
  if (!context.mounted) return;
  final keepCopy = await showDialog<bool>(
    context: context,
    builder: (_) => const _ResetDialog(),
  );
  if (keepCopy == null || !context.mounted) return;
  final router = GoRouter.of(context);
  final db = ref.read(databaseProvider);
  try {
    if (keepCopy) {
      await takeSafetyCopy(
        db,
        SafetyReason.reset,
        deviceId: ref.read(deviceIdProvider),
      );
    }
    await ref.read(credentialRepositoryProvider).clear();
    await resetAppData(db);
    if (!keepCopy) await db.delete(db.safetyCopies).go();
    // Scrub the deleted rows from free pages.
    try {
      await db.customStatement('VACUUM');
    } on Object catch (e) {
      debugPrint('VACUUM after reset failed: $e');
    }
    await refreshAfterDataReplace(ref);
  } on SafetyCopyException catch (e) {
    if (context.mounted) _snack(context, l.backupSafetyFailed('${e.cause}'));
    return;
  } on Object catch (e) {
    if (context.mounted) _snack(context, l.commonError(e.toString()));
    return;
  }
  // The settings stream now reports defaults (onboarding not done, lock
  // off); the lock controller follows the appLock setting.
  router.go('/onboarding');
}

class _ResetDialog extends StatefulWidget {
  const _ResetDialog();

  @override
  State<_ResetDialog> createState() => _ResetDialogState();
}

/// Pops the "keep a safety copy" choice when confirmed, null when
/// cancelled.
class _ResetDialogState extends State<_ResetDialog> {
  final _c = TextEditingController();
  bool _keepCopy = true;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final word = l.settingsUiResetAppWord;
    final matches = _c.text.trim().toUpperCase() == word.toUpperCase();
    return AlertDialog(
      icon: Icon(Icons.warning_amber_rounded, color: context.colors.error),
      title: Text(l.settingsUiResetAppTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.settingsUiResetAppMessage(word)),
          const SizedBox(height: Space.md),
          TextField(
            key: const ValueKey('reset-confirm'),
            controller: _c,
            autofocus: true,
            autocorrect: false,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l.settingsUiTypeToConfirm(word),
            ),
          ),
          const SizedBox(height: Space.xs),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _keepCopy,
            onChanged: (v) => setState(() => _keepCopy = v ?? false),
            title: Text(l.backupResetKeepCopy),
            subtitle: Text(l.backupResetKeepCopyDesc),
          ),
        ],
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
          onPressed: matches ? () => Navigator.pop(context, _keepCopy) : null,
          child: Text(l.settingsUiResetAppConfirm),
        ),
      ],
    );
  }
}

/// Row that runs an async action with a progress indicator and reports the
/// result in a snackbar.
class _ActionRow extends StatefulWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.run,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Future<String> Function() run;

  @override
  State<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends State<_ActionRow> {
  bool _busy = false;

  Future<void> _go() async {
    setState(() => _busy = true);
    String msg;
    try {
      msg = await widget.run();
    } on Object catch (e) {
      if (!mounted) return;
      msg = context.l10n.commonError(e.toString());
    }
    if (!mounted) return;
    setState(() => _busy = false);
    _snack(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    return SettingRow(
      leading: Icon(widget.icon, color: context.colors.onSurfaceVariant),
      title: widget.title,
      subtitle: widget.subtitle,
      onTap: _busy ? null : _go,
      trailing: _busy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
    );
  }
}

class _StatisticsRow extends ConsumerWidget {
  const _StatisticsRow();

  static String _label(AppLocalizations l, String table) => switch (table) {
    'transactions' => l.navTransactions,
    'accounts' => l.navAccounts,
    'categories' => l.navCategories,
    'tags' => l.navTags,
    'budgets' => l.setModBudgets,
    'recurring_rules' => l.settingsUiStatRecurring,
    'goals' => l.navGoals,
    'rules' => l.navRules,
    'import_batches' => l.settingsUiStatImports,
    _ => table,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final stats = ref.watch(dbStatisticsProvider);
    final locale = ref.watch(formatLocaleProvider);
    final rows = stats.when(
      loading: () => const <(String, String)>[],
      error: (e, _) => [(l.commonError(e.toString()), '')],
      data: (s) => [
        for (final t in statisticsTables) (_label(l, t), '${s[t]?.live ?? 0}'),
        (l.settingsUiStatChangeLog, '${s.changeLogEntries}'),
        if (s.deletedRows > 0) (l.settingsUiStatDeleted, '${s.deletedRows}'),
        if (s.sizeBytes != null)
          (l.settingsUiStatDbSize, formatBytes(s.sizeBytes!, locale)),
      ],
    );
    return SettingRow(
      leading: Icon(Icons.query_stats, color: context.colors.onSurfaceVariant),
      title: l.settingsUiStats,
      trailing: IconButton(
        tooltip: l.settingsUiRefresh,
        icon: const Icon(Icons.refresh),
        onPressed: () => ref.invalidate(dbStatisticsProvider),
      ),
      below: stats.isLoading
          ? const LinearProgressIndicator()
          : Column(
              children: [
                for (final (k, v) in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            k,
                            style: context.text.bodySmall?.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Text(
                          v,
                          style: context.text.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Desktop: choose the folder that holds the database. Takes effect after
/// a restart; the current file can be copied there.
class _StorageLocationRow extends ConsumerWidget {
  const _StorageLocationRow();

  Future<void> _choose(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final current = ref
        .read(settingsProvider)
        .get(DataSettings.storageLocation);
    final defaultDir = await defaultDbDirectory();
    final from = current.isEmpty ? defaultDir : current;
    final dir = await FilePicker.getDirectoryPath(
      dialogTitle: l.setStorageLocation,
    );
    if (dir == null || dir == from || !context.mounted) return;
    final exists = await databaseExistsIn(dir);
    if (!context.mounted) return;
    final ok = await confirmDialog(
      context,
      title: l.settingsUiStorageMoveTitle,
      message: exists
          ? l.settingsUiStorageExisting(dir)
          : l.settingsUiStorageMoveMessage(dir),
      confirmLabel: exists
          ? l.settingsUiStorageUseExisting
          : l.settingsUiStorageCopy,
      destructive: false,
    );
    if (!ok || !context.mounted) return;
    try {
      if (!exists && from != null) {
        await copyDatabaseTo(ref.read(databaseProvider), from, dir);
      }
      await ref
          .read(settingsProvider.notifier)
          .set(DataSettings.storageLocation, dir);
      if (context.mounted) _snack(context, l.settingsUiStorageRestart);
    } on Object catch (e) {
      if (context.mounted) _snack(context, l.commonError(e.toString()));
    }
  }

  Future<void> _useDefault(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final ok = await confirmDialog(
      context,
      title: l.settingsUiStorageResetDefault,
      message: l.settingsUiStorageResetMessage,
      confirmLabel: l.settingsUiStorageResetDefault,
      destructive: false,
    );
    if (!ok) return;
    await ref
        .read(settingsProvider.notifier)
        .reset(DataSettings.storageLocation);
    if (context.mounted) _snack(context, l.settingsUiStorageRestart);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final current = ref.watch(
      settingsProvider.select((s) => s.get(DataSettings.storageLocation)),
    );
    return SettingRow(
      leading: Icon(
        Icons.folder_outlined,
        color: context.colors.onSurfaceVariant,
      ),
      title: l.setStorageLocation,
      subtitle: current.isEmpty ? l.settingsUiStorageDefault : current,
      onTap: () => _choose(context, ref),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (current.isNotEmpty)
            IconButton(
              tooltip: l.settingsUiStorageResetDefault,
              icon: const Icon(Icons.restart_alt),
              onPressed: () => _useDefault(context, ref),
            ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
