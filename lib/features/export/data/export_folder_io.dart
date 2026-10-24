import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:personal_finance/features/export/data/export_folder.dart';

ExportFolder openExportFolder(String path) => IoExportFolder(path);

/// [ExportFolder] backed by `dart:io`.
class IoExportFolder implements ExportFolder {
  IoExportFolder(this.path);
  final String path;

  Directory get _dir => Directory(path);

  @override
  Future<void> writeFile(String name, Uint8List bytes) async {
    await _dir.create(recursive: true);
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
  Future<List<String>> listFiles() async {
    if (!_dir.existsSync()) return const [];
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
