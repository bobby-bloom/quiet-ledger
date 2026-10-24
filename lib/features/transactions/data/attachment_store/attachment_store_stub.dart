import 'dart:typed_data';

/// Whether attachments are stored as files (false: bytes in the DB).
const bool attachmentsUseFiles = false;

/// Stores [bytes] as a file and returns its absolute path (unsupported).
Future<String?> writeAttachmentFile(String fileName, Uint8List bytes) async =>
    null;

/// Copies the file at [sourcePath] into attachment storage (unsupported).
Future<String?> copyAttachmentFile(String sourcePath, String fileName) async =>
    null;

/// Reads a stored attachment file (unsupported).
Future<Uint8List?> readAttachmentFile(String path) async => null;

/// Deletes a stored attachment file (unsupported).
Future<void> deleteAttachmentFile(String path) async {}
