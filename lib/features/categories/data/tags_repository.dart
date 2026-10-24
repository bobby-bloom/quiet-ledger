import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/features/categories/data/references.dart';

final tagsRepositoryProvider = Provider<TagsRepository>(
  (ref) => TagsRepository(
    ref.watch(databaseProvider),
    ref.watch(syncWriterProvider),
  ),
);

/// Thrown when a tag name is empty or already used by another live tag.
class TagNameException implements Exception {
  const TagNameException({required this.taken});

  /// true = name already exists, false = name empty.
  final bool taken;

  @override
  String toString() => 'TagNameException(taken: $taken)';
}

/// Writes for tags. Tag names are unique (case-insensitive) among live
/// tags.
class TagsRepository {
  TagsRepository(this.db, this.writer);

  final AppDatabase db;
  final SyncWriter writer;

  /// Normalises a tag name: trims and drops a leading '#'.
  static String normalize(String name) {
    var n = name.trim();
    while (n.startsWith('#')) {
      n = n.substring(1).trimLeft();
    }
    return n;
  }

  Future<Tag?> byName(String name) async {
    final n = normalize(name).toLowerCase();
    final rows = await (db.select(
      db.tags,
    )..where((t) => t.deletedAt.isNull() & t.name.lower().equals(n))).get();
    return rows.firstOrNull;
  }

  Future<String> create(String name, {int? color}) =>
      writer.transaction(() async {
        final n = await _checkName(name, null);
        return await writer.insert(
          db.tags,
          TagsCompanion(name: Value(n), color: Value(color)),
        );
      });

  /// Returns the id of the live tag called [name], creating it if needed
  /// (used by import and quick add).
  Future<String> ensure(String name, {int? color}) =>
      writer.transaction(() async {
        final existing = await byName(name);
        if (existing != null) return existing.id;
        return await create(name, color: color);
      });

  Future<void> update(String id, {required String name, int? color}) =>
      writer.transaction(() async {
        final n = await _checkName(name, id);
        await writer.update(
          db.tags,
          id,
          TagsCompanion(name: Value(n), color: Value(color)),
        );
      });

  Future<void> setArchived(String id, {required bool archived}) =>
      writer.update(db.tags, id, TagsCompanion(archived: Value(archived)));

  /// Soft-deletes the tag and removes it from all transactions.
  Future<void> delete(String id) => writer.transaction(() async {
    await writer.deleteWhere(db.transactionTags, 'tag_id', id);
    await writer.delete(db.tags, id);
  });

  /// Merges [sourceId] into [targetId]: transactions tagged with the source
  /// get the target (without duplicates), JSON references are re-pointed
  /// and the source is soft-deleted.
  Future<void> merge(String sourceId, String targetId) => writer.transaction(
    () async {
      if (sourceId == targetId) {
        throw ArgumentError.value(targetId, 'targetId', 'same as source');
      }
      final links = await (db.select(
        db.transactionTags,
      )..where((t) => t.tagId.equals(sourceId) & t.deletedAt.isNull())).get();
      final alreadyTagged = {
        for (final r in await (db.select(
          db.transactionTags,
        )..where((t) => t.tagId.equals(targetId) & t.deletedAt.isNull())).get())
          r.transactionId,
      };
      for (final l in links) {
        if (alreadyTagged.contains(l.transactionId)) {
          await writer.delete(db.transactionTags, l.id);
        } else {
          await writer.update(
            db.transactionTags,
            l.id,
            TransactionTagsCompanion(tagId: Value(targetId)),
          );
          alreadyTagged.add(l.transactionId);
        }
      }
      await repointJsonReferences(db, writer, sourceId, targetId);
      await writer.delete(db.tags, sourceId);
    },
  );

  Future<String> _checkName(String name, String? selfId) async {
    final n = normalize(name);
    if (n.isEmpty) throw const TagNameException(taken: false);
    final other = await byName(n);
    if (other != null && other.id != selfId) {
      throw const TagNameException(taken: true);
    }
    return n;
  }
}

/// Number of tagged live transactions per tag id.
final tagUsageCountsProvider = StreamProvider<Map<String, int>>((ref) {
  final db = ref.watch(databaseProvider);
  return db
      .customSelect(
        'SELECT tt.tag_id AS id, COUNT(DISTINCT tt.transaction_id) AS c '
        'FROM transaction_tags tt JOIN transactions t ON t.id = tt.transaction_id '
        'WHERE tt.deleted_at IS NULL AND t.deleted_at IS NULL GROUP BY tt.tag_id',
        readsFrom: {db.transactionTags, db.transactions},
      )
      .watch()
      .map(
        (rows) => {
          for (final r in rows) r.read<String>('id'): r.read<int>('c'),
        },
      );
});
