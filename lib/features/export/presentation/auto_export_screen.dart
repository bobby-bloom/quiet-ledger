import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/breakpoints.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/platform/capabilities.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/backup_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/export/data/auto_export.dart';
import 'package:personal_finance/features/export/data/export_folder.dart';
import 'package:personal_finance/features/export/data/export_folder_native.dart';
import 'package:personal_finance/features/export/domain/backup_health.dart';
import 'package:personal_finance/features/export/presentation/backup_health_banner.dart';
import 'package:personal_finance/features/export/presentation/export_labels.dart';
import 'package:personal_finance/features/export/presentation/folder_backups.dart';

/// Automatic backup settings (`/more/export/folder`): schedule, folder,
/// retention, last run and "Back up now". Native platforms only.
class AutoExportScreen extends ConsumerStatefulWidget {
  const AutoExportScreen({super.key});

  @override
  ConsumerState<AutoExportScreen> createState() => _AutoExportScreenState();
}

class _AutoExportScreenState extends ConsumerState<AutoExportScreen> {
  bool _running = false;

  Future<void> _chooseFolder() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final current = ref
        .read(settingsProvider)
        .get(ImportExportSettings.autoExportFolder);
    if (ref.read(platformCapabilitiesProvider).backupFolder ==
        BackupFolderKind.native) {
      try {
        final picked = await pickNativeFolder();
        if (picked != null) await _setFolder(picked.ref, picked.name);
      } on Object catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(l.commonError('$e'))));
      }
      return;
    }
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: l.exportAutoChooseFolder,
      initialDirectory:
          current == null ||
              isNativeFolderRef(current) ||
              current == appDocumentsFolderRef
          ? null
          : current,
    );
    if (path == null || path.isEmpty) return;
    await _setFolder(path, null);
  }

  /// iOS: the app's Documents folder (Files › On My iPhone).
  Future<void> _useAppDocuments() async {
    if (await appDocumentsBackupPath() == null) return;
    await _setFolder(appDocumentsFolderRef, null);
  }

  Future<void> _setFolder(String folder, String? name) async {
    final s = ref.read(settingsProvider.notifier);
    await s.set(ImportExportSettings.autoExportFolder, folder);
    if (name == null) {
      await s.reset(BackupSettings.folderName);
    } else {
      await s.set(BackupSettings.folderName, name);
    }
    // A new folder: an access error of the old one no longer applies.
    await clearBackupFailure(ref.read);
  }

  Future<void> _runNow() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _running = true);
    final r = await runAutoExportNow(ref.read);
    if (!mounted) return;
    setState(() => _running = false);
    final folder = ref
        .read(settingsProvider)
        .get(ImportExportSettings.autoExportFolder);
    if (folder != null) ref.invalidate(folderBackupsProvider(folder));
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          r.written
              ? l.exportAutoRunDone(r.fileName!)
              : l.exportAutoRunFailed('${r.error}'),
        ),
      ),
    );
  }

  Future<void> _setKeep(int v) => ref
      .read(settingsProvider.notifier)
      .set(ImportExportSettings.autoExportKeep, v.clamp(1, 100));

  Future<void> _setStaleDays(int v) => ref
      .read(settingsProvider.notifier)
      .set(BackupSettings.staleDays, v.clamp(1, 90));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final caps = ref.watch(platformCapabilitiesProvider);
    final s = ref.watch(settingsProvider);
    final dates = ref.watch(dateFormatsProvider);
    final gutter = WindowSize.of(context).isCompact
        ? Space.phoneGutter
        : Space.desktopGutter;

    if (!caps.chooseFolder) {
      return Scaffold(
        appBar: AppBar(title: Text(l.exportAutoTitle)),
        body: EmptyState(
          icon: Icons.folder_off_outlined,
          message: l.exportAutoUnavailable,
        ),
      );
    }

    final schedule = s.get(ImportExportSettings.autoExport);
    final folder = s.get(ImportExportSettings.autoExportFolder);
    final hasFolder = folder != null && folder.isNotEmpty;
    final folderLabel = backupFolderLabel(l, s);
    final keep = s.get(ImportExportSettings.autoExportKeep);
    final last = DateTime.tryParse(
      s.get(ImportExportSettings.lastAutoExport) ?? '',
    );
    final error = s.get(BackupSettings.lastError);
    final staleDays = s.get(BackupSettings.staleDays);
    final health = ref.watch(backupHealthProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.exportAutoTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(gutter, Space.xs, gutter, Space.xxl),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: SectionCard(
                  title: l.exportAutoSettings,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l.exportAutoDesc,
                        style: context.text.bodyMedium?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: Space.md),
                      Text(
                        l.exportAutoSchedule,
                        style: context.text.labelLarge?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: Space.xs),
                      SegmentedButton<AutoExportSchedule>(
                        segments: [
                          for (final v in AutoExportSchedule.values)
                            ButtonSegment(
                              value: v,
                              label: Text(scheduleLabel(l, v)),
                            ),
                        ],
                        selected: {schedule},
                        onSelectionChanged: (v) => ref
                            .read(settingsProvider.notifier)
                            .set(ImportExportSettings.autoExport, v.first),
                      ),
                      const SizedBox(height: Space.sm),
                      const Divider(height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.folder_outlined),
                        title: Text(
                          ImportExportSettings.autoExportFolder.label(l),
                        ),
                        subtitle: Text(
                          hasFolder ? folderLabel! : l.exportAutoNoFolder,
                          style: hasFolder ? context.mono : null,
                        ),
                        trailing: TextButton(
                          onPressed: _chooseFolder,
                          child: Text(l.exportAutoChooseFolder),
                        ),
                      ),
                      if (caps.appDocumentsFolder)
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton.icon(
                            onPressed: _useAppDocuments,
                            icon: const Icon(Icons.phone_iphone),
                            label: Text(l.backupUseAppDocuments),
                          ),
                        ),
                      if (!hasFolder && schedule != AutoExportSchedule.off)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Space.xs),
                          child: Text(
                            l.exportAutoNeedsFolder,
                            style: context.text.bodySmall?.copyWith(
                              color: context.finance.warning,
                            ),
                          ),
                        ),
                      const Divider(height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.history),
                        title: Text(
                          ImportExportSettings.autoExportKeep.label(l),
                        ),
                        subtitle: Text(l.exportAutoKeepValue(keep)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: l.exportDecrease,
                              onPressed: keep > 1
                                  ? () => _setKeep(keep - 1)
                                  : null,
                              icon: const Icon(Icons.remove),
                            ),
                            SizedBox(
                              width: Space.xl,
                              child: Text(
                                '$keep',
                                textAlign: TextAlign.center,
                                style: context.text.titleMedium,
                              ),
                            ),
                            IconButton(
                              tooltip: l.exportIncrease,
                              onPressed: keep < 100
                                  ? () => _setKeep(keep + 1)
                                  : null,
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.notifications_outlined),
                        title: Text(l.backupStaleDays),
                        subtitle: Text(l.backupStaleDaysValue(staleDays)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: l.exportDecrease,
                              onPressed: staleDays > 1
                                  ? () => _setStaleDays(staleDays - 1)
                                  : null,
                              icon: const Icon(Icons.remove),
                            ),
                            SizedBox(
                              width: Space.xl,
                              child: Text(
                                '$staleDays',
                                textAlign: TextAlign.center,
                                style: context.text.titleMedium,
                              ),
                            ),
                            IconButton(
                              tooltip: l.exportIncrease,
                              onPressed: staleDays < 90
                                  ? () => _setStaleDays(staleDays + 1)
                                  : null,
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event_available_outlined),
                        title: Text(
                          last == null
                              ? l.exportAutoNever
                              : l.exportAutoLast(
                                  '${dates.medium(last.toLocal())} '
                                  '${dates.time(last.toLocal())}',
                                ),
                        ),
                      ),
                      if (error != null ||
                          health.status == BackupStatus.interrupted)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Space.xs),
                          child: Text(
                            error == null
                                ? l.backupHealthInterrupted
                                : l.backupHealthFailing(error),
                            style: context.text.bodySmall?.copyWith(
                              color: context.colors.error,
                            ),
                          ),
                        ),
                      const SizedBox(height: Space.xs),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: FilledButton.icon(
                          onPressed: hasFolder && !_running ? _runNow : null,
                          icon: _running
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.backup_outlined),
                          label: Text(l.exportAutoRunNow),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (hasFolder) ...[
              const SizedBox(height: Space.md),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: FolderBackupsCard(folder: folder),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
