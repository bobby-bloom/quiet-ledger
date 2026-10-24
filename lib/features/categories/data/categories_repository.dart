import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/core/ledger/ledger_repository.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/features/categories/data/references.dart';
import 'package:personal_finance/features/categories/domain/default_categories.dart';
import 'package:personal_finance/features/categories/domain/drafts.dart';

final categoriesRepositoryProvider = Provider<CategoriesRepository>(
  (ref) => CategoriesRepository(
    ref.watch(databaseProvider),
    ref.watch(syncWriterProvider),
    ref.watch(ledgerRepositoryProvider),
  ),
);

/// Why a category operation was refused.
enum CategoryError {
  /// Parent must be a live top-level category of the same kind.
  invalidParent,

  /// A category with subcategories cannot become a subcategory.
  hasChildren,

  /// Delete refused: transactions, splits or budgets use it.
  inUse,

  /// Merge: source and target must differ and have the same kind.
  invalidMergeTarget,

  /// Merge: a category with subcategories can only be merged into a
  /// top-level category.
  mergeWouldNest,
  notFound,
}

class CategoryException implements Exception {
  const CategoryException(this.error);

  final CategoryError error;

  @override
  String toString() => 'CategoryException(${error.name})';
}

/// How often a category is referenced.
class CategoryUsage {
  const CategoryUsage({
    required this.transactions,
    required this.splits,
    required this.budgets,
    required this.children,
  });

  final int transactions;
  final int splits;
  final int budgets;
  final int children;

  bool get inUse => transactions > 0 || splits > 0 || budgets > 0;
}

/// Writes for the two-level category hierarchy. All writes go through
/// [SyncWriter]; transaction category changes go through
/// [LedgerRepository].
class CategoriesRepository {
  CategoriesRepository(this.db, this.writer, this.ledger);

  final AppDatabase db;
  final SyncWriter writer;
  final LedgerRepository ledger;

  Future<Category?> byId(String id) => (db.select(
    db.categories,
  )..where((c) => c.id.equals(id) & c.deletedAt.isNull())).getSingleOrNull();

  Future<List<Category>> _children(String parentId) =>
      (db.select(db.categories)
            ..where((c) => c.parentId.equals(parentId) & c.deletedAt.isNull())
            ..orderBy([(c) => OrderingTerm(expression: c.sortOrder)]))
          .get();

  /// Creates a category at the end of its siblings. A subcategory takes the
  /// kind of its parent.
  Future<String> create(CategoryDraft draft) => writer.transaction(() async {
    _check(draft);
    var d = draft;
    if (d.parentId != null) {
      final parent = await _validParent(d.parentId!, null);
      d = d.copyWith(kind: parent.kind);
    }
    final order = await _nextOrder(d.parentId, d.kind);
    return await writer.insert(
      db.categories,
      _companion(d).copyWith(sortOrder: Value(order)),
    );
  });

  /// Updates category [id]. Moving it under another parent appends it to
  /// that parent's children; a kind change also applies to its children.
  Future<void> update(String id, CategoryDraft draft) => writer.transaction(
    () async {
      _check(draft);
      final existing = await byId(id);
      if (existing == null) {
        throw const CategoryException(CategoryError.notFound);
      }
      final children = await _children(id);
      var d = draft;
      if (d.parentId != null) {
        if (children.isNotEmpty) {
          throw const CategoryException(CategoryError.hasChildren);
        }
        final parent = await _validParent(d.parentId!, id);
        d = d.copyWith(kind: parent.kind);
      }
      var c = _companion(d);
      if (d.parentId != existing.parentId || d.kind != existing.kind) {
        c = c.copyWith(sortOrder: Value(await _nextOrder(d.parentId, d.kind)));
      }
      await writer.update(db.categories, id, c);
      for (final ch in children) {
        if (ch.kind != d.kind) {
          await writer.update(
            db.categories,
            ch.id,
            CategoriesCompanion(kind: Value(d.kind)),
          );
        }
      }
      if (d.archived != existing.archived) {
        await _cascadeArchive(id, d.archived, existing.parentId == null);
      }
    },
  );

  /// Archives or restores a category. Archiving a parent archives its
  /// subcategories; restoring a subcategory restores its parent.
  Future<void> setArchived(String id, {required bool archived}) =>
      writer.transaction(() async {
        final c = await byId(id);
        if (c == null) return;
        await writer.update(
          db.categories,
          id,
          CategoriesCompanion(archived: Value(archived)),
        );
        await _cascadeArchive(id, archived, c.parentId == null);
        if (!archived && c.parentId != null) {
          final p = await byId(c.parentId!);
          if (p != null && p.archived) {
            await writer.update(
              db.categories,
              p.id,
              const CategoriesCompanion(archived: Value(false)),
            );
          }
        }
      });

  Future<void> _cascadeArchive(String id, bool archived, bool isParent) async {
    if (!isParent || !archived) return;
    for (final ch in await _children(id)) {
      if (!ch.archived) {
        await writer.update(
          db.categories,
          ch.id,
          const CategoriesCompanion(archived: Value(true)),
        );
      }
    }
  }

  Future<void> setFavourite(String id, {required bool favourite}) =>
      writer.update(
        db.categories,
        id,
        CategoriesCompanion(favourite: Value(favourite)),
      );

  Future<CategoryUsage> usage(String id) async {
    final r = await db
        .customSelect(
          'SELECT '
          '(SELECT COUNT(*) FROM transactions WHERE category_id = ?1 '
          'AND deleted_at IS NULL) AS txns, '
          '(SELECT COUNT(*) FROM transaction_splits WHERE category_id = ?1 '
          'AND deleted_at IS NULL) AS splits, '
          '(SELECT COUNT(*) FROM budgets WHERE category_id = ?1 '
          'AND deleted_at IS NULL) + '
          '(SELECT COUNT(*) FROM budget_rules WHERE category_id = ?1 '
          'AND deleted_at IS NULL) AS budgets, '
          '(SELECT COUNT(*) FROM categories WHERE parent_id = ?1 '
          'AND deleted_at IS NULL) AS children',
          variables: [Variable<String>(id)],
          readsFrom: {
            db.transactions,
            db.transactionSplits,
            db.budgets,
            db.budgetRules,
            db.categories,
          },
        )
        .getSingle();
    return CategoryUsage(
      transactions: r.read<int>('txns'),
      splits: r.read<int>('splits'),
      budgets: r.read<int>('budgets'),
      children: r.read<int>('children'),
    );
  }

  /// Soft-deletes an unused category without subcategories. Throws
  /// [CategoryException] otherwise (archive or merge instead).
  Future<void> delete(String id) => writer.transaction(() async {
    final u = await usage(id);
    if (u.children > 0) {
      throw const CategoryException(CategoryError.hasChildren);
    }
    if (u.inUse) throw const CategoryException(CategoryError.inUse);
    await writer.delete(db.categories, id);
  });

  /// Restores a deleted category (undo).
  Future<void> restore(String id) => writer.undelete(db.categories, id);

  /// Merges [sourceId] into [targetId]: moves all transactions, splits,
  /// budgets (amounts of the same period are added up) and subcategories to
  /// the target, re-points JSON references (templates, rules, filters) and
  /// soft-deletes the source.
  Future<void> merge(String sourceId, String targetId) =>
      writer.transaction(() async {
        final source = await byId(sourceId);
        final target = await byId(targetId);
        if (source == null || target == null) {
          throw const CategoryException(CategoryError.notFound);
        }
        if (sourceId == targetId ||
            source.kind != target.kind ||
            target.parentId == sourceId) {
          throw const CategoryException(CategoryError.invalidMergeTarget);
        }
        final children = await _children(sourceId);
        if (children.isNotEmpty && target.parentId != null) {
          throw const CategoryException(CategoryError.mergeWouldNest);
        }

        // Transactions (through the ledger so search & peers stay right).
        final txnIds =
            await (db.selectOnly(db.transactions)
                  ..addColumns([db.transactions.id])
                  ..where(
                    db.transactions.categoryId.equals(sourceId) &
                        db.transactions.deletedAt.isNull(),
                  ))
                .map((r) => r.read(db.transactions.id)!)
                .get();
        if (txnIds.isNotEmpty) {
          await ledger.bulkUpdate(txnIds, categoryId: targetId);
        }

        // Splits.
        final splits =
            await (db.select(db.transactionSplits)..where(
                  (s) => s.categoryId.equals(sourceId) & s.deletedAt.isNull(),
                ))
                .get();
        for (final s in splits) {
          await writer.update(
            db.transactionSplits,
            s.id,
            TransactionSplitsCompanion(categoryId: Value(targetId)),
          );
        }

        // Budgets: combine with an existing target budget of the period.
        final targetBudgets = {
          for (final b
              in await (db.select(db.budgets)..where(
                    (b) => b.categoryId.equals(targetId) & b.deletedAt.isNull(),
                  ))
                  .get())
            (b.periodStart, b.periodEnd): b,
        };
        final sourceBudgets =
            await (db.select(db.budgets)..where(
                  (b) => b.categoryId.equals(sourceId) & b.deletedAt.isNull(),
                ))
                .get();
        for (final b in sourceBudgets) {
          final existing = targetBudgets[(b.periodStart, b.periodEnd)];
          if (existing != null) {
            await writer.update(
              db.budgets,
              existing.id,
              BudgetsCompanion(
                amountMinor: Value(existing.amountMinor + b.amountMinor),
                rolloverMinor: Value(existing.rolloverMinor + b.rolloverMinor),
                // The sum is no rule's amount: keep it as set by hand.
                ruleId: const Value(null),
              ),
            );
            await writer.delete(db.budgets, b.id);
          } else {
            await writer.update(
              db.budgets,
              b.id,
              BudgetsCompanion(categoryId: Value(targetId)),
            );
          }
        }

        // Repeating budgets, per length: moved to the target, or, where the
        // target has its own of that length, the source's newest amount is
        // added to them (like the amounts of a period above).
        final targetRules =
            await (db.select(db.budgetRules)..where(
                  (r) => r.categoryId.equals(targetId) & r.deletedAt.isNull(),
                ))
                .get();
        final sourceRules =
            await (db.select(db.budgetRules)..where(
                  (r) => r.categoryId.equals(sourceId) & r.deletedAt.isNull(),
                ))
                .get();
        for (final cadence in BudgetCadence.values) {
          final targets = [
            for (final r in targetRules)
              if (r.cadence == cadence) r,
          ];
          final sources = [
            for (final r in sourceRules)
              if (r.cadence == cadence) r,
          ];
          if (sources.isEmpty) continue;
          if (targets.isEmpty) {
            for (final r in sources) {
              await writer.update(
                db.budgetRules,
                r.id,
                BudgetRulesCompanion(categoryId: Value(targetId)),
              );
            }
            continue;
          }
          final newest = sources.reduce(
            (a, b) => b.updatedAt.compareTo(a.updatedAt) > 0 ? b : a,
          );
          for (final t in targets) {
            await writer.update(
              db.budgetRules,
              t.id,
              BudgetRulesCompanion(
                amountMinor: Value(t.amountMinor + newest.amountMinor),
              ),
            );
          }
          for (final r in sources) {
            await writer.delete(db.budgetRules, r.id);
          }
        }

        // Subcategories move under the target, after its own children.
        var order = await _nextOrder(targetId, target.kind);
        for (final ch in children) {
          await writer.update(
            db.categories,
            ch.id,
            CategoriesCompanion(
              parentId: Value(targetId),
              sortOrder: Value(order++),
            ),
          );
        }

        await repointJsonReferences(db, writer, sourceId, targetId);
        await writer.delete(db.categories, sourceId);
      });

  /// Sets the order of siblings to their position in [orderedIds].
  Future<void> reorder(List<String> orderedIds) => writer.transaction(() async {
    for (var i = 0; i < orderedIds.length; i++) {
      final c = await byId(orderedIds[i]);
      if (c == null || c.sortOrder == i) continue;
      await writer.update(
        db.categories,
        c.id,
        CategoriesCompanion(sortOrder: Value(i)),
      );
    }
  });

  /// Seeds the default set when no categories exist (see
  /// [seedDefaultCategories]).
  Future<void> seedDefaults(DefaultCategorySet set) =>
      seedDefaultCategories(writer, db, set);

  // ------------------------------------------------------------ helpers ---

  void _check(CategoryDraft d) {
    final p = d.validate();
    if (p.isNotEmpty) throw ArgumentError('Invalid category: ${p.join(', ')}');
  }

  Future<Category> _validParent(String parentId, String? selfId) async {
    final parent = await byId(parentId);
    if (parent == null || parent.parentId != null || parent.id == selfId) {
      throw const CategoryException(CategoryError.invalidParent);
    }
    return parent;
  }

  Future<int> _nextOrder(String? parentId, CategoryKind kind) async {
    final max = db.categories.sortOrder.max();
    final q = db.selectOnly(db.categories)..addColumns([max]);
    final live = db.categories.deletedAt.isNull();
    q.where(
      parentId == null
          ? live &
                db.categories.parentId.isNull() &
                db.categories.kind.equalsValue(kind)
          : live & db.categories.parentId.equals(parentId),
    );
    final row = await q.getSingle();
    return (row.read(max) ?? -1) + 1;
  }

  CategoriesCompanion _companion(CategoryDraft d) => CategoriesCompanion(
    name: Value(d.name.trim()),
    kind: Value(d.kind),
    parentId: Value(d.parentId),
    icon: Value(d.icon),
    color: Value(d.color),
    favourite: Value(d.favourite),
    archived: Value(d.archived),
    rolloverOverride: Value(d.rolloverOverride?.name),
    warnThresholdOverride: Value(d.warnThresholdOverride),
  );
}

/// Number of transactions and splits per category id (live rows).
final categoryUsageCountsProvider = StreamProvider<Map<String, int>>((ref) {
  final db = ref.watch(databaseProvider);
  return db
      .customSelect(
        'SELECT category_id AS id, COUNT(*) AS c FROM ( '
        'SELECT category_id FROM transactions WHERE deleted_at IS NULL '
        'AND category_id IS NOT NULL '
        'UNION ALL SELECT category_id FROM transaction_splits '
        'WHERE deleted_at IS NULL AND category_id IS NOT NULL) '
        'GROUP BY category_id',
        readsFrom: {db.transactions, db.transactionSplits},
      )
      .watch()
      .map(
        (rows) => {
          for (final r in rows) r.read<String>('id'): r.read<int>('c'),
        },
      );
});
