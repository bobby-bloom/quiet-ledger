import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/features/export/data/export_folder_stub.dart'
    if (dart.library.io) 'package:personal_finance/features/export/data/export_folder_io.dart'
    as impl;

/// A directory that receives automatic backups. The io implementation
/// writes atomically (temp file + rename); on the web folders are not
/// available ([openExportFolder] throws [UnsupportedError]).
abstract interface class ExportFolder {
  /// Writes [name] (overwriting), atomically where the platform allows.
  Future<void> writeFile(String name, Uint8List bytes);

  /// File names (not paths) directly inside the folder.
  Future<List<String>> listFiles();

  Future<void> deleteFile(String name);
}

/// Opens the folder at [path] (created if missing).
ExportFolder openExportFolder(String path) => impl.openExportFolder(path);

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
  Future<List<String>> listFiles() async => files.keys.toList();

  @override
  Future<void> deleteFile(String name) async => files.remove(name);
}
