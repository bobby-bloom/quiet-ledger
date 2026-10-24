import 'package:drift/drift.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/core/ledger/ledger_repository.dart';

import '../../helpers/test_app.dart';

/// Reference data for transaction tests, written through [SyncWriter].
class Seed {
  Seed._(this.db, this.writer, this.ledger);

  final AppDatabase db;
  final SyncWriter writer;
  final LedgerRepository ledger;

  late String checking;
  late String savings;
  late String groceries;
  late String household;
  late String eatingOut;
  late String salary;
  late String vacationTag;
  late String receiptField;

  static Future<Seed> create(AppDatabase db) async {
    final writer = SyncWriter(db, testClock(node: 'seed'), 'seed');
    final s = Seed._(db, writer, LedgerRepository(db, writer));
    s.checking = await s.account('Everyday checking', 100000);
    s.savings = await s.account('Holiday savings', 0);
    s.groceries = await s.category('Groceries');
    s.household = await s.category('Household', parentId: s.groceries);
    s.eatingOut = await s.category('Eating out');
    s.salary = await s.category('Salary', kind: CategoryKind.income);
    s.vacationTag = await writer.insert(
      db.tags,
      const TagsCompanion(name: Value('vacation')),
    );
    s.receiptField = await writer.insert(
      db.customFieldDefs,
      const CustomFieldDefsCompanion(
        name: Value('Receipt no.'),
        type: Value(CustomFieldType.text),
      ),
    );
    return s;
  }

  Future<String> account(String name, int opening) => writer.insert(
    db.accounts,
    AccountsCompanion(
      name: Value(name),
      type: const Value(AccountType.checking),
      openingBalanceMinor: Value(opening),
      openingDate: Value(DateTime(2026)),
    ),
  );

  Future<String> category(
    String name, {
    CategoryKind kind = CategoryKind.expense,
    String? parentId,
  }) => writer.insert(
    db.categories,
    CategoriesCompanion(
      name: Value(name),
      kind: Value(kind),
      parentId: Value(parentId),
    ),
  );
}
