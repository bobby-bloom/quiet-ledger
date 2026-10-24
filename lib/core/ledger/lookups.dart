import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/ledger/ledger_repository.dart';

// Shared, reactive lookups of reference data. Feature code reads these
// instead of re-querying. All lists exclude soft-deleted rows but include
// archived ones (filter with `.where((a) => !a.archived)` where needed).

final accountsProvider = StreamProvider<List<Account>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.accounts)
        ..where((a) => a.deletedAt.isNull())
        ..orderBy([
          (a) => OrderingTerm(expression: a.sortOrder),
          (a) => OrderingTerm(expression: a.name),
        ]))
      .watch();
});

final accountGroupsProvider = StreamProvider<List<AccountGroup>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.accountGroups)
        ..where((a) => a.deletedAt.isNull())
        ..orderBy([(a) => OrderingTerm(expression: a.sortOrder)]))
      .watch();
});

final categoriesProvider = StreamProvider<List<Category>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.categories)
        ..where((c) => c.deletedAt.isNull())
        ..orderBy([
          (c) => OrderingTerm(expression: c.sortOrder),
          (c) => OrderingTerm(expression: c.name),
        ]))
      .watch();
});

final tagsProvider = StreamProvider<List<Tag>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.tags)
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm(expression: t.name)]))
      .watch();
});

final customFieldDefsProvider = StreamProvider<List<CustomFieldDef>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.customFieldDefs)
        ..where((c) => c.deletedAt.isNull())
        ..orderBy([(c) => OrderingTerm(expression: c.sortOrder)]))
      .watch();
});

/// Id -> entity maps for fast lookups in lists.
final accountMapProvider = Provider<Map<String, Account>>(
  (ref) => {
    for (final a in ref.watch(accountsProvider).value ?? const <Account>[])
      a.id: a,
  },
);

final categoryMapProvider = Provider<Map<String, Category>>(
  (ref) => {
    for (final c in ref.watch(categoriesProvider).value ?? const <Category>[])
      c.id: c,
  },
);

final tagMapProvider = Provider<Map<String, Tag>>(
  (ref) => {
    for (final t in ref.watch(tagsProvider).value ?? const <Tag>[]) t.id: t,
  },
);

/// Current balances (cleared + pending) per account id.
final accountBalancesProvider = StreamProvider<Map<String, int>>(
  (ref) => ref.watch(ledgerRepositoryProvider).watchBalances(),
);

/// "Parent › Child" display name for a category.
String categoryPath(
  Category c,
  Map<String, Category> all, {
  String sep = ' › ',
}) {
  final parent = c.parentId == null ? null : all[c.parentId];
  return parent == null ? c.name : '${parent.name}$sep${c.name}';
}

/// Categories as a two-level tree: top-level categories with their children.
List<(Category parent, List<Category> children)> categoryTree(
  List<Category> all, {
  CategoryKind? kind,
  bool includeArchived = false,
}) {
  final visible = all.where(
    (c) => (includeArchived || !c.archived) && (kind == null || c.kind == kind),
  );
  final byParent = groupBy(visible, (c) => c.parentId);
  return [
    for (final p in byParent[null] ?? const <Category>[])
      (p, byParent[p.id] ?? const <Category>[]),
  ];
}
