import 'package:drift/drift.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/core/ledger/ledger_repository.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';

import '../../helpers/test_app.dart';

/// A seeded ledger used by the report tests. Amounts in cents.
///
/// March 2026 (expenses): Rent 1000, Food 195 (Groceries 100 incl. a split
/// line of 60 and a refund of 10, Restaurants 75, Food itself 20), Fun 40
/// (archived, from a split), uncategorised 5. Income: Salary 3000.
/// Excluded noise: a transfer, a deleted and a planned transaction.
class ReportFixture {
  ReportFixture._(this.db, this.writer, this.repo);

  final AppDatabase db;
  final SyncWriter writer;
  final LedgerRepository repo;

  late final String checking;
  late final String savings;
  late final String card;
  late final String loan;
  late final String hidden;

  late final String food;
  late final String groceries;
  late final String restaurants;
  late final String rent;
  late final String fun;
  late final String salary;

  late final String vacation;
  late final String oneOff;
  late final String projectField;

  static Future<ReportFixture> create(AppDatabase db) async {
    final writer = SyncWriter(db, testClock(), 'dev-1');
    final f = ReportFixture._(db, writer, LedgerRepository(db, writer));
    await f._seed();
    return f;
  }

  Future<String> _account(
    String name,
    AccountType type,
    int opening,
    DateTime openingDate, {
    bool inNetWorth = true,
  }) => writer.insert(
    db.accounts,
    AccountsCompanion(
      name: Value(name),
      type: Value(type),
      openingBalanceMinor: Value(opening),
      openingDate: Value(openingDate),
      includeInNetWorth: Value(inNetWorth),
    ),
  );

  Future<String> _category(
    String name, {
    String? parent,
    CategoryKind kind = CategoryKind.expense,
    bool archived = false,
  }) => writer.insert(
    db.categories,
    CategoriesCompanion(
      name: Value(name),
      parentId: Value(parent),
      kind: Value(kind),
      archived: Value(archived),
    ),
  );

  Future<String> expense(
    DateTime date,
    int cents, {
    String? category,
    String? account,
    String? payee,
    List<String> tags = const [],
    Map<String, Object?> fields = const {},
    TxnStatus status = TxnStatus.cleared,
    List<SplitDraft> splits = const [],
  }) => repo.create(
    TxnDraft(
      accountId: account ?? checking,
      amountMinor: cents,
      date: date,
      categoryId: category,
      payee: payee,
      tagIds: tags,
      customFields: fields,
      status: status,
      splits: splits,
    ),
  );

  Future<void> _seed() async {
    checking = await _account(
      'Checking',
      AccountType.checking,
      100000,
      DateTime(2025),
    );
    savings = await _account(
      'Savings',
      AccountType.savings,
      10000,
      DateTime(2026, 3),
    );
    card = await _account('Card', AccountType.creditCard, 0, DateTime(2025));
    loan = await _account('Loan', AccountType.loan, -500000, DateTime(2025));
    hidden = await _account(
      'Hidden',
      AccountType.checking,
      99900,
      DateTime(2025),
      inNetWorth: false,
    );

    food = await _category('Food');
    groceries = await _category('Groceries', parent: food);
    restaurants = await _category('Restaurants', parent: food);
    rent = await _category('Rent');
    fun = await _category('Fun', archived: true);
    salary = await _category('Salary', kind: CategoryKind.income);

    vacation = await writer.insert(
      db.tags,
      const TagsCompanion(name: Value('Vacation')),
    );
    oneOff = await writer.insert(
      db.tags,
      const TagsCompanion(name: Value('One-off')),
    );
    projectField = await writer.insert(
      db.customFieldDefs,
      const CustomFieldDefsCompanion(
        name: Value('Project'),
        type: Value(CustomFieldType.select),
        options: Value('["Trip","Home"]'),
      ),
    );

    // Last year and across the year boundary.
    await expense(DateTime(2025, 3, 10), -2500, category: groceries);
    await expense(DateTime(2025, 12, 31), -1100, category: groceries);
    await expense(DateTime(2026), -2200, category: groceries);
    // February.
    await expense(DateTime(2026, 2, 10), -4000, category: groceries);
    await repo.create(
      TxnDraft(
        accountId: checking,
        amountMinor: -20000,
        date: DateTime(2026, 2, 15),
        type: TxnType.transfer,
        transferAccountId: loan,
      ),
    );

    // March.
    await repo.create(
      TxnDraft(
        accountId: checking,
        amountMinor: 300000,
        date: DateTime(2026, 3),
        type: TxnType.income,
        categoryId: salary,
        payee: 'Employer',
      ),
    );
    await expense(
      DateTime(2026, 3, 5),
      -5000,
      category: groceries,
      payee: 'Corner Grocer',
    );
    await expense(
      DateTime(2026, 3, 10),
      -3000,
      category: restaurants,
      payee: 'Pizza',
    );
    await expense(
      DateTime(2026, 3, 12),
      -2000,
      category: food,
      payee: 'corner grocer ',
    );
    await expense(
      DateTime(2026, 3, 15),
      -100000,
      category: rent,
      payee: 'Landlord',
      tags: [oneOff],
    );
    await expense(
      DateTime(2026, 3, 20),
      -10000,
      payee: 'Market',
      splits: [
        SplitDraft(amountMinor: -6000, categoryId: groceries),
        SplitDraft(amountMinor: -4000, categoryId: fun),
      ],
    );
    await repo.create(
      TxnDraft(
        accountId: checking,
        amountMinor: -50000,
        date: DateTime(2026, 3, 21),
        type: TxnType.transfer,
        transferAccountId: savings,
      ),
    );
    final deleted = await expense(
      DateTime(2026, 3, 22),
      -99900,
      category: rent,
    );
    await repo.delete(deleted);
    await expense(
      DateTime(2026, 3, 25),
      -4500,
      account: card,
      category: restaurants,
      payee: 'Trattoria',
      tags: [vacation],
      fields: {projectField: 'Trip'},
    );
    // Refund.
    await expense(
      DateTime(2026, 3, 26),
      1000,
      category: groceries,
      payee: 'Corner Grocer',
    );
    await expense(
      DateTime(2026, 3, 27),
      -7700,
      category: rent,
      status: TxnStatus.planned,
    );
    await expense(DateTime(2026, 3, 28), -500);
  }
}
