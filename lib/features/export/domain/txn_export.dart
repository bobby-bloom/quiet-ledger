import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:personal_finance/core/csv/csv_writer.dart';
import 'package:personal_finance/core/db/tables.dart';

// Transaction CSV layout (PLAN.md §2.6).
//
// One CSV row per transaction leg. Transfers export both legs (one per
// account, with the counter-account in "Transfer account"), so the amounts
// of a flat export sum to the net change of all accounts.
//
// Split transactions are written as **one row per split line**: the row
// carries the split's amount, category and note (falling back to the
// transaction note) and the "Split" column holds a marker `i/n`. All other
// columns repeat the parent's values and the "ID" column is the parent's
// id, so the rows can be grouped back together. This keeps sums and
// category pivots in a spreadsheet correct (no parent row to double-count).

/// Stable column keys (stored in presets). Custom fields use
/// `cf:<fieldId>` (see [customFieldKey]).
abstract final class TxnColumnKeys {
  static const date = 'date';
  static const valueDate = 'valueDate';
  static const account = 'account';
  static const type = 'type';
  static const amount = 'amount';
  static const currency = 'currency';
  static const payee = 'payee';
  static const note = 'note';
  static const category = 'category';
  static const split = 'split';
  static const tags = 'tags';
  static const status = 'status';
  static const transferAccount = 'transferAccount';
  static const id = 'id';

  /// Default order; custom fields are inserted before [id].
  static const fixed = [
    date,
    valueDate,
    account,
    type,
    amount,
    currency,
    payee,
    note,
    category,
    split,
    tags,
    status,
    transferAccount,
  ];
}

String customFieldKey(String fieldId) => 'cf:$fieldId';

/// One exported CSV row.
@immutable
class TxnExportRow {
  const TxnExportRow({
    required this.id,
    required this.date,
    required this.accountId,
    required this.accountName,
    required this.type,
    required this.amountMinor,
    required this.currency,
    required this.status,
    this.valueDate,
    this.payee,
    this.note,
    this.categoryPath,
    this.split,
    this.tags = const [],
    this.transferAccountName,
    this.customFields = const {},
  });

  final String id;
  final DateTime date;
  final DateTime? valueDate;
  final String accountId;
  final String accountName;
  final TxnType type;

  /// Signed minor units (the split line's amount for split rows).
  final int amountMinor;
  final String currency;
  final String? payee;
  final String? note;

  /// `Parent > Child`.
  final String? categoryPath;

  /// Split marker `i/n`, null when not split.
  final String? split;
  final List<String> tags;
  final TxnStatus status;
  final String? transferAccountName;

  /// fieldId → JSON-decoded value.
  final Map<String, Object?> customFields;
}

/// Localized texts for the transaction CSV.
@immutable
class TxnExportLabels {
  const TxnExportLabels({
    required this.headers,
    required this.types,
    required this.statuses,
  });

  /// Raw keys and enum names (tests, machine-readable exports).
  factory TxnExportLabels.raw() => TxnExportLabels(
    headers: {
      for (final k in [...TxnColumnKeys.fixed, 'id']) k: k,
    },
    types: {for (final t in TxnType.values) t: t.name},
    statuses: {for (final s in TxnStatus.values) s: s.name},
  );

  /// Column key → header text.
  final Map<String, String> headers;
  final Map<TxnType, String> types;
  final Map<TxnStatus, String> statuses;

  String header(String key) => headers[key] ?? key;
}

/// Custom field info needed for formatting values.
@immutable
class TxnExportField {
  const TxnExportField(this.id, this.name, this.type);
  final String id;
  final String name;
  final CustomFieldType type;
}

/// All columns in default order (fixed columns, custom fields, id).
List<CsvColumn<TxnExportRow>> txnExportColumns(
  TxnExportLabels labels, {
  List<TxnExportField> customFields = const [],
}) {
  CsvColumn<TxnExportRow> col(
    String key,
    Object? Function(TxnExportRow r) value,
  ) => CsvColumn(key, labels.header(key), value);
  return [
    col(TxnColumnKeys.date, (r) => r.date),
    col(TxnColumnKeys.valueDate, (r) => r.valueDate),
    col(TxnColumnKeys.account, (r) => r.accountName),
    col(TxnColumnKeys.type, (r) => labels.types[r.type] ?? r.type.name),
    col(TxnColumnKeys.amount, (r) => CsvAmount(r.amountMinor)),
    col(TxnColumnKeys.currency, (r) => r.currency),
    col(TxnColumnKeys.payee, (r) => r.payee),
    col(TxnColumnKeys.note, (r) => r.note),
    col(TxnColumnKeys.category, (r) => r.categoryPath),
    col(TxnColumnKeys.split, (r) => r.split),
    col(TxnColumnKeys.tags, (r) => r.tags),
    col(
      TxnColumnKeys.status,
      (r) => labels.statuses[r.status] ?? r.status.name,
    ),
    col(TxnColumnKeys.transferAccount, (r) => r.transferAccountName),
    for (final f in customFields)
      CsvColumn(
        customFieldKey(f.id),
        f.name,
        (r) => customFieldCell(f.type, r.customFields[f.id]),
      ),
    col(TxnColumnKeys.id, (r) => r.id),
  ];
}

/// Converts a decoded custom field value to a CSV cell value.
Object? customFieldCell(CustomFieldType type, Object? value) {
  if (value == null) return null;
  switch (type) {
    case CustomFieldType.date:
      if (value is String) return DateTime.tryParse(value) ?? value;
      return value;
    case CustomFieldType.number:
      return value is num ? value : num.tryParse('$value') ?? value;
    case CustomFieldType.boolean:
      return value is bool ? value : value == 'true';
    case CustomFieldType.multiselect:
      return value is List ? value : [value];
    case CustomFieldType.text:
    case CustomFieldType.select:
      return value is String ? value : jsonEncode(value);
  }
}

/// `Parent > Child` path for a category.
String categoryPath(
  String? id,
  Map<String, ({String name, String? parentId})> categories,
) {
  if (id == null) return '';
  final names = <String>[];
  var current = categories[id];
  final seen = <String>{};
  var currentId = id;
  while (current != null && seen.add(currentId)) {
    names.insert(0, current.name);
    final p = current.parentId;
    if (p == null) break;
    currentId = p;
    current = categories[p];
  }
  return names.join(' > ');
}

/// A file name safe on every platform (keeps letters incl. umlauts, digits,
/// space, `-`, `_` and `.`).
String safeFileName(String name, {String fallback = 'file'}) {
  final cleaned = name
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
  final noDots = cleaned.replaceAll(RegExp(r'^\.+'), '');
  return noDots.isEmpty ? fallback : noDots;
}
