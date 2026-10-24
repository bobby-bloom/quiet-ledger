import 'package:drift/drift.dart';
import 'package:personal_finance/core/db/tables.dart';

export 'package:personal_finance/core/db/tables.dart';

part 'database.g.dart';

/// Database name; the native file is `<name>.sqlite`.
const appDbName = 'personal_finance';

/// All synced tables, used by generic helpers (export bundle, purge, sync).
const syncedTableNames = <String>[
  'account_groups',
  'accounts',
  'categories',
  'transactions',
  'transaction_splits',
  'tags',
  'transaction_tags',
  'custom_field_defs',
  'custom_field_values',
  'attachments',
  'rules',
  'transaction_templates',
  'recurring_rules',
  'recurring_amount_changes',
  'budgets',
  'budget_templates',
  'goals',
  'scenarios',
  'saved_filters',
  'dashboard_layouts',
  'import_profiles',
  'import_batches',
  'settings',
];

@DriftDatabase(
  tables: [
    AccountGroups,
    Accounts,
    Categories,
    Transactions,
    TransactionSplits,
    Tags,
    TransactionTags,
    CustomFieldDefs,
    CustomFieldValues,
    Attachments,
    Rules,
    TransactionTemplates,
    RecurringRules,
    RecurringAmountChanges,
    Budgets,
    BudgetTemplates,
    Goals,
    Scenarios,
    SavedFilters,
    DashboardLayouts,
    ImportProfiles,
    ImportBatches,
    Settings,
    ChangeLog,
    SyncState,
  ],
  include: {'search.drift'},
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // v2: lookup indexes and search refresh on category/tag rename.
        await m.createIndex(txnPayee);
        await m.createIndex(attachmentTxn);
        await m.createIndex(changeLogEntity);
        await m.createTrigger(txnSearchCatAu);
        await m.createTrigger(txnSearchTagnameAu);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = OFF');
      await customStatement('PRAGMA journal_mode = WAL');
    },
  );

  /// Clears and rebuilds the FTS index.
  Future<void> rebuildSearch() => transaction(() async {
    await customStatement('DELETE FROM txn_search');
    await rebuildSearchIndex();
  });

  /// Looks up a table by its SQL name.
  TableInfo<Table, dynamic> tableByName(String name) =>
      allTables.firstWhere((t) => t.actualTableName == name);
}
