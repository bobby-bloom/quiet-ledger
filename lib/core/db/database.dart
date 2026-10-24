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
  'budget_rules',
  'goals',
  'scenarios',
  'saved_filters',
  'dashboard_layouts',
  'import_profiles',
  'import_batches',
  'settings',
];

/// Tables deliberately left out of backups: sync bookkeeping (reset by a
/// restore), the full-text index (rebuilt from `transactions`) and the
/// on-device safety copies. Every other table must be in
/// [syncedTableNames]; a test enforces this.
const backupExcludedTables = <String>{
  'change_log',
  'sync_state',
  'txn_search',
  'safety_copies',
};

/// The database file was written by a newer app version (schema [found] >
/// [supported]). Opening is refused so the file is never downgraded.
class NewerDatabaseException implements Exception {
  const NewerDatabaseException(this.found, this.supported);
  final int found;
  final int supported;

  @override
  String toString() =>
      'Database schema $found is newer than this app supports ($supported)';
}

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
    BudgetRules,
    Goals,
    Scenarios,
    SavedFilters,
    DashboardLayouts,
    ImportProfiles,
    ImportBatches,
    Settings,
    ChangeLog,
    SyncState,
    SafetyCopies,
  ],
  include: {'search.drift'},
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => currentSchemaVersion;

  /// Schema version this build creates and migrates to.
  static const currentSchemaVersion = 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // Drift also calls this for downgrades and would then stamp the
      // older version on a newer file. Refuse instead; the file is kept.
      if (from > to) throw NewerDatabaseException(from, to);
      if (from < 2) {
        // v2: lookup indexes and search refresh on category/tag rename.
        await m.createIndex(txnPayee);
        await m.createIndex(attachmentTxn);
        await m.createIndex(changeLogEntity);
        await m.createTrigger(txnSearchCatAu);
        await m.createTrigger(txnSearchTagnameAu);
      }
      if (from < 3) {
        // v3: on-device safety copies.
        await m.createTable(safetyCopies);
      }
      if (from < 4) {
        // v4: repeating budgets.
        await m.createTable(budgetRules);
        await m.addColumn(budgets, budgets.ruleId);
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
