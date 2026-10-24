import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/core/ledger/ledger_repository.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:sqlite3/sqlite3.dart';

import '../helpers/test_app.dart';

Future<int> _matches(AppDatabase db, String q) async {
  final r = await db
      .customSelect(
        'SELECT count(*) AS c FROM txn_search WHERE txn_search MATCH ?',
        variables: [Variable<String>(q)],
      )
      .getSingle();
  return r.read<int>('c');
}

void main() {
  test('renaming a category or tag updates the search index', () async {
    final db = newTestDb();
    addTearDown(db.close);
    final w = SyncWriter(db, testClock(), 'd');
    final repo = LedgerRepository(db, w);
    final acc = await w.insert(
      db.accounts,
      AccountsCompanion(
        name: const Value('A'),
        type: const Value(AccountType.checking),
        openingDate: Value(DateTime(2026)),
      ),
    );
    final cat = await w.insert(
      db.categories,
      const CategoriesCompanion(
        name: Value('Food'),
        kind: Value(CategoryKind.expense),
      ),
    );
    final tag = await w.insert(
      db.tags,
      const TagsCompanion(name: Value('trip')),
    );
    await repo.create(
      TxnDraft(
        accountId: acc,
        amountMinor: -100,
        date: DateTime(2026, 5),
        categoryId: cat,
        tagIds: [tag],
      ),
    );
    await w.update(
      db.categories,
      cat,
      const CategoriesCompanion(name: Value('Groceries')),
    );
    await w.update(db.tags, tag, const TagsCompanion(name: Value('holiday')));
    expect(await _matches(db, 'groceries'), 1);
    expect(await _matches(db, 'food'), 0);
    expect(await _matches(db, 'holiday'), 1);
    expect(await _matches(db, 'trip'), 0);
  });

  test('a v1 database upgrades to the current schema', () async {
    // Create a v1 database: full schema, then drop the v2 additions and set
    // user_version = 1.
    final raw = sqlite3.openInMemory();
    final v1 = AppDatabase(
      NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
    );
    await v1.customSelect('SELECT 1').get();
    for (final s in [
      'DROP INDEX txn_payee',
      'DROP INDEX attachment_txn',
      'DROP INDEX change_log_entity',
      'DROP TRIGGER txn_search_cat_au',
      'DROP TRIGGER txn_search_tagname_au',
      'DROP TABLE safety_copies',
      'PRAGMA user_version = 1',
    ]) {
      await v1.customStatement(s);
    }
    await v1.close();

    final v2 = AppDatabase(NativeDatabase.opened(raw));
    addTearDown(v2.close);
    final objects = await v2
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type IN ('index','trigger')",
        )
        .get();
    final names = objects.map((r) => r.read<String>('name')).toSet();
    expect(
      names,
      containsAll([
        'txn_payee',
        'attachment_txn',
        'change_log_entity',
        'txn_search_cat_au',
        'txn_search_tagname_au',
      ]),
    );
    final version = await v2.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.first, AppDatabase.currentSchemaVersion);
    await v2.customSelect('SELECT count(*) FROM safety_copies').get();
  });

  test('a v2 database upgrades to v3 and keeps its data', () async {
    final raw = sqlite3.openInMemory();
    final v2 = AppDatabase(
      NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
    );
    final w = SyncWriter(v2, testClock(), 'd');
    await w.insert(v2.tags, const TagsCompanion(name: Value('kept')));
    await v2.customStatement('DROP TABLE safety_copies');
    await v2.customStatement('PRAGMA user_version = 2');
    await v2.close();

    final v3 = AppDatabase(NativeDatabase.opened(raw));
    addTearDown(v3.close);
    expect((await v3.select(v3.tags).get()).single.name, 'kept');
    expect(await v3.select(v3.safetyCopies).get(), isEmpty);
  });
}
