import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:personal_finance/core/db/tables.dart';

/// One category line of a split transaction. [amountMinor] has the same sign
/// convention as the parent (negative for expenses).
@immutable
class SplitDraft {
  const SplitDraft({required this.amountMinor, this.categoryId, this.note});

  factory SplitDraft.fromJson(Map<String, Object?> j) => SplitDraft(
    amountMinor: (j['amountMinor']! as num).toInt(),
    categoryId: j['categoryId'] as String?,
    note: j['note'] as String?,
  );

  final int amountMinor;
  final String? categoryId;
  final String? note;

  Map<String, Object?> toJson() => {
    'amountMinor': amountMinor,
    if (categoryId != null) 'categoryId': categoryId,
    if (note != null) 'note': note,
  };

  SplitDraft copyWith({int? amountMinor, String? categoryId, String? note}) =>
      SplitDraft(
        amountMinor: amountMinor ?? this.amountMinor,
        categoryId: categoryId ?? this.categoryId,
        note: note ?? this.note,
      );

  @override
  bool operator ==(Object other) =>
      other is SplitDraft &&
      other.amountMinor == amountMinor &&
      other.categoryId == categoryId &&
      other.note == note;

  @override
  int get hashCode => Object.hash(amountMinor, categoryId, note);
}

/// A transaction as entered by the user, before it is written.
///
/// This is the shared exchange format for quick add, templates, recurring
/// rules (`recurring_rules.template` JSON), rules engine actions and import.
///
/// Sign convention: [amountMinor] is the signed amount for [accountId]
/// (negative = money leaves). For transfers [amountMinor] is negative on the
/// source [accountId] and [transferAccountId] receives `-amountMinor`.
@immutable
class TxnDraft {
  const TxnDraft({
    required this.accountId,
    required this.amountMinor,
    required this.date,
    this.type = TxnType.expense,
    this.valueDate,
    this.payee,
    this.note,
    this.categoryId,
    this.transferAccountId,
    this.status = TxnStatus.cleared,
    this.splits = const [],
    this.tagIds = const [],
    this.customFields = const {},
    this.recurringRuleId,
    this.importBatchId,
    this.importRowRef,
    this.dedupeHash,
    this.currency = 'EUR',
  });

  factory TxnDraft.fromJson(Map<String, Object?> j) => TxnDraft(
    accountId: j['accountId'] as String? ?? '',
    amountMinor: (j['amountMinor'] as num?)?.toInt() ?? 0,
    date: j['date'] == null
        ? DateTime.now()
        : DateTime.parse(j['date']! as String),
    type: TxnType.values.byName(j['type'] as String? ?? 'expense'),
    valueDate: j['valueDate'] == null
        ? null
        : DateTime.parse(j['valueDate']! as String),
    payee: j['payee'] as String?,
    note: j['note'] as String?,
    categoryId: j['categoryId'] as String?,
    transferAccountId: j['transferAccountId'] as String?,
    status: TxnStatus.values.byName(j['status'] as String? ?? 'cleared'),
    splits: [
      for (final s in (j['splits'] as List? ?? const []))
        SplitDraft.fromJson((s as Map).cast()),
    ],
    tagIds: [for (final t in (j['tagIds'] as List? ?? const [])) t as String],
    customFields: ((j['customFields'] as Map?) ?? const {}).cast(),
    currency: j['currency'] as String? ?? 'EUR',
  );

  final String accountId;
  final int amountMinor;
  final DateTime date;
  final TxnType type;
  final DateTime? valueDate;
  final String? payee;
  final String? note;

  /// Ignored when [splits] is non-empty or for transfers.
  final String? categoryId;

  /// Target account for transfers.
  final String? transferAccountId;
  final TxnStatus status;
  final List<SplitDraft> splits;
  final List<String> tagIds;

  /// Custom field id -> JSON-compatible value.
  final Map<String, Object?> customFields;
  final String? recurringRuleId;
  final String? importBatchId;
  final String? importRowRef;
  final String? dedupeHash;
  final String currency;

  bool get isSplit => splits.isNotEmpty;
  bool get isTransfer => type == TxnType.transfer;

  /// Sum of split amounts minus the total; 0 when balanced.
  int get splitRemainder =>
      amountMinor - splits.fold(0, (a, s) => a + s.amountMinor);

  /// Returns a list of problems; empty when the draft can be saved.
  List<String> validate() => [
    if (accountId.isEmpty) 'accountId',
    if (isTransfer && (transferAccountId == null || transferAccountId!.isEmpty))
      'transferAccountId',
    if (isTransfer && transferAccountId == accountId) 'sameAccount',
    if (isSplit && splitRemainder != 0) 'splitRemainder',
  ];

  /// JSON for templates and recurring rules. Import bookkeeping fields are
  /// not included.
  Map<String, Object?> toJson() => {
    'accountId': accountId,
    'amountMinor': amountMinor,
    'date': date.toIso8601String(),
    'type': type.name,
    if (valueDate != null) 'valueDate': valueDate!.toIso8601String(),
    if (payee != null) 'payee': payee,
    if (note != null) 'note': note,
    if (categoryId != null) 'categoryId': categoryId,
    if (transferAccountId != null) 'transferAccountId': transferAccountId,
    'status': status.name,
    if (splits.isNotEmpty) 'splits': [for (final s in splits) s.toJson()],
    if (tagIds.isNotEmpty) 'tagIds': tagIds,
    if (customFields.isNotEmpty) 'customFields': customFields,
    if (currency != 'EUR') 'currency': currency,
  };

  static const _unset = Object();

  TxnDraft copyWith({
    String? accountId,
    int? amountMinor,
    DateTime? date,
    TxnType? type,
    Object? valueDate = _unset,
    Object? payee = _unset,
    Object? note = _unset,
    Object? categoryId = _unset,
    Object? transferAccountId = _unset,
    TxnStatus? status,
    List<SplitDraft>? splits,
    List<String>? tagIds,
    Map<String, Object?>? customFields,
    Object? recurringRuleId = _unset,
    Object? importBatchId = _unset,
    Object? importRowRef = _unset,
    Object? dedupeHash = _unset,
  }) => TxnDraft(
    accountId: accountId ?? this.accountId,
    amountMinor: amountMinor ?? this.amountMinor,
    date: date ?? this.date,
    type: type ?? this.type,
    valueDate: valueDate == _unset ? this.valueDate : valueDate as DateTime?,
    payee: payee == _unset ? this.payee : payee as String?,
    note: note == _unset ? this.note : note as String?,
    categoryId: categoryId == _unset ? this.categoryId : categoryId as String?,
    transferAccountId: transferAccountId == _unset
        ? this.transferAccountId
        : transferAccountId as String?,
    status: status ?? this.status,
    splits: splits ?? this.splits,
    tagIds: tagIds ?? this.tagIds,
    customFields: customFields ?? this.customFields,
    recurringRuleId: recurringRuleId == _unset
        ? this.recurringRuleId
        : recurringRuleId as String?,
    importBatchId: importBatchId == _unset
        ? this.importBatchId
        : importBatchId as String?,
    importRowRef: importRowRef == _unset
        ? this.importRowRef
        : importRowRef as String?,
    dedupeHash: dedupeHash == _unset ? this.dedupeHash : dedupeHash as String?,
    currency: currency,
  );

  static const _listEq = ListEquality<Object?>();
  static const _mapEq = MapEquality<String, Object?>();

  @override
  bool operator ==(Object other) =>
      other is TxnDraft &&
      other.accountId == accountId &&
      other.amountMinor == amountMinor &&
      other.date == date &&
      other.type == type &&
      other.valueDate == valueDate &&
      other.payee == payee &&
      other.note == note &&
      other.categoryId == categoryId &&
      other.transferAccountId == transferAccountId &&
      other.status == status &&
      _listEq.equals(other.splits, splits) &&
      _listEq.equals(other.tagIds, tagIds) &&
      _mapEq.equals(other.customFields, customFields) &&
      other.recurringRuleId == recurringRuleId &&
      other.importBatchId == importBatchId;

  @override
  int get hashCode => Object.hash(
    accountId,
    amountMinor,
    date,
    type,
    payee,
    note,
    categoryId,
    transferAccountId,
    status,
    Object.hashAll(splits),
    Object.hashAll(tagIds),
  );

  @override
  String toString() => 'TxnDraft(${toJson()})';
}

/// Strips time-of-day: all ledger dates are local midnight.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
