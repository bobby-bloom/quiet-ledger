import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:personal_finance/core/db/tables.dart';
import 'package:personal_finance/features/import/domain/date_parser.dart';
import 'package:personal_finance/features/import/domain/number_parser.dart';
import 'package:personal_finance/features/import/domain/source_reader.dart';
import 'package:personal_finance/features/import/domain/text_normalize.dart';

// Every choice of the import wizard. Stored as `import_profiles.config`
// (see [ImportConfig.toJson]) for one-click re-import.

/// What a sheet column is imported as.
enum ColumnTarget {
  ignore,
  date,
  valueDate,

  /// Signed amount, or the absolute amount with [amountType].
  amount,

  /// Money out (Soll / Ausgabe / debit).
  debit,

  /// Money in (Haben / Einnahme / credit).
  credit,

  /// Sign indicator next to [amount] (S/H, +/-, Einnahme/Ausgabe, ...).
  amountType,
  payee,
  note,
  category,
  subcategory,
  account,
  tags,
  status,
  customField,

  /// Running balance, used to verify the import and derive the opening
  /// balance.
  balance;

  /// Targets that at most one column may have.
  bool get isUnique => this != ignore && this != note && this != customField;
}

/// How amounts are written.
enum AmountMode { signed, debitCredit, amountWithType }

/// Where a sheet's account comes from.
enum AccountSource { fixed, column, sheetName }

/// What a duplicate row defaults to.
enum DuplicatePolicy { skip, import }

T _enum<T extends Enum>(List<T> values, Object? name, T fallback) =>
    values.firstWhereOrNull((v) => v.name == name) ?? fallback;

List<String> _strings(Object? v) => [
  for (final x in (v as List? ?? const [])) '$x',
];

/// Normalised key of a sheet value (account name, category path) used to
/// group equal values and to look them up in profile maps.
String valueKey(String s) => normaliseText(s);

/// Key of a category path (`['Food', 'Groceries']` → `food>groceries`).
String categoryKey(List<String> path) => path.map(valueKey).join('>');

@immutable
class ColumnConfig {
  const ColumnConfig({
    required this.index,
    required this.target,
    this.customFieldId,
    this.dateFormat = DateFormatKind.auto,
    this.numberFormat = NumberFormatKind.auto,
  });

  factory ColumnConfig.fromJson(Map<String, Object?> j) => ColumnConfig(
    index: (j['index'] as num?)?.toInt() ?? 0,
    target: _enum(ColumnTarget.values, j['target'], ColumnTarget.ignore),
    customFieldId: j['customFieldId'] as String?,
    dateFormat: _enum(
      DateFormatKind.values,
      j['dateFormat'],
      DateFormatKind.auto,
    ),
    numberFormat: _enum(
      NumberFormatKind.values,
      j['numberFormat'],
      NumberFormatKind.auto,
    ),
  );

  /// 0-based column index.
  final int index;
  final ColumnTarget target;

  /// For [ColumnTarget.customField].
  final String? customFieldId;

  /// Override for date columns (auto = detect).
  final DateFormatKind dateFormat;

  /// Override for amount/balance columns (auto = detect).
  final NumberFormatKind numberFormat;

  bool get isDate =>
      target == ColumnTarget.date || target == ColumnTarget.valueDate;

  bool get isNumber =>
      target == ColumnTarget.amount ||
      target == ColumnTarget.debit ||
      target == ColumnTarget.credit ||
      target == ColumnTarget.balance;

  ColumnConfig copyWith({
    ColumnTarget? target,
    Object? customFieldId = _unset,
    DateFormatKind? dateFormat,
    NumberFormatKind? numberFormat,
  }) => ColumnConfig(
    index: index,
    target: target ?? this.target,
    customFieldId: customFieldId == _unset
        ? this.customFieldId
        : customFieldId as String?,
    dateFormat: dateFormat ?? this.dateFormat,
    numberFormat: numberFormat ?? this.numberFormat,
  );

  Map<String, Object?> toJson() => {
    'index': index,
    'target': target.name,
    'customFieldId': ?customFieldId,
    if (dateFormat != DateFormatKind.auto) 'dateFormat': dateFormat.name,
    if (numberFormat != NumberFormatKind.auto)
      'numberFormat': numberFormat.name,
  };

  @override
  bool operator ==(Object other) =>
      other is ColumnConfig &&
      other.index == index &&
      other.target == target &&
      other.customFieldId == customFieldId &&
      other.dateFormat == dateFormat &&
      other.numberFormat == numberFormat;

  @override
  int get hashCode =>
      Object.hash(index, target, customFieldId, dateFormat, numberFormat);
}

/// Words of a type column that mean money out / money in. Compared after
/// [valueKey] normalisation.
@immutable
class TypeTokens {
  const TypeTokens({
    this.negative = defaultNegative,
    this.positive = defaultPositive,
  });

  factory TypeTokens.fromJson(Map<String, Object?> j) => TypeTokens(
    negative: j['negative'] == null ? defaultNegative : _strings(j['negative']),
    positive: j['positive'] == null ? defaultPositive : _strings(j['positive']),
  );

  static const defaultNegative = [
    's',
    'soll',
    'a',
    'ausgabe',
    'ausgaben',
    'aus',
    'lastschrift',
    'belastung',
    '-',
    'minus',
    'debit',
    'd',
    'dr',
    'db',
    'out',
    'expense',
    'withdrawal',
    'payment',
  ];

  static const defaultPositive = [
    'h',
    'haben',
    'e',
    'einnahme',
    'einnahmen',
    'ein',
    'gutschrift',
    '+',
    'plus',
    'credit',
    'c',
    'cr',
    'in',
    'income',
    'deposit',
  ];

  final List<String> negative;
  final List<String> positive;

  /// -1 for money out, 1 for money in, null when [raw] is not a known token.
  int? signOf(String raw) {
    final t = raw.trim();
    if (t == '-' || t == '−') return -1;
    if (t == '+') return 1;
    final k = valueKey(t);
    if (k.isEmpty) return null;
    if (negative.any((n) => valueKey(n) == k || n == t)) return -1;
    if (positive.any((p) => valueKey(p) == k || p == t)) return 1;
    return null;
  }

  Map<String, Object?> toJson() => {'negative': negative, 'positive': positive};
}

/// Per-sheet choices.
@immutable
class SheetConfig {
  const SheetConfig({
    required this.fileName,
    required this.sheetName,
    this.include = true,
    this.headerRow = 0,
    this.headerRows = 1,
    this.firstDataRow = 1,
    this.lastDataRow,
    this.columns = const [],
    this.amountMode = AmountMode.signed,
    this.invertSign = false,
    this.typeTokens = const TypeTokens(),
    this.accountSource = AccountSource.fixed,
    this.fixedAccount = '',
    this.year,
    this.categorySeparator = '',
    this.tagSeparator = ',',
    this.headerSignature = const [],
  });

  factory SheetConfig.fromJson(Map<String, Object?> j) => SheetConfig(
    fileName: j['fileName'] as String? ?? '',
    sheetName: j['sheetName'] as String? ?? '',
    include: j['include'] as bool? ?? true,
    headerRow: (j['headerRow'] as num?)?.toInt() ?? 0,
    headerRows: (j['headerRows'] as num?)?.toInt() ?? 1,
    firstDataRow: (j['firstDataRow'] as num?)?.toInt() ?? 1,
    lastDataRow: (j['lastDataRow'] as num?)?.toInt(),
    columns: [
      for (final c in (j['columns'] as List? ?? const []))
        if (c is Map) ColumnConfig.fromJson(c.cast()),
    ],
    amountMode: _enum(AmountMode.values, j['amountMode'], AmountMode.signed),
    invertSign: j['invertSign'] as bool? ?? false,
    typeTokens: j['typeTokens'] is Map
        ? TypeTokens.fromJson((j['typeTokens']! as Map).cast())
        : const TypeTokens(),
    accountSource: _enum(
      AccountSource.values,
      j['accountSource'],
      AccountSource.fixed,
    ),
    fixedAccount: j['fixedAccount'] as String? ?? '',
    year: (j['year'] as num?)?.toInt(),
    categorySeparator: j['categorySeparator'] as String? ?? '',
    tagSeparator: j['tagSeparator'] as String? ?? ',',
    headerSignature: _strings(j['headerSignature']),
  );

  final String fileName;
  final String sheetName;
  final bool include;

  /// 0-based row of the (first) header row; -1 = no header.
  final int headerRow;

  /// Number of header rows (multi-row headers are joined per column).
  final int headerRows;

  /// 0-based first row that may hold data.
  final int firstDataRow;

  /// 0-based last row that may hold data (inclusive); null = to the end.
  final int? lastDataRow;

  /// Mapped columns (columns not listed are ignored).
  final List<ColumnConfig> columns;
  final AmountMode amountMode;

  /// Negate every amount (sheets that write expenses as positive numbers).
  final bool invertSign;
  final TypeTokens typeTokens;
  final AccountSource accountSource;

  /// Account name for [AccountSource.fixed] (key into
  /// [ImportConfig.accounts]); also the fallback for empty account cells.
  final String fixedAccount;

  /// Year for dates without a year (`05.01.`), usually from the sheet name.
  final int? year;

  /// Separator of "Parent > Child" in a single category column; empty =
  /// no hierarchy in the column.
  final String categorySeparator;
  final String tagSeparator;

  /// Normalised header labels, used to reuse this config for sheets with
  /// the same columns (e.g. a new year's sheet).
  final List<String> headerSignature;

  String get key => sheetKey(fileName, sheetName);

  ColumnConfig? column(int index) =>
      columns.firstWhereOrNull((c) => c.index == index);

  ColumnTarget targetOf(int index) =>
      column(index)?.target ?? ColumnTarget.ignore;

  /// First column with [target].
  ColumnConfig? columnFor(ColumnTarget target) =>
      columns.firstWhereOrNull((c) => c.target == target);

  List<ColumnConfig> columnsFor(ColumnTarget target) => [
    for (final c in columns)
      if (c.target == target) c,
  ];

  /// Sets column [index] to [target]. Unique targets are removed from other
  /// columns.
  SheetConfig withTarget(int index, ColumnTarget target, {String? fieldId}) {
    final existing = column(index);
    final next = <ColumnConfig>[
      for (final c in columns)
        if (c.index != index &&
            !(target.isUnique && c.target == target) &&
            !(target == ColumnTarget.customField &&
                c.target == ColumnTarget.customField &&
                c.customFieldId == fieldId))
          c,
      if (target != ColumnTarget.ignore)
        (existing ?? ColumnConfig(index: index, target: target)).copyWith(
          target: target,
          customFieldId: target == ColumnTarget.customField ? fieldId : null,
        ),
    ]..sort((a, b) => a.index.compareTo(b.index));
    var mode = amountMode;
    if (target == ColumnTarget.debit || target == ColumnTarget.credit) {
      mode = AmountMode.debitCredit;
    } else if (target == ColumnTarget.amountType) {
      mode = AmountMode.amountWithType;
    }
    return copyWith(columns: next, amountMode: mode);
  }

  SheetConfig withColumn(ColumnConfig column) => copyWith(
    columns: [
      for (final c in columns)
        if (c.index == column.index) column else c,
    ],
  );

  SheetConfig copyWith({
    String? fileName,
    String? sheetName,
    bool? include,
    int? headerRow,
    int? headerRows,
    int? firstDataRow,
    Object? lastDataRow = _unset,
    List<ColumnConfig>? columns,
    AmountMode? amountMode,
    bool? invertSign,
    TypeTokens? typeTokens,
    AccountSource? accountSource,
    String? fixedAccount,
    Object? year = _unset,
    String? categorySeparator,
    String? tagSeparator,
    List<String>? headerSignature,
  }) => SheetConfig(
    fileName: fileName ?? this.fileName,
    sheetName: sheetName ?? this.sheetName,
    include: include ?? this.include,
    headerRow: headerRow ?? this.headerRow,
    headerRows: headerRows ?? this.headerRows,
    firstDataRow: firstDataRow ?? this.firstDataRow,
    lastDataRow: lastDataRow == _unset ? this.lastDataRow : lastDataRow as int?,
    columns: columns ?? this.columns,
    amountMode: amountMode ?? this.amountMode,
    invertSign: invertSign ?? this.invertSign,
    typeTokens: typeTokens ?? this.typeTokens,
    accountSource: accountSource ?? this.accountSource,
    fixedAccount: fixedAccount ?? this.fixedAccount,
    year: year == _unset ? this.year : year as int?,
    categorySeparator: categorySeparator ?? this.categorySeparator,
    tagSeparator: tagSeparator ?? this.tagSeparator,
    headerSignature: headerSignature ?? this.headerSignature,
  );

  Map<String, Object?> toJson() => {
    'fileName': fileName,
    'sheetName': sheetName,
    'include': include,
    'headerRow': headerRow,
    'headerRows': headerRows,
    'firstDataRow': firstDataRow,
    'lastDataRow': ?lastDataRow,
    'columns': [for (final c in columns) c.toJson()],
    'amountMode': amountMode.name,
    if (invertSign) 'invertSign': true,
    'typeTokens': typeTokens.toJson(),
    'accountSource': accountSource.name,
    'fixedAccount': fixedAccount,
    'year': ?year,
    'categorySeparator': categorySeparator,
    'tagSeparator': tagSeparator,
    'headerSignature': headerSignature,
  };
}

String sheetKey(String fileName, String sheetName) =>
    '$fileName\u0000$sheetName';

/// Row filters (PLAN.md §2.5 step 3).
@immutable
class RowFilterConfig {
  const RowFilterConfig({
    this.skipPatterns = defaultSkipPatterns,
    this.skipWithoutDate = true,
    this.skipZeroAmount = true,
  });

  factory RowFilterConfig.fromJson(Map<String, Object?> j) => RowFilterConfig(
    skipPatterns: j['skipPatterns'] == null
        ? defaultSkipPatterns
        : _strings(j['skipPatterns']),
    skipWithoutDate: j['skipWithoutDate'] as bool? ?? true,
    skipZeroAmount: j['skipZeroAmount'] as bool? ?? true,
  );

  /// Text at the start of a cell that marks a subtotal / sum row. A pattern
  /// wrapped in slashes (`/^Summe \w+$/`) is a regular expression.
  static const defaultSkipPatterns = [
    'Summe',
    'Zwischensumme',
    'Gesamt',
    'Gesamtsumme',
    'Saldo',
    'Übertrag',
    'Endsaldo',
    'Anfangssaldo',
    'Kontostand',
    'Total',
    'Subtotal',
    'Sum',
    'Opening balance',
    'Closing balance',
    'Balance brought forward',
    'Carried forward',
  ];

  final List<String> skipPatterns;

  /// Rows without a date are skipped (otherwise reported as invalid).
  final bool skipWithoutDate;

  /// Rows whose amount is empty or zero are skipped.
  final bool skipZeroAmount;

  RowFilterConfig copyWith({
    List<String>? skipPatterns,
    bool? skipWithoutDate,
    bool? skipZeroAmount,
  }) => RowFilterConfig(
    skipPatterns: skipPatterns ?? this.skipPatterns,
    skipWithoutDate: skipWithoutDate ?? this.skipWithoutDate,
    skipZeroAmount: skipZeroAmount ?? this.skipZeroAmount,
  );

  Map<String, Object?> toJson() => {
    'skipPatterns': skipPatterns,
    'skipWithoutDate': skipWithoutDate,
    'skipZeroAmount': skipZeroAmount,
  };
}

/// Where a sheet account value goes: an existing account or a new one.
@immutable
class AccountTarget {
  const AccountTarget.existing(String this.existingId)
    : name = '',
      type = AccountType.checking;

  const AccountTarget.create(this.name, {this.type = AccountType.checking})
    : existingId = null;

  factory AccountTarget.fromJson(Map<String, Object?> j) {
    final id = j['existingId'] as String?;
    if (id != null) return AccountTarget.existing(id);
    return AccountTarget.create(
      j['name'] as String? ?? '',
      type: _enum(AccountType.values, j['type'], AccountType.checking),
    );
  }

  final String? existingId;
  final String name;
  final AccountType type;

  bool get isNew => existingId == null;

  Map<String, Object?> toJson() => existingId != null
      ? {'existingId': existingId}
      : {'name': name, 'type': type.name};

  @override
  bool operator ==(Object other) =>
      other is AccountTarget &&
      other.existingId == existingId &&
      other.name == name &&
      other.type == type;

  @override
  int get hashCode => Object.hash(existingId, name, type);
}

enum CategoryTargetMode {
  /// An existing category.
  existing,

  /// Create the category (and its parent) with the sheet's name.
  create,

  /// Import without a category (rules may still categorise).
  none,

  /// Rows become transfers to [CategoryTarget.transferAccount].
  transfer,
}

/// Where a category value goes.
@immutable
class CategoryTarget {
  const CategoryTarget._(
    this.mode, {
    this.existingId,
    this.path = const [],
    this.kind = CategoryKind.expense,
    this.transferAccount,
  });

  const CategoryTarget.existing(String id)
    : this._(CategoryTargetMode.existing, existingId: id);

  const CategoryTarget.create(
    List<String> path, {
    CategoryKind kind = CategoryKind.expense,
  }) : this._(CategoryTargetMode.create, path: path, kind: kind);

  const CategoryTarget.none() : this._(CategoryTargetMode.none);

  /// [accountKey] is a key of [ImportConfig.accounts] or an existing
  /// account id prefixed with `id:`.
  const CategoryTarget.transfer(String accountKey)
    : this._(CategoryTargetMode.transfer, transferAccount: accountKey);

  factory CategoryTarget.fromJson(Map<String, Object?> j) {
    final mode = _enum(
      CategoryTargetMode.values,
      j['mode'],
      CategoryTargetMode.none,
    );
    return switch (mode) {
      CategoryTargetMode.existing => CategoryTarget.existing(
        j['existingId'] as String? ?? '',
      ),
      CategoryTargetMode.create => CategoryTarget.create(
        _strings(j['path']),
        kind: _enum(CategoryKind.values, j['kind'], CategoryKind.expense),
      ),
      CategoryTargetMode.none => const CategoryTarget.none(),
      CategoryTargetMode.transfer => CategoryTarget.transfer(
        j['transferAccount'] as String? ?? '',
      ),
    };
  }

  final CategoryTargetMode mode;
  final String? existingId;
  final List<String> path;
  final CategoryKind kind;
  final String? transferAccount;

  Map<String, Object?> toJson() => {
    'mode': mode.name,
    'existingId': ?existingId,
    if (mode == CategoryTargetMode.create) 'path': path,
    if (mode == CategoryTargetMode.create) 'kind': kind.name,
    'transferAccount': ?transferAccount,
  };

  @override
  bool operator ==(Object other) =>
      other is CategoryTarget &&
      other.mode == mode &&
      other.existingId == existingId &&
      const ListEquality<String>().equals(other.path, path) &&
      other.kind == kind &&
      other.transferAccount == transferAccount;

  @override
  int get hashCode => Object.hash(
    mode,
    existingId,
    Object.hashAll(path),
    kind,
    transferAccount,
  );
}

@immutable
class TransferConfig {
  const TransferConfig({this.detect = true, this.windowDays = 3});

  factory TransferConfig.fromJson(Map<String, Object?> j) => TransferConfig(
    detect: j['detect'] as bool? ?? true,
    windowDays: (j['windowDays'] as num?)?.toInt() ?? 3,
  );

  final bool detect;

  /// Maximum date difference between the two legs.
  final int windowDays;

  TransferConfig copyWith({bool? detect, int? windowDays}) => TransferConfig(
    detect: detect ?? this.detect,
    windowDays: windowDays ?? this.windowDays,
  );

  Map<String, Object?> toJson() => {'detect': detect, 'windowDays': windowDays};
}

/// All wizard choices.
@immutable
class ImportConfig {
  const ImportConfig({
    this.sheets = const [],
    this.filters = const RowFilterConfig(),
    this.accounts = const {},
    this.categories = const {},
    this.transfers = const TransferConfig(),
    this.duplicates = DuplicatePolicy.skip,
    this.incremental = true,
    this.applyRules = true,
    this.setOpeningBalances = true,
    this.csvOptions = const {},
  });

  factory ImportConfig.fromJson(Map<String, Object?> j) => ImportConfig(
    sheets: [
      for (final s in (j['sheets'] as List? ?? const []))
        if (s is Map) SheetConfig.fromJson(s.cast()),
    ],
    filters: j['filters'] is Map
        ? RowFilterConfig.fromJson((j['filters']! as Map).cast())
        : const RowFilterConfig(),
    accounts: {
      for (final e in ((j['accounts'] as Map?) ?? const {}).entries)
        if (e.value is Map)
          '${e.key}': AccountTarget.fromJson((e.value as Map).cast()),
    },
    categories: {
      for (final e in ((j['categories'] as Map?) ?? const {}).entries)
        if (e.value is Map)
          '${e.key}': CategoryTarget.fromJson((e.value as Map).cast()),
    },
    transfers: j['transfers'] is Map
        ? TransferConfig.fromJson((j['transfers']! as Map).cast())
        : const TransferConfig(),
    duplicates: _enum(
      DuplicatePolicy.values,
      j['duplicates'],
      DuplicatePolicy.skip,
    ),
    incremental: j['incremental'] as bool? ?? true,
    applyRules: j['applyRules'] as bool? ?? true,
    setOpeningBalances: j['setOpeningBalances'] as bool? ?? true,
    csvOptions: {
      for (final e in ((j['csvOptions'] as Map?) ?? const {}).entries)
        if (e.value is Map)
          '${e.key}': CsvReadOptions.fromJson((e.value as Map).cast()),
    },
  );

  factory ImportConfig.decode(String json) {
    final v = jsonDecode(json);
    if (v is! Map) {
      throw const FormatException('Import config is not an object');
    }
    return ImportConfig.fromJson(v.cast());
  }

  final List<SheetConfig> sheets;
  final RowFilterConfig filters;

  /// [valueKey] of a sheet account value → target.
  final Map<String, AccountTarget> accounts;

  /// [categoryKey] of a sheet category path → target.
  final Map<String, CategoryTarget> categories;
  final TransferConfig transfers;
  final DuplicatePolicy duplicates;

  /// Skip rows already imported by an earlier batch of the same profile or
  /// file.
  final bool incremental;
  final bool applyRules;

  /// Set new accounts' opening balance from the running-balance column.
  final bool setOpeningBalances;

  /// CSV read overrides per file name.
  final Map<String, CsvReadOptions> csvOptions;

  SheetConfig? sheet(String key) =>
      sheets.firstWhereOrNull((s) => s.key == key);

  List<SheetConfig> get includedSheets => [
    for (final s in sheets)
      if (s.include) s,
  ];

  ImportConfig withSheet(SheetConfig sheet) => copyWith(
    sheets: [
      for (final s in sheets)
        if (s.key == sheet.key) sheet else s,
    ],
  );

  ImportConfig copyWith({
    List<SheetConfig>? sheets,
    RowFilterConfig? filters,
    Map<String, AccountTarget>? accounts,
    Map<String, CategoryTarget>? categories,
    TransferConfig? transfers,
    DuplicatePolicy? duplicates,
    bool? incremental,
    bool? applyRules,
    bool? setOpeningBalances,
    Map<String, CsvReadOptions>? csvOptions,
  }) => ImportConfig(
    sheets: sheets ?? this.sheets,
    filters: filters ?? this.filters,
    accounts: accounts ?? this.accounts,
    categories: categories ?? this.categories,
    transfers: transfers ?? this.transfers,
    duplicates: duplicates ?? this.duplicates,
    incremental: incremental ?? this.incremental,
    applyRules: applyRules ?? this.applyRules,
    setOpeningBalances: setOpeningBalances ?? this.setOpeningBalances,
    csvOptions: csvOptions ?? this.csvOptions,
  );

  Map<String, Object?> toJson() => {
    'version': 1,
    'sheets': [for (final s in sheets) s.toJson()],
    'filters': filters.toJson(),
    'accounts': {for (final e in accounts.entries) e.key: e.value.toJson()},
    'categories': {for (final e in categories.entries) e.key: e.value.toJson()},
    'transfers': transfers.toJson(),
    'duplicates': duplicates.name,
    'incremental': incremental,
    'applyRules': applyRules,
    'setOpeningBalances': setOpeningBalances,
    'csvOptions': {for (final e in csvOptions.entries) e.key: e.value.toJson()},
  };

  String encode() => jsonEncode(toJson());
}

const _unset = Object();
