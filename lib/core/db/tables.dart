import 'package:drift/drift.dart';

// Schema v1, see PLAN.md §4.2.
//
// Conventions:
// * Every table mixes in [SyncColumns]: a UUIDv7 text `id`, `createdAt`
//   (epoch millis), `updatedAt` (HLC string, sortable), `deletedAt`
//   (tombstone, epoch millis) and `originDeviceId`.
// * Never write to these tables directly: go through `SyncWriter`
//   (core/db/sync_writer.dart) so rows get stamped and the ChangeLog is
//   appended in the same DB transaction.
// * Money is always an `int` of minor units (`...Minor` columns).
// * Dates without time are stored as `DateTime` at local midnight; drift
//   stores them as unix seconds.
// * Basis points (`...Bp`) are used for rates: 1 % = 100 bp.
// * JSON columns hold text encoded with dart:convert.

mixin SyncColumns on Table {
  TextColumn get id => text()();
  IntColumn get createdAt => integer()();
  TextColumn get updatedAt => text()();
  IntColumn get deletedAt => integer().nullable()();
  TextColumn get originDeviceId => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

enum AccountType {
  checking,
  savings,
  cash,
  creditCard,
  investment,
  loan,
  otherAsset,
  otherLiability;

  bool get isLiability =>
      this == creditCard || this == loan || this == otherLiability;
}

enum CategoryKind { expense, income }

enum TxnType { expense, income, transfer }

enum TxnStatus { cleared, pending, planned }

enum CustomFieldType { text, number, date, select, multiselect, boolean }

enum PostingMode { autoPost, remindConfirm }

@DataClassName('AccountGroup')
class AccountGroups extends Table with SyncColumns {
  TextColumn get name => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

@DataClassName('Account')
class Accounts extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get type => textEnum<AccountType>()();
  TextColumn get currency => text().withDefault(const Constant('EUR'))();
  IntColumn get openingBalanceMinor =>
      integer().withDefault(const Constant(0))();
  DateTimeColumn get openingDate => dateTime()();

  /// ARGB colour value.
  IntColumn get color => integer().nullable()();

  /// Material icon key (see `app/icons.dart`).
  TextColumn get icon => text().nullable()();
  TextColumn get groupId => text().nullable()();
  BoolColumn get includeInNetWorth =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get includeInBudgets =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get includeInForecast =>
      boolean().withDefault(const Constant(true))();
  IntColumn get lowBalanceThresholdMinor => integer().nullable()();
  IntColumn get expectedAnnualReturnBp => integer().nullable()();
  IntColumn get interestRateBp => integer().nullable()();
  TextColumn get note => text().nullable()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

@DataClassName('Category')
class Categories extends Table with SyncColumns {
  TextColumn get parentId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get kind => textEnum<CategoryKind>()();
  TextColumn get icon => text().nullable()();
  IntColumn get color => integer().nullable()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// null = use global/default setting. Values: 'none', 'leftover',
  /// 'overspent', 'both'.
  TextColumn get rolloverOverride => text().nullable()();

  /// Warning threshold in percent (e.g. 80); null = global setting.
  IntColumn get warnThresholdOverride => integer().nullable()();
  BoolColumn get favourite => boolean().withDefault(const Constant(false))();
}

@DataClassName('Txn')
@TableIndex(name: 'txn_account_date', columns: {#accountId, #date})
@TableIndex(name: 'txn_date', columns: {#date})
@TableIndex(name: 'txn_category', columns: {#categoryId})
@TableIndex(name: 'txn_dedupe', columns: {#dedupeHash})
@TableIndex(name: 'txn_import_batch', columns: {#importBatchId})
@TableIndex(name: 'txn_payee', columns: {#payee})
class Transactions extends Table with SyncColumns {
  TextColumn get accountId => text()();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get valueDate => dateTime().nullable()();

  /// Signed: negative = money leaves the account.
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text().withDefault(const Constant('EUR'))();
  TextColumn get type => textEnum<TxnType>()();
  TextColumn get payee => text().nullable()();
  TextColumn get note => text().nullable()();

  /// null when the transaction is split (see [TransactionSplits]) or is a
  /// transfer.
  TextColumn get categoryId => text().nullable()();

  /// For transfers: id of the other leg.
  TextColumn get transferPeerId => text().nullable()();
  TextColumn get status =>
      textEnum<TxnStatus>().withDefault(Constant(TxnStatus.cleared.name))();
  TextColumn get recurringRuleId => text().nullable()();
  TextColumn get importBatchId => text().nullable()();
  TextColumn get importRowRef => text().nullable()();
  TextColumn get dedupeHash => text().nullable()();
}

@DataClassName('TxnSplit')
@TableIndex(name: 'split_txn', columns: {#transactionId})
class TransactionSplits extends Table with SyncColumns {
  TextColumn get transactionId => text()();
  TextColumn get categoryId => text().nullable()();
  IntColumn get amountMinor => integer()();
  TextColumn get note => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

@DataClassName('Tag')
class Tags extends Table with SyncColumns {
  TextColumn get name => text()();
  IntColumn get color => integer().nullable()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

@DataClassName('TxnTag')
@TableIndex(name: 'txn_tag_txn', columns: {#transactionId})
@TableIndex(name: 'txn_tag_tag', columns: {#tagId})
class TransactionTags extends Table with SyncColumns {
  TextColumn get transactionId => text()();
  TextColumn get tagId => text()();
}

@DataClassName('CustomFieldDef')
class CustomFieldDefs extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get type => textEnum<CustomFieldType>()();

  /// JSON list of option strings for select/multiselect.
  TextColumn get options => text().withDefault(const Constant('[]'))();

  /// Entity the field applies to: 'transaction' or 'account'.
  TextColumn get appliesTo =>
      text().withDefault(const Constant('transaction'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

@DataClassName('CustomFieldValue')
@TableIndex(name: 'cfv_entity', columns: {#entityId})
class CustomFieldValues extends Table with SyncColumns {
  TextColumn get fieldId => text()();
  TextColumn get entityId => text()();

  /// JSON-encoded value (string, number, ISO date, list, bool).
  TextColumn get value => text()();
}

@DataClassName('Attachment')
@TableIndex(name: 'attachment_txn', columns: {#transactionId})
class Attachments extends Table with SyncColumns {
  TextColumn get transactionId => text()();
  TextColumn get fileName => text()();
  TextColumn get filePath => text().nullable()();
  BlobColumn get data => blob().nullable()();
  TextColumn get mimeType => text()();
  IntColumn get sizeBytes => integer().withDefault(const Constant(0))();
}

@DataClassName('Rule')
class Rules extends Table with SyncColumns {
  TextColumn get name => text()();
  IntColumn get priority => integer().withDefault(const Constant(0))();

  /// JSON, see features/rules/domain.
  TextColumn get conditions => text()();
  TextColumn get actions => text()();
  BoolColumn get applyOnEntry => boolean().withDefault(const Constant(true))();
  BoolColumn get applyOnImport => boolean().withDefault(const Constant(true))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
}

@DataClassName('TxnTemplate')
class TransactionTemplates extends Table with SyncColumns {
  TextColumn get name => text()();

  /// JSON of the template transaction (see features/transactions/domain).
  TextColumn get fields => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

@DataClassName('RecurringRule')
class RecurringRules extends Table with SyncColumns {
  TextColumn get name => text()();

  /// RFC 5545 RRULE without the `RRULE:` prefix, e.g. `FREQ=MONTHLY;BYMONTHDAY=1`.
  TextColumn get rrule => text()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  IntColumn get count => integer().nullable()();

  /// JSON template transaction (account, amount, category, splits, tags...).
  TextColumn get template => text()();
  TextColumn get postingMode => textEnum<PostingMode>()();
  IntColumn get remindDaysBefore => integer().withDefault(const Constant(2))();

  /// Minutes after midnight.
  IntColumn get notifyTime => integer().withDefault(const Constant(540))();
  DateTimeColumn get lastPostedDate => dateTime().nullable()();

  /// 'none' | 'previous' | 'next' business-day shift.
  TextColumn get weekendShift => text().withDefault(const Constant('none'))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
}

@DataClassName('RecurringAmountChange')
class RecurringAmountChanges extends Table with SyncColumns {
  TextColumn get ruleId => text()();
  DateTimeColumn get fromDate => dateTime()();
  IntColumn get amountMinor => integer()();
}

@DataClassName('Budget')
@TableIndex(name: 'budget_period', columns: {#periodStart})
class Budgets extends Table with SyncColumns {
  TextColumn get categoryId => text()();
  DateTimeColumn get periodStart => dateTime()();
  IntColumn get amountMinor => integer()();

  /// Rollover amount carried into this period (computed when the period is
  /// filled; may be adjusted by the user).
  IntColumn get rolloverMinor => integer().withDefault(const Constant(0))();
}

@DataClassName('BudgetTemplate')
class BudgetTemplates extends Table with SyncColumns {
  TextColumn get name => text()();

  /// JSON list of {categoryId, amountMinor}.
  TextColumn get items => text()();
}

@DataClassName('Goal')
class Goals extends Table with SyncColumns {
  TextColumn get name => text()();
  IntColumn get targetMinor => integer()();
  DateTimeColumn get targetDate => dateTime().nullable()();
  TextColumn get accountId => text().nullable()();

  /// Amount already saved when not linked to an account.
  IntColumn get savedMinor => integer().withDefault(const Constant(0))();
  IntColumn get contributionMinor => integer().nullable()();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  IntColumn get color => integer().nullable()();
  TextColumn get icon => text().nullable()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

@DataClassName('Scenario')
class Scenarios extends Table with SyncColumns {
  TextColumn get name => text()();
  IntColumn get color => integer().nullable()();

  /// JSON list of adjustments, see features/scenarios/domain.
  TextColumn get adjustments => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(false))();
}

@DataClassName('SavedFilter')
class SavedFilters extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get filter => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

@DataClassName('DashboardLayout')
class DashboardLayouts extends Table with SyncColumns {
  /// 'compact' | 'medium' | 'expanded'.
  TextColumn get breakpoint => text()();
  TextColumn get widgets => text()();
}

@DataClassName('ImportProfile')
class ImportProfiles extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get config => text()();
}

@DataClassName('ImportBatch')
class ImportBatches extends Table with SyncColumns {
  TextColumn get fileName => text()();
  TextColumn get fileHash => text()();
  TextColumn get profileId => text().nullable()();
  DateTimeColumn get importedAt => dateTime()();
  IntColumn get rowCount => integer()();
  DateTimeColumn get undoneAt => dateTime().nullable()();

  /// JSON summary (counts, warnings).
  TextColumn get summary => text().withDefault(const Constant('{}'))();
}

/// Key/value settings. `id` is `<scope>|<key>`.
@DataClassName('SettingRow')
class Settings extends Table with SyncColumns {
  TextColumn get key => text()();

  /// JSON-encoded value.
  TextColumn get value => text()();

  /// `global`, `account:<id>` or `category:<id>`.
  TextColumn get scope => text().withDefault(const Constant('global'))();
}

enum ChangeOp { insert, update, delete }

/// Append-only log of every local write, consumed by a future sync backend.
@DataClassName('ChangeLogEntry')
@TableIndex(name: 'change_log_entity', columns: {#entity, #entityId})
class ChangeLog extends Table {
  IntColumn get seq => integer().autoIncrement()();
  TextColumn get entity => text()();
  TextColumn get entityId => text()();
  TextColumn get op => textEnum<ChangeOp>()();
  TextColumn get hlc => text()();

  /// JSON object of changed column -> new value (SQL names).
  TextColumn get changedFields => text()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
}

/// Unused in v1.
@DataClassName('SyncStateRow')
class SyncState extends Table {
  TextColumn get backendId => text()();
  TextColumn get lastPulledHlc => text().nullable()();
  IntColumn get lastPushedSeq => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {backendId};
}
