import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/features/transactions/data/attachment_store/attachment_store.dart';

final attachmentsRepositoryProvider = Provider<AttachmentsRepository>(
  (ref) => AttachmentsRepository(
    ref.watch(databaseProvider),
    ref.watch(syncWriterProvider),
  ),
);

/// Live attachments of one transaction.
final attachmentsForProvider = StreamProvider.family<List<Attachment>, String>(
  (ref, txnId) => ref.watch(attachmentsRepositoryProvider).watchFor(txnId),
);

/// A file picked in quick add that is not saved yet.
@immutable
class PendingAttachment {
  const PendingAttachment({
    required this.fileName,
    required this.bytes,
    this.sourcePath,
  });

  final String fileName;
  final Uint8List bytes;

  /// Original path on native platforms (copied instead of re-written).
  final String? sourcePath;

  String get mimeType => mimeTypeFor(fileName);
}

/// Best-effort MIME type from the file extension.
String mimeTypeFor(String fileName) {
  final ext = fileName.contains('.')
      ? fileName.substring(fileName.lastIndexOf('.') + 1).toLowerCase()
      : '';
  return switch (ext) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    'bmp' => 'image/bmp',
    'pdf' => 'application/pdf',
    'txt' => 'text/plain',
    'csv' => 'text/csv',
    'html' || 'htm' => 'text/html',
    _ => 'application/octet-stream',
  };
}

/// Receipt attachments. Native: the file is copied to
/// `<app support>/attachments/` and `filePath` holds its absolute path.
/// Web: the bytes are stored in `attachments.data`.
class AttachmentsRepository {
  AttachmentsRepository(this.db, this.writer);

  final AppDatabase db;
  final SyncWriter writer;

  Stream<List<Attachment>> watchFor(String txnId) =>
      (db.select(db.attachments)
            ..where((a) => a.transactionId.equals(txnId) & a.deletedAt.isNull())
            ..orderBy([(a) => OrderingTerm(expression: a.createdAt)]))
          .watch();

  /// Stores [file] and links it to [txnId]. Returns the attachment id.
  Future<String> add(String txnId, PendingAttachment file) async {
    String? path;
    if (attachmentsUseFiles) {
      path = file.sourcePath != null
          ? await copyAttachmentFile(file.sourcePath!, file.fileName)
          : await writeAttachmentFile(file.fileName, file.bytes);
    }
    return await writer.insert(
      db.attachments,
      AttachmentsCompanion(
        transactionId: Value(txnId),
        fileName: Value(file.fileName),
        filePath: Value(path),
        data: Value(path == null ? file.bytes : null),
        mimeType: Value(file.mimeType),
        sizeBytes: Value(file.bytes.length),
      ),
    );
  }

  Future<void> addAll(String txnId, Iterable<PendingAttachment> files) async {
    for (final f in files) {
      await add(txnId, f);
    }
  }

  /// Soft-deletes the attachment row. The file is kept so undo works; a
  /// purge job can remove files of tombstoned rows.
  Future<void> delete(String id) => writer.delete(db.attachments, id);

  Future<void> restore(String id) => writer.undelete(db.attachments, id);

  /// The attachment's content, from the DB (web) or its file (native).
  Future<Uint8List?> bytesOf(Attachment a) async {
    if (a.data != null) return a.data;
    if (a.filePath != null) return await readAttachmentFile(a.filePath!);
    return null;
  }

  /// Copies all live attachments of [fromTxnId] to [toTxnId] (duplicate).
  Future<void> copyAll(String fromTxnId, String toTxnId) async {
    final list = await watchFor(fromTxnId).first;
    for (final a in list) {
      await writer.insert(
        db.attachments,
        AttachmentsCompanion(
          transactionId: Value(toTxnId),
          fileName: Value(a.fileName),
          filePath: Value(a.filePath),
          data: Value(a.data),
          mimeType: Value(a.mimeType),
          sizeBytes: Value(a.sizeBytes),
        ),
      );
    }
  }
}
