import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:personal_finance/features/export/data/export_folder.dart';

ExportFolder openExportFolder(String path, {bool create = false}) =>
    IoExportFolder(path, create: create);

/// `<app Documents>/Backups` (iOS: visible in Files › On My iPhone).
Future<String?> appDocumentsBackupPath() async =>
    p.join((await getApplicationDocumentsDirectory()).path, 'Backups');

/// [ExportFolder] backed by `dart:io`.
///
/// A missing folder is an error ([BackupFolderMissingException]) unless
/// [create] is set: a picked folder that is gone is usually on a drive that
/// is not connected, and recreating the path would put the backups on the
/// system disk instead.
class IoExportFolder implements ExportFolder {
  IoExportFolder(this.path, {this.create = false});
  final String path;

  /// Create the folder when it does not exist (the app's own folders).
  final bool create;

  Directory get _dir => Directory(path);

  Future<void> _requireDir() async {
    if (_dir.existsSync()) return;
    if (!create) throw BackupFolderMissingException(path);
    await _dir.create(recursive: true);
  }

  @override
  Future<void> writeFile(String name, Uint8List bytes) async {
    await _requireDir();
    final target = File(p.join(path, name));
    final tmp = File(p.join(path, '.$name.tmp'));
    await tmp.writeAsBytes(bytes, flush: true);
    if (await tmp.length() != bytes.length) {
      await tmp.delete();
      throw FileSystemException('Incomplete write', tmp.path);
    }
    await tmp.rename(target.path);
  }

  @override
  Future<Uint8List?> readFile(String name) async {
    final f = File(p.join(path, name));
    return f.existsSync() ? await f.readAsBytes() : null;
  }

  @override
  Future<List<String>> listFiles() async {
    if (!_dir.existsSync()) {
      if (!create) throw BackupFolderMissingException(path);
      return const [];
    }
    return await _dir
        .list()
        .where((e) => e is File)
        .map((e) => p.basename(e.path))
        .toList();
  }

  @override
  Future<void> deleteFile(String name) async {
    final f = File(p.join(path, name));
    if (f.existsSync()) await f.delete();
  }
}
