import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/core/ledger/ledger_repository.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/core/sync/raw_rows.dart';

import '../../helpers/test_app.dart';

/// Ids of the fixture data set.
class Fixture {
  late String checking;
  late String savings;
  late String food;
  late String groceries;
  late String household;
  late String salary;
  late String tagHoliday;
  late String tagWork;
  late String cfReceipt;
  late String cfWarranty;
  late String expense;
  late String income;
  late String transfer;
  late String split;
  late String deleted;
}

/// Writes a varied data set through the normal write path: hierarchy,
/// tags, custom fields, a transfer, a split, a soft-deleted transaction,
/// an attachment blob, settings and awkward text (quotes, line breaks,
/// umlauts, empty strings).
Future<Fixture> seed(AppDatabase db, {SyncWriter? writer}) async {
  final w = writer ?? SyncWriter(db, testClock(), 'dev-1');
  final repo = LedgerRepository(db, w);
  final f = Fixture();
  Future<String> account(String name, int opening) => w.insert(
    db.accounts,
    AccountsCompanion(
      name: Value(name),
      type: const Value(AccountType.checking),
      openingBalanceMinor: Value(opening),
      openingDate: Value(DateTime(2026)),
      note: const Value(''),
    ),
  );
  Future<String> category(
    String name, {
    String? parent,
    CategoryKind kind = CategoryKind.expense,
  }) => w.insert(
    db.categories,
    CategoriesCompanion(
      name: Value(name),
      parentId: Value(parent),
      kind: Value(kind),
    ),
  );
  f
    ..checking = await account('Girokonto', 100000)
    ..savings = await account('Tagesgeld', 0)
    ..food = await category('Essen')
    ..household = await category('Haushalt');
  f
    ..groceries = await category('Lebensmittel', parent: f.food)
    ..salary = await category('Gehalt', kind: CategoryKind.income)
    ..tagHoliday = await w.insert(
      db.tags,
      const TagsCompanion(name: Value('Urlaub')),
    )
    ..tagWork = await w.insert(
      db.tags,
      const TagsCompanion(name: Value('Arbeit')),
    )
    ..cfReceipt = await w.insert(
      db.customFieldDefs,
      const CustomFieldDefsCompanion(
        name: Value('Beleg'),
        type: Value(CustomFieldType.text),
        sortOrder: Value(0),
      ),
    )
    ..cfWarranty = await w.insert(
      db.customFieldDefs,
      const CustomFieldDefsCompanion(
        name: Value('Garantie bis'),
        type: Value(CustomFieldType.date),
        sortOrder: Value(1),
      ),
    );

  f.expense = await repo.create(
    TxnDraft(
      accountId: f.checking,
      amountMinor: -2550,
      date: DateTime(2026, 3, 5),
      payee: 'Bäckerei "Korn"; Filiale',
      note: 'Zeile 1\nZeile 2',
      categoryId: f.groceries,
      tagIds: [f.tagWork, f.tagHoliday],
      customFields: {f.cfReceipt: 'R-1', f.cfWarranty: '2028-03-05'},
      valueDate: DateTime(2026, 3, 6),
    ),
  );
  f.income = await repo.create(
    TxnDraft(
      accountId: f.checking,
      amountMinor: 300000,
      date: DateTime(2026, 3),
      type: TxnType.income,
      payee: 'Arbeitgeber',
      categoryId: f.salary,
      status: TxnStatus.pending,
    ),
  );
  f.transfer = await repo.create(
    TxnDraft(
      accountId: f.checking,
      amountMinor: -50000,
      date: DateTime(2026, 3, 10),
      type: TxnType.transfer,
      transferAccountId: f.savings,
    ),
  );
  f.split = await repo.create(
    TxnDraft(
      accountId: f.checking,
      amountMinor: -10000,
      date: DateTime(2026, 3, 12),
      payee: 'Kaufhaus',
      note: 'Großeinkauf',
      splits: [
        SplitDraft(amountMinor: -7000, categoryId: f.groceries),
        SplitDraft(amountMinor: -3000, categoryId: f.household, note: 'Putz'),
      ],
    ),
  );
  f.deleted = await repo.create(
    TxnDraft(
      accountId: f.savings,
      amountMinor: -100,
      date: DateTime(2026, 3, 15),
      payee: 'Gelöscht',
    ),
  );
  await repo.delete(f.deleted);

  await w.insert(
    db.attachments,
    AttachmentsCompanion(
      transactionId: Value(f.expense),
      fileName: const Value('beleg.png'),
      mimeType: const Value('image/png'),
      data: Value(Uint8List.fromList([0, 1, 2, 250, 255])),
      sizeBytes: const Value(5),
    ),
  );
  await w.insert(
    db.settings,
    SettingsCompanion(
      key: const Value('general.language'),
      value: Value(jsonEncode('de')),
    ),
    id: 'global|general.language',
  );
  return f;
}

/// Writes three raw rows into every synced table, driven by the schema so
/// new tables and columns are covered automatically: one with every column
/// set to an awkward non-default value, one with every nullable column null
/// and the rest at their "empty" value (`''`, 0, empty blob), and one
/// tombstone. Bypasses `SyncWriter` on purpose (see `raw_rows.dart`).
Future<void> fillEveryColumn(AppDatabase db) async {
  for (final name in syncedTableNames) {
    final table = db.tableByName(name);
    final cols = [for (final c in table.$columns) c.name];
    final rows = <List<Object?>>[];
    for (var i = 0; i < 3; i++) {
      rows.add([for (final c in table.$columns) _fillValue(name, c, i)]);
    }
    await insertRawRows(db, table, cols, rows);
  }
}

Object? _fillValue(String table, GeneratedColumn<Object> c, int row) {
  final full = row != 1;
  switch (c.name) {
    case 'id':
      return 'fill-$table-$row';
    case 'updated_at':
      return '${(1700000000000 + row).toString().padLeft(15, '0')}-0000$row-dev-fill';
    case 'deleted_at':
      return row == 2 ? 1767225600 : null;
  }
  if (!full && c.$nullable) return null;
  return switch (c.type) {
    DriftSqlType.bool => full ? 1 : 0,
    DriftSqlType.int || DriftSqlType.bigInt => full ? -9007199254740991 : 0,
    DriftSqlType.dateTime => full ? 4102444799 : 0,
    DriftSqlType.double => full ? -1234.5678 : 0.0,
    DriftSqlType.blob =>
      full ? Uint8List.fromList(List.generate(256, (b) => b)) : Uint8List(0),
    _ => full ? '$table.${c.name} "q"; ä€😀,\r\nline 2 ' : '',
  };
}

/// Raw rows of every synced table ordered by id.
Future<Map<String, List<Map<String, Object?>>>> dumpTables(
  AppDatabase db,
) async => {
  for (final t in syncedTableNames)
    t: await selectRawRows(db, db.tableByName(t), orderBy: 'id'),
};
