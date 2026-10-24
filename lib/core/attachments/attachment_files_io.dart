import 'dart:io';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:personal_finance/core/db/sync_writer.dart';

/// Whether attachments are stored as files (false: bytes in the DB).
const bool attachmentsUseFiles = true;

/// Replaces `<app support>/attachments` in tests.
@visibleForTesting
String? attachmentsDirectoryOverride;

Future<Directory> _dir() async {
  final base =
      attachmentsDirectoryOverride ??
      p.join((await getApplicationSupportDirectory()).path, 'attachments');
  final dir = Directory(base);
  if (!dir.existsSync()) await dir.create(recursive: true);
  return dir;
}

String _safeName(String fileName) {
  final cleaned = fileName.replaceAll(RegExp(r'[^\w.\-]+'), '_');
  return '${newId()}_${cleaned.isEmpty ? 'file' : cleaned}';
}

/// Stores [bytes] under a new, unique name in `attachments/` and returns
/// that name (the value for `attachments.file_path`). Never overwrites.
Future<String?> writeAttachmentFile(String fileName, Uint8List bytes) async {
  final dir = await _dir();
  final name = _safeName(fileName);
  final file = File(p.join(dir.path, name));
  await file.writeAsBytes(bytes, flush: true);
  return name;
}

/// Copies [sourcePath] into `attachments/` and returns the stored name.
Future<String?> copyAttachmentFile(String sourcePath, String fileName) async {
  final dir = await _dir();
  final name = _safeName(fileName);
  await File(sourcePath).copy(p.join(dir.path, name));
  return name;
}

/// The absolute path of a stored attachment, or null when the file is
/// missing. [stored] is a name inside `attachments/` or, from older
/// versions, an absolute path; an absolute path that no longer exists (the
/// app container moved, e.g. iOS after an update) is looked up by its file
/// name in the current `attachments/`.
Future<String?> resolveAttachmentPath(String stored) async {
  if (p.isAbsolute(stored)) {
    if (File(stored).existsSync()) return stored;
    final moved = p.join((await _dir()).path, p.basename(stored));
    return File(moved).existsSync() ? moved : null;
  }
  final path = p.join((await _dir()).path, stored);
  return File(path).existsSync() ? path : null;
}

/// For an old absolute [stored] path whose file is in the current
/// `attachments/`: the relative name to store instead. Null when nothing
/// should change.
Future<String?> relativeAttachmentPath(String stored) async {
  if (!p.isAbsolute(stored)) return null;
  final dir = (await _dir()).path;
  final name = p.basename(stored);
  return File(p.join(dir, name)).existsSync() ? name : null;
}

Future<Uint8List?> readAttachmentFile(String stored) async {
  final path = await resolveAttachmentPath(stored);
  if (path == null) return null;
  return await File(path).readAsBytes();
}

Future<void> deleteAttachmentFile(String stored) async {
  final path = await resolveAttachmentPath(stored);
  if (path != null) await File(path).delete();
}
