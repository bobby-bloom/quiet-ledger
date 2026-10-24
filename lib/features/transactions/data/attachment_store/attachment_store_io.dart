import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:personal_finance/core/db/sync_writer.dart';

/// Whether attachments are stored as files (false: bytes in the DB).
const bool attachmentsUseFiles = true;

Future<Directory> _dir() async {
  final base = await getApplicationSupportDirectory();
  final dir = Directory(p.join(base.path, 'attachments'));
  if (!dir.existsSync()) await dir.create(recursive: true);
  return dir;
}

String _safeName(String fileName) {
  final cleaned = fileName.replaceAll(RegExp(r'[^\w.\-]+'), '_');
  return '${newId()}_${cleaned.isEmpty ? 'file' : cleaned}';
}

/// Stores [bytes] under `attachments/` and returns the absolute path.
Future<String?> writeAttachmentFile(String fileName, Uint8List bytes) async {
  final dir = await _dir();
  final file = File(p.join(dir.path, _safeName(fileName)));
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

/// Copies [sourcePath] into `attachments/` and returns the absolute path.
Future<String?> copyAttachmentFile(String sourcePath, String fileName) async {
  final dir = await _dir();
  final target = p.join(dir.path, _safeName(fileName));
  await File(sourcePath).copy(target);
  return target;
}

Future<Uint8List?> readAttachmentFile(String path) async {
  final f = File(path);
  if (!f.existsSync()) return null;
  return await f.readAsBytes();
}

Future<void> deleteAttachmentFile(String path) async {
  final f = File(path);
  if (f.existsSync()) await f.delete();
}
