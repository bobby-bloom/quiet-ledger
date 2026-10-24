import 'dart:typed_data';

/// Whether attachments are stored as files (false: bytes in the DB).
const bool attachmentsUseFiles = false;

/// Stores [bytes] as a file and returns its stored name (unsupported).
Future<String?> writeAttachmentFile(String fileName, Uint8List bytes) async =>
    null;

/// Copies the file at [sourcePath] into attachment storage (unsupported).
Future<String?> copyAttachmentFile(String sourcePath, String fileName) async =>
    null;

/// Absolute path of a stored attachment file (unsupported).
Future<String?> resolveAttachmentPath(String stored) async => null;

/// Relative name for an old absolute path (unsupported).
Future<String?> relativeAttachmentPath(String stored) async => null;

/// Reads a stored attachment file (unsupported).
Future<Uint8List?> readAttachmentFile(String stored) async => null;

/// Deletes a stored attachment file (unsupported).
Future<void> deleteAttachmentFile(String stored) async {}
