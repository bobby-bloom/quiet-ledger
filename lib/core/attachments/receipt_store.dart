import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/core/attachments/attachment_files.dart'
    as files;

/// Receipt file access for backups (export reads files, restore writes
/// them). Override [receiptStoreProvider] in tests.
abstract interface class ReceiptStore {
  /// Whether receipts live in files (native) rather than in
  /// `attachments.data` (web).
  bool get usesFiles;

  /// Bytes of the stored file, null when it is missing.
  Future<Uint8List?> read(String storedPath);

  /// Stores [bytes] under a new name (never overwrites) and returns the
  /// value for `attachments.file_path`.
  Future<String> write(String fileName, Uint8List bytes);

  Future<void> delete(String storedPath);
}

/// The platform's attachment storage (`core/attachments/attachment_files`).
class PlatformReceiptStore implements ReceiptStore {
  const PlatformReceiptStore();

  @override
  bool get usesFiles => files.attachmentsUseFiles;

  @override
  Future<Uint8List?> read(String storedPath) =>
      files.readAttachmentFile(storedPath);

  @override
  Future<String> write(String fileName, Uint8List bytes) async =>
      await files.writeAttachmentFile(fileName, bytes) ??
      (throw UnsupportedError('No file storage on this platform'));

  @override
  Future<void> delete(String storedPath) =>
      files.deleteAttachmentFile(storedPath);
}

/// In-memory store for tests.
class MemoryReceiptStore implements ReceiptStore {
  MemoryReceiptStore({this.usesFiles = true});

  @override
  final bool usesFiles;

  final Map<String, Uint8List> files = {};
  var _next = 0;

  @override
  Future<Uint8List?> read(String storedPath) async => files[storedPath];

  @override
  Future<String> write(String fileName, Uint8List bytes) async {
    final name = 'r${_next++}_$fileName';
    files[name] = bytes;
    return name;
  }

  @override
  Future<void> delete(String storedPath) async => files.remove(storedPath);
}

final receiptStoreProvider = Provider<ReceiptStore>(
  (ref) => const PlatformReceiptStore(),
);
