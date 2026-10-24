import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/csv/file_output.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/export/data/export_folder.dart';
import 'package:personal_finance/features/export/domain/auto_export_plan.dart';
import 'package:personal_finance/features/export/domain/backup_crypto.dart';
import 'package:personal_finance/features/export/domain/backup_settings.dart';
import 'package:personal_finance/features/export/presentation/restore_flow.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

/// Backups found in the automatic backup folder, newest first.
final folderBackupsProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, folder) async {
      final files = await ref
          .watch(exportFolderFactoryProvider)(folder)
          .listFiles();
      return files.where(isAutoExportFile).toList()
        ..sort((a, b) => b.compareTo(a));
    });

/// How the backup folder is shown: the app Documents folder by its place
/// in Files, a platform folder by its name, a path as it is. Null without a
/// folder.
String? backupFolderLabel(AppLocalizations l, SettingsSnapshot s) {
  final folder = s.get(ImportExportSettings.autoExportFolder);
  if (folder == null || folder.isEmpty) return null;
  if (folder == appDocumentsFolderRef) return l.backupAppDocumentsFolder;
  return s.get(BackupSettings.folderName) ?? folder;
}

/// When the backup [name] was made, from its file name
/// (`…-yyyyMMdd-HHmmss…`, local time).
DateTime? autoExportFileTime(String name) {
  final m = RegExp(r'(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})(\d{2})')
      .firstMatch(name);
  if (m == null) return null;
  final v = [for (var i = 1; i <= 6; i++) int.parse(m[i]!)];
  return DateTime(v[0], v[1], v[2], v[3], v[4], v[5]);
}

/// Card on the automatic backup screen: the backups in the folder, each
/// with "Check" and "Restore" (docs/BACKUP.md).
class FolderBackupsCard extends ConsumerWidget {
  const FolderBackupsCard({required this.folder, super.key});

  final String folder;

  Future<PickedFile?> _read(
    BuildContext context,
    WidgetRef ref,
    String name,
  ) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    void snack(String m) => messenger.showSnackBar(SnackBar(content: Text(m)));
    try {
      final bytes = await ref
          .read(exportFolderFactoryProvider)(folder)
          .readFile(name);
      if (bytes != null) return PickedFile(name, bytes);
    } on Object catch (e) {
      snack(l.commonError('$e'));
      return null;
    }
    snack(l.backupFolderFileGone);
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final dates = ref.watch(dateFormatsProvider);
    final files = ref.watch(folderBackupsProvider(folder));
    return SectionCard(
      title: l.backupFolderList,
      padding: const EdgeInsets.fromLTRB(
        Space.cardPadding,
        Space.xs,
        Space.xs,
        Space.xs,
      ),
      child: files.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(Space.md),
          child: Center(child: CircularProgressIndicator.adaptive()),
        ),
        error: (e, _) => Text(
          l.commonError('$e'),
          style: TextStyle(color: context.colors.error),
        ),
        data: (names) => names.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.sm),
                child: Text(l.backupFolderListEmpty),
              )
            : Column(
                children: [
                  for (final name in names)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        name.endsWith(encryptedBackupExtension)
                            ? Icons.lock_outline
                            : Icons.archive_outlined,
                      ),
                      title: Text(switch (autoExportFileTime(name)) {
                        final t? => '${dates.medium(t)} ${dates.time(t)}',
                        null => name,
                      }),
                      subtitle: Text(name, style: context.mono),
                      trailing: PopupMenuButton<bool>(
                        tooltip: l.backupSafetyActions,
                        onSelected: (restore) async {
                          final file = await _read(context, ref, name);
                          if (file == null || !context.mounted) return;
                          if (restore) {
                            await startRestore(context, ref, file: file);
                          } else {
                            await checkBackupFile(context, ref, file: file);
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: false,
                            child: Text(l.backupCheck),
                          ),
                          PopupMenuItem(
                            value: true,
                            child: Text(l.backupSafetyRestore),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
