import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:personal_finance/core/db/tables.dart';

/// Relative date ranges. Stored by name so a saved filter like "This month"
/// keeps moving with the calendar.
enum DatePreset {
  thisMonth,
  lastMonth,
  last30Days,
  last90Days,
  thisYear,
  lastYear,

  /// Uses [TxnFilter.dateFrom] / [TxnFilter.dateTo].
  custom,
}

/// How a custom-field condition matches the stored JSON value.
enum CustomFieldOp {
  /// The field has any value.
  isSet,

  /// The JSON value equals [CustomFieldFilter.value] (select, number, date,
  /// boolean).
  equals,

  /// Case-insensitive substring of a text value.
  contains,

  /// A multi-select value includes the option [CustomFieldFilter.value].
  includes,

  /// Loose match of a textual value (deep links): equal as JSON string,
  /// equal as raw JSON (numbers, booleans) or included in a multi-select.
  matches,
}

@immutable
class CustomFieldFilter {
  const CustomFieldFilter({
    required this.fieldId,
    this.op = CustomFieldOp.isSet,
    this.value,
  });

  factory CustomFieldFilter.fromJson(Map<String, Object?> j) =>
      CustomFieldFilter(
        fieldId: j['fieldId']! as String,
        op:
            CustomFieldOp.values.firstWhereOrNull((o) => o.name == j['op']) ??
            CustomFieldOp.isSet,
        value: j['value'],
      );

  final String fieldId;
  final CustomFieldOp op;

  /// JSON-compatible value (String, num, bool).
  final Object? value;

  Map<String, Object?> toJson() => {
    'fieldId': fieldId,
    'op': op.name,
    if (value != null) 'value': value,
  };

  @override
  bool operator ==(Object other) =>
      other is CustomFieldFilter &&
      other.fieldId == fieldId &&
      other.op == op &&
      other.value == value;

  @override
  int get hashCode => Object.hash(fieldId, op, value);
}

/// Half-open date range `[start, end)` at local midnight.
typedef TxnDateSpan = ({DateTime start, DateTime end});

/// The transaction list's filter (search + facets). Immutable, comparable
/// and JSON-serialisable so it can be stored as a saved filter
/// (`saved_filters.filter`) and used as a provider family key.
///
/// All facets are AND-combined; values inside one facet are OR-combined
/// (e.g. account A or B). Amount bounds compare the absolute amount.
@immutable
class TxnFilter {
  const TxnFilter({
    this.search = '',
    this.payee,
    this.importBatchId,
    this.accountIds = const {},
    this.categoryIds = const {},
    this.uncategorized = false,
    this.tagIds = const {},
    this.types = const {},
    this.statuses = const {},
    this.minAmountMinor,
    this.maxAmountMinor,
    this.datePreset,
    this.dateFrom,
    this.dateTo,
    this.customFields = const [],
  });

  factory TxnFilter.fromJson(Map<String, Object?> j) {
    Set<String> ids(String key) => {
      for (final v in (j[key] as List? ?? const [])) v as String,
    };
    DateTime? date(String key) {
      final v = j[key];
      return v is String ? DateTime.tryParse(v) : null;
    }

    return TxnFilter(
      search: j['search'] as String? ?? '',
      payee: j['payee'] as String?,
      importBatchId: j['importBatch'] as String?,
      accountIds: ids('accounts'),
      categoryIds: ids('categories'),
      uncategorized: j['uncategorized'] == true,
      tagIds: ids('tags'),
      types: {
        for (final v in (j['types'] as List? ?? const []))
          ?TxnType.values.firstWhereOrNull((t) => t.name == v),
      },
      statuses: {
        for (final v in (j['statuses'] as List? ?? const []))
          ?TxnStatus.values.firstWhereOrNull((t) => t.name == v),
      },
      minAmountMinor: (j['minAmount'] as num?)?.toInt(),
      maxAmountMinor: (j['maxAmount'] as num?)?.toInt(),
      datePreset: DatePreset.values.firstWhereOrNull(
        (p) => p.name == j['datePreset'],
      ),
      dateFrom: date('dateFrom'),
      dateTo: date('dateTo'),
      customFields: [
        for (final c in (j['customFields'] as List? ?? const []))
          CustomFieldFilter.fromJson((c as Map).cast()),
      ],
    );
  }

  /// Builds a filter from deep-link query parameters of `/transactions`:
  ///
  /// * `account`, `category`, `tag`: ids, comma-separated for several;
  ///   `category=none` selects uncategorised transactions (no category
  ///   and no split line with a category)
  /// * `field` + `fieldValue`: custom field id and value
  ///   ([CustomFieldOp.matches]); `field` alone = the field has a value
  /// * `payee`: exact payee (case-insensitive)
  /// * `from`, `to`: dates `YYYY-MM-DD`, both inclusive (either may be
  ///   omitted)
  /// * `type`: `expense`, `income`, `transfer` (comma-separated)
  /// * `status`: `cleared`, `pending`, `planned` (comma-separated)
  /// * `q`: full-text search
  /// * `importBatch`: rows created by one import batch
  ///
  /// Unknown parameters and invalid values are ignored.
  factory TxnFilter.fromQuery(Map<String, String> q) {
    Set<String> ids(String key) => {
      for (final v in (q[key] ?? '').split(','))
        if (v.trim().isNotEmpty) v.trim(),
    };
    DateTime? day(String key) {
      final d = DateTime.tryParse(q[key]?.trim() ?? '');
      return d == null ? null : DateTime(d.year, d.month, d.day);
    }

    final from = day('from');
    final to = day('to');
    final payee = q['payee']?.trim();
    final categories = ids('category');
    final field = q['field']?.trim() ?? '';
    final fieldValue = q['fieldValue'];
    return TxnFilter(
      search: q['q']?.trim() ?? '',
      payee: payee == null || payee.isEmpty ? null : payee,
      importBatchId: (q['importBatch']?.trim().isEmpty ?? true)
          ? null
          : q['importBatch']!.trim(),
      accountIds: ids('account'),
      categoryIds: categories.difference(const {'none'}),
      uncategorized: categories.contains('none'),
      customFields: [
        if (field.isNotEmpty && (fieldValue == null || fieldValue.isEmpty))
          CustomFieldFilter(fieldId: field)
        else if (field.isNotEmpty)
          CustomFieldFilter(
            fieldId: field,
            op: CustomFieldOp.matches,
            value: fieldValue,
          ),
      ],
      tagIds: ids('tag'),
      types: {
        for (final v in ids('type'))
          ?TxnType.values.firstWhereOrNull((t) => t.name == v),
      },
      statuses: {
        for (final v in ids('status'))
          ?TxnStatus.values.firstWhereOrNull((t) => t.name == v),
      },
      datePreset: from != null || to != null ? DatePreset.custom : null,
      dateFrom: from,
      dateTo: to,
    );
  }

  /// Query parameters that [TxnFilter.fromQuery] turns back into this
  /// filter (facets without a parameter are dropped).
  Map<String, String> toQuery() {
    String day(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    String join(Iterable<String> v) => (v.toList()..sort()).join(',');
    final span = datePreset == DatePreset.custom;
    return {
      if (accountIds.isNotEmpty) 'account': join(accountIds),
      if (hasCategory)
        'category': join([...categoryIds, if (uncategorized) 'none']),
      if (customFields.length == 1 &&
          (customFields.single.op == CustomFieldOp.isSet ||
              customFields.single.op == CustomFieldOp.matches)) ...{
        'field': customFields.single.fieldId,
        if (customFields.single.op == CustomFieldOp.matches)
          'fieldValue': '${customFields.single.value}',
      },
      if (tagIds.isNotEmpty) 'tag': join(tagIds),
      if (hasPayee) 'payee': payee!.trim(),
      if (span && dateFrom != null) 'from': day(dateFrom!),
      if (span && dateTo != null) 'to': day(dateTo!),
      if (types.isNotEmpty) 'type': join(types.map((t) => t.name)),
      if (statuses.isNotEmpty) 'status': join(statuses.map((t) => t.name)),
      if (hasSearch) 'q': search.trim(),
      'importBatch': ?importBatchId,
    };
  }

  /// Full-text query over payee, note, category and tag names. Words are
  /// prefix-matched and AND-combined. A query that is a plain amount also
  /// matches transactions of exactly that amount.
  final String search;

  /// Exact payee (case-insensitive), e.g. from a "top payees" report.
  final String? payee;

  /// Only rows created by this import batch (import history link).
  final String? importBatchId;
  final Set<String> accountIds;

  /// Matches the transaction category and split lines; parents include
  /// their sub-categories.
  final Set<String> categoryIds;

  /// Also (OR) match transactions without category (no splits, no
  /// transfer).
  final bool uncategorized;
  final Set<String> tagIds;
  final Set<TxnType> types;
  final Set<TxnStatus> statuses;

  /// Inclusive bounds on the absolute amount in minor units.
  final int? minAmountMinor;
  final int? maxAmountMinor;
  final DatePreset? datePreset;

  /// Inclusive first/last day for [DatePreset.custom] (either may be null
  /// for an open range).
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final List<CustomFieldFilter> customFields;

  static const empty = TxnFilter();

  bool get hasSearch => search.trim().isNotEmpty;

  bool get hasDate =>
      datePreset != null &&
      (datePreset != DatePreset.custom || dateFrom != null || dateTo != null);

  bool get hasAmount => minAmountMinor != null || maxAmountMinor != null;

  bool get hasCategory => categoryIds.isNotEmpty || uncategorized;

  bool get hasPayee => payee != null && payee!.trim().isNotEmpty;

  /// Number of active facets (search excluded), for a "Filters (3)" badge.
  int get activeCount => [
    hasPayee,
    importBatchId != null,
    accountIds.isNotEmpty,
    hasCategory,
    tagIds.isNotEmpty,
    types.isNotEmpty,
    statuses.isNotEmpty,
    hasAmount,
    hasDate,
    customFields.isNotEmpty,
  ].where((x) => x).length;

  bool get isEmpty => !hasSearch && activeCount == 0;

  /// Exactly one account selected (running balance is meaningful).
  String? get singleAccountId =>
      accountIds.length == 1 ? accountIds.first : null;

  /// Resolves the date facet relative to [now]. Null = no date limit.
  TxnDateSpan? dateSpan(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    switch (datePreset) {
      case null:
        return null;
      case DatePreset.thisMonth:
        return (
          start: DateTime(now.year, now.month),
          end: DateTime(now.year, now.month + 1),
        );
      case DatePreset.lastMonth:
        return (
          start: DateTime(now.year, now.month - 1),
          end: DateTime(now.year, now.month),
        );
      case DatePreset.last30Days:
        return (
          start: DateTime(today.year, today.month, today.day - 29),
          end: DateTime(today.year, today.month, today.day + 1),
        );
      case DatePreset.last90Days:
        return (
          start: DateTime(today.year, today.month, today.day - 89),
          end: DateTime(today.year, today.month, today.day + 1),
        );
      case DatePreset.thisYear:
        return (start: DateTime(now.year), end: DateTime(now.year + 1));
      case DatePreset.lastYear:
        return (start: DateTime(now.year - 1), end: DateTime(now.year));
      case DatePreset.custom:
        if (dateFrom == null && dateTo == null) return null;
        final from = dateFrom ?? DateTime(1900);
        final to = dateTo ?? DateTime(9999);
        return (
          start: DateTime(from.year, from.month, from.day),
          end: DateTime(to.year, to.month, to.day + 1),
        );
    }
  }

  static const _unset = Object();

  TxnFilter copyWith({
    String? search,
    Object? payee = _unset,
    Object? importBatchId = _unset,
    Set<String>? accountIds,
    Set<String>? categoryIds,
    bool? uncategorized,
    Set<String>? tagIds,
    Set<TxnType>? types,
    Set<TxnStatus>? statuses,
    Object? minAmountMinor = _unset,
    Object? maxAmountMinor = _unset,
    Object? datePreset = _unset,
    Object? dateFrom = _unset,
    Object? dateTo = _unset,
    List<CustomFieldFilter>? customFields,
  }) => TxnFilter(
    search: search ?? this.search,
    payee: payee == _unset ? this.payee : payee as String?,
    importBatchId: importBatchId == _unset
        ? this.importBatchId
        : importBatchId as String?,
    accountIds: accountIds ?? this.accountIds,
    categoryIds: categoryIds ?? this.categoryIds,
    uncategorized: uncategorized ?? this.uncategorized,
    tagIds: tagIds ?? this.tagIds,
    types: types ?? this.types,
    statuses: statuses ?? this.statuses,
    minAmountMinor: minAmountMinor == _unset
        ? this.minAmountMinor
        : minAmountMinor as int?,
    maxAmountMinor: maxAmountMinor == _unset
        ? this.maxAmountMinor
        : maxAmountMinor as int?,
    datePreset: datePreset == _unset
        ? this.datePreset
        : datePreset as DatePreset?,
    dateFrom: dateFrom == _unset ? this.dateFrom : dateFrom as DateTime?,
    dateTo: dateTo == _unset ? this.dateTo : dateTo as DateTime?,
    customFields: customFields ?? this.customFields,
  );

  /// Removes the date facet.
  TxnFilter withoutDate() =>
      copyWith(datePreset: null, dateFrom: null, dateTo: null);

  Map<String, Object?> toJson() {
    List<String> sorted(Iterable<String> s) => s.toList()..sort();
    String day(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    return {
      if (hasSearch) 'search': search.trim(),
      if (hasPayee) 'payee': payee!.trim(),
      if (importBatchId != null) 'importBatch': importBatchId,
      if (accountIds.isNotEmpty) 'accounts': sorted(accountIds),
      if (categoryIds.isNotEmpty) 'categories': sorted(categoryIds),
      if (uncategorized) 'uncategorized': true,
      if (tagIds.isNotEmpty) 'tags': sorted(tagIds),
      if (types.isNotEmpty)
        'types': [
          for (final t in TxnType.values)
            if (types.contains(t)) t.name,
        ],
      if (statuses.isNotEmpty)
        'statuses': [
          for (final s in TxnStatus.values)
            if (statuses.contains(s)) s.name,
        ],
      if (minAmountMinor != null) 'minAmount': minAmountMinor,
      if (maxAmountMinor != null) 'maxAmount': maxAmountMinor,
      if (datePreset != null) 'datePreset': datePreset!.name,
      if (dateFrom != null) 'dateFrom': day(dateFrom!),
      if (dateTo != null) 'dateTo': day(dateTo!),
      if (customFields.isNotEmpty)
        'customFields': [for (final c in customFields) c.toJson()],
    };
  }

  static const _setEq = SetEquality<Object?>();
  static const _listEq = ListEquality<CustomFieldFilter>();

  @override
  bool operator ==(Object other) =>
      other is TxnFilter &&
      other.search == search &&
      other.payee == payee &&
      other.importBatchId == importBatchId &&
      _setEq.equals(other.accountIds, accountIds) &&
      _setEq.equals(other.categoryIds, categoryIds) &&
      other.uncategorized == uncategorized &&
      _setEq.equals(other.tagIds, tagIds) &&
      _setEq.equals(other.types, types) &&
      _setEq.equals(other.statuses, statuses) &&
      other.minAmountMinor == minAmountMinor &&
      other.maxAmountMinor == maxAmountMinor &&
      other.datePreset == datePreset &&
      other.dateFrom == dateFrom &&
      other.dateTo == dateTo &&
      _listEq.equals(other.customFields, customFields);

  @override
  int get hashCode => Object.hash(
    search,
    payee,
    importBatchId,
    _setEq.hash(accountIds),
    _setEq.hash(categoryIds),
    uncategorized,
    _setEq.hash(tagIds),
    _setEq.hash(types),
    _setEq.hash(statuses),
    minAmountMinor,
    maxAmountMinor,
    datePreset,
    dateFrom,
    dateTo,
    _listEq.hash(customFields),
  );

  @override
  String toString() => 'TxnFilter(${toJson()})';
}
