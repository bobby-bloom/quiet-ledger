import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/features/export/data/export_folder_native.dart';
import 'package:personal_finance/features/export/data/export_folder_stub.dart'
    if (dart.library.io) 'package:personal_finance/features/export/data/export_folder_io.dart'
    as impl;

/// A directory that receives automatic backups. The io implementation
/// writes atomically (temp file + rename); on the web folders are not
/// available ([openExportFolder] throws [UnsupportedError]).
abstract interface class ExportFolder {
  /// Writes [name] (overwriting), atomically where the platform allows.
  Future<void> writeFile(String name, Uint8List bytes);

  /// The content of [name], null when it does not exist. Used to verify a
  /// backup after writing it.
  Future<Uint8List?> readFile(String name);

  /// File names (not paths) directly inside the folder.
  Future<List<String>> listFiles();

  Future<void> deleteFile(String name);
}

/// `autoExportFolder` value for `<app Documents>/Backups` (iOS: Files ›
/// On My iPhone). Stored instead of the absolute path because iOS moves the
/// app container on every update.
const appDocumentsFolderRef = 'appdocs:Backups';

/// Opens the folder at [path] (created if missing), the app Documents
/// folder ([appDocumentsFolderRef]) or the platform folder [path] refers to
/// (`content://…`, `bookmark:…`; see `export_folder_native.dart`).
ExportFolder openExportFolder(String path) {
  if (path == appDocumentsFolderRef) return AppDocumentsExportFolder();
  return isNativeFolderRef(path)
      ? NativeExportFolder(path)
      : impl.openExportFolder(path);
}

/// `<app Documents>/Backups` where the platform has one, else null.
Future<String?> appDocumentsBackupPath() => impl.appDocumentsBackupPath();

/// The folder behind [appDocumentsFolderRef]. Looks up the current path on
/// every call, so it follows the app container when it moves.
class AppDocumentsExportFolder implements ExportFolder {
  AppDocumentsExportFolder({Future<String?> Function()? resolve})
    : _resolve = resolve ?? appDocumentsBackupPath;

  final Future<String?> Function() _resolve;

  Future<ExportFolder> _open() async {
    final path = await _resolve();
    if (path == null) throw UnsupportedError('No app Documents folder');
    return impl.openExportFolder(path);
  }

  @override
  Future<void> writeFile(String name, Uint8List bytes) async {
    final folder = await _open();
    await folder.writeFile(name, bytes);
  }

  @override
  Future<Uint8List?> readFile(String name) async {
    final folder = await _open();
    return await folder.readFile(name);
  }

  @override
  Future<List<String>> listFiles() async {
    final folder = await _open();
    return await folder.listFiles();
  }

  @override
  Future<void> deleteFile(String name) async {
    final folder = await _open();
    await folder.deleteFile(name);
  }
}

/// Factory used by auto-export; override in tests.
final exportFolderFactoryProvider = Provider<ExportFolder Function(String)>(
  (ref) => openExportFolder,
);

/// In-memory folder for tests and the web preview.
class MemoryExportFolder implements ExportFolder {
  final Map<String, Uint8List> files = {};

  @override
  Future<void> writeFile(String name, Uint8List bytes) async =>
      files[name] = bytes;

  @override
  Future<Uint8List?> readFile(String name) async => files[name];

  @override
  Future<List<String>> listFiles() async => files.keys.toList();

  @override
  Future<void> deleteFile(String name) async => files.remove(name);
}
