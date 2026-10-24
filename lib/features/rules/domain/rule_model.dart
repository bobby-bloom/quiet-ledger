import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:personal_finance/core/db/tables.dart';

// Auto-categorisation rules (PLAN.md §2.1). Pure Dart.
//
// Storage: `rules.conditions` holds [RuleConditions.toJson] and
// `rules.actions` holds [RuleActions.toJson], both JSON-encoded.

/// Which text of a transaction a [TextCondition] looks at.
enum RuleTextField {
  payee,
  note,

  /// Payee or note (matches when either matches).
  payeeOrNote,
}

/// How a [TextCondition] compares. All comparisons ignore case.
enum TextOperator { contains, equals, startsWith, endsWith, regex }

/// How the conditions of a rule combine.
enum MatchMode { all, any }

/// One condition of a rule.
@immutable
sealed class RuleCondition {
  const RuleCondition();

  factory RuleCondition.fromJson(Map<String, Object?> j) {
    switch (j['kind']) {
      case 'text':
        return TextCondition(
          field: _enumByName(
            RuleTextField.values,
            j['field'] as String?,
            RuleTextField.payeeOrNote,
          ),
          operator: _enumByName(
            TextOperator.values,
            j['op'] as String?,
            TextOperator.contains,
          ),
          value: j['value'] as String? ?? '',
          negate: j['negate'] as bool? ?? false,
        );
      case 'amount':
        return AmountCondition(
          minMinor: (j['min'] as num?)?.toInt(),
          maxMinor: (j['max'] as num?)?.toInt(),
          absolute: j['abs'] as bool? ?? true,
        );
      case 'account':
        return AccountCondition([
          for (final a in (j['ids'] as List? ?? const [])) a as String,
        ]);
      case 'type':
        return TypeCondition([
          for (final t in (j['types'] as List? ?? const []))
            ?TxnType.values.firstWhereOrNull((v) => v.name == t),
        ]);
      default:
        throw FormatException('Unknown rule condition: ${j['kind']}');
    }
  }

  Map<String, Object?> toJson();

  /// Whether the condition is complete enough to be evaluated. Incomplete
  /// conditions are ignored (they neither match nor block).
  bool get isComplete;
}

/// Payee/note text comparison (case-insensitive).
@immutable
class TextCondition extends RuleCondition {
  const TextCondition({
    this.field = RuleTextField.payeeOrNote,
    this.operator = TextOperator.contains,
    this.value = '',
    this.negate = false,
  });

  final RuleTextField field;
  final TextOperator operator;
  final String value;

  /// Inverts the result ("does not contain").
  final bool negate;

  @override
  bool get isComplete =>
      value.trim().isNotEmpty &&
      (operator != TextOperator.regex || isValidRegex(value));

  TextCondition copyWith({
    RuleTextField? field,
    TextOperator? operator,
    String? value,
    bool? negate,
  }) => TextCondition(
    field: field ?? this.field,
    operator: operator ?? this.operator,
    value: value ?? this.value,
    negate: negate ?? this.negate,
  );

  @override
  Map<String, Object?> toJson() => {
    'kind': 'text',
    'field': field.name,
    'op': operator.name,
    'value': value,
    if (negate) 'negate': true,
  };

  @override
  bool operator ==(Object other) =>
      other is TextCondition &&
      other.field == field &&
      other.operator == operator &&
      other.value == value &&
      other.negate == negate;

  @override
  int get hashCode => Object.hash(field, operator, value, negate);
}

/// Amount range in minor units, inclusive. With [absolute] the sign is
/// ignored (an expense of 12,50 is 1250).
@immutable
class AmountCondition extends RuleCondition {
  const AmountCondition({this.minMinor, this.maxMinor, this.absolute = true});

  final int? minMinor;
  final int? maxMinor;
  final bool absolute;

  @override
  bool get isComplete => minMinor != null || maxMinor != null;

  AmountCondition copyWith({
    Object? minMinor = _unset,
    Object? maxMinor = _unset,
    bool? absolute,
  }) => AmountCondition(
    minMinor: minMinor == _unset ? this.minMinor : minMinor as int?,
    maxMinor: maxMinor == _unset ? this.maxMinor : maxMinor as int?,
    absolute: absolute ?? this.absolute,
  );

  @override
  Map<String, Object?> toJson() => {
    'kind': 'amount',
    'min': ?minMinor,
    'max': ?maxMinor,
    'abs': absolute,
  };

  @override
  bool operator ==(Object other) =>
      other is AmountCondition &&
      other.minMinor == minMinor &&
      other.maxMinor == maxMinor &&
      other.absolute == absolute;

  @override
  int get hashCode => Object.hash(minMinor, maxMinor, absolute);
}

/// Transaction is in one of [accountIds].
@immutable
class AccountCondition extends RuleCondition {
  const AccountCondition(this.accountIds);

  final List<String> accountIds;

  @override
  bool get isComplete => accountIds.isNotEmpty;

  @override
  Map<String, Object?> toJson() => {'kind': 'account', 'ids': accountIds};

  @override
  bool operator ==(Object other) =>
      other is AccountCondition &&
      const ListEquality<String>().equals(other.accountIds, accountIds);

  @override
  int get hashCode => Object.hashAll(accountIds);
}

/// Transaction type is one of [types].
@immutable
class TypeCondition extends RuleCondition {
  const TypeCondition(this.types);

  final List<TxnType> types;

  @override
  bool get isComplete => types.isNotEmpty;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'type',
    'types': [for (final t in types) t.name],
  };

  @override
  bool operator ==(Object other) =>
      other is TypeCondition &&
      const ListEquality<TxnType>().equals(other.types, types);

  @override
  int get hashCode => Object.hashAll(types);
}

/// The condition list of a rule.
@immutable
class RuleConditions {
  const RuleConditions({this.mode = MatchMode.all, this.items = const []});

  factory RuleConditions.fromJson(Map<String, Object?> j) => RuleConditions(
    mode: _enumByName(MatchMode.values, j['match'] as String?, MatchMode.all),
    items: [
      for (final c in (j['items'] as List? ?? const []))
        if (c is Map) RuleCondition.fromJson(c.cast()),
    ],
  );

  factory RuleConditions.decode(String json) {
    if (json.trim().isEmpty) return const RuleConditions();
    final v = jsonDecode(json);
    if (v is! Map) return const RuleConditions();
    return RuleConditions.fromJson(v.cast());
  }

  final MatchMode mode;
  final List<RuleCondition> items;

  /// Conditions that take part in matching.
  List<RuleCondition> get effective => [
    for (final c in items)
      if (c.isComplete) c,
  ];

  Map<String, Object?> toJson() => {
    'match': mode.name,
    'items': [for (final c in items) c.toJson()],
  };

  String encode() => jsonEncode(toJson());

  RuleConditions copyWith({MatchMode? mode, List<RuleCondition>? items}) =>
      RuleConditions(mode: mode ?? this.mode, items: items ?? this.items);

  @override
  bool operator ==(Object other) =>
      other is RuleConditions &&
      other.mode == mode &&
      const ListEquality<RuleCondition>().equals(other.items, items);

  @override
  int get hashCode => Object.hash(mode, Object.hashAll(items));
}

/// What a matching rule does. Null / empty members are not touched.
@immutable
class RuleActions {
  const RuleActions({
    this.categoryId,
    this.addTagIds = const [],
    this.customFields = const {},
    this.payee,
    this.status,
    this.note,
    this.overwrite = false,
  });

  factory RuleActions.fromJson(Map<String, Object?> j) => RuleActions(
    categoryId: j['categoryId'] as String?,
    addTagIds: [for (final t in (j['addTagIds'] as List? ?? const [])) '$t'],
    customFields: ((j['customFields'] as Map?) ?? const {}).cast(),
    payee: j['payee'] as String?,
    status: TxnStatus.values.firstWhereOrNull((s) => s.name == j['status']),
    note: j['note'] as String?,
    overwrite: j['overwrite'] as bool? ?? false,
  );

  factory RuleActions.decode(String json) {
    if (json.trim().isEmpty) return const RuleActions();
    final v = jsonDecode(json);
    if (v is! Map) return const RuleActions();
    return RuleActions.fromJson(v.cast());
  }

  final String? categoryId;
  final List<String> addTagIds;

  /// Custom field id -> JSON-compatible value.
  final Map<String, Object?> customFields;

  /// Renames / normalises the payee. Always replaces the payee of a matching
  /// transaction (that is what a rename is for).
  final String? payee;
  final TxnStatus? status;
  final String? note;

  /// When true the rule also replaces category, note, status and custom
  /// fields that already have a value. Otherwise it only fills empty ones.
  final bool overwrite;

  bool get isEmpty =>
      categoryId == null &&
      addTagIds.isEmpty &&
      customFields.isEmpty &&
      (payee == null || payee!.trim().isEmpty) &&
      status == null &&
      (note == null || note!.trim().isEmpty);

  Map<String, Object?> toJson() => {
    'categoryId': ?categoryId,
    if (addTagIds.isNotEmpty) 'addTagIds': addTagIds,
    if (customFields.isNotEmpty) 'customFields': customFields,
    if (payee != null && payee!.trim().isNotEmpty) 'payee': payee,
    if (status != null) 'status': status!.name,
    if (note != null && note!.trim().isNotEmpty) 'note': note,
    if (overwrite) 'overwrite': true,
  };

  String encode() => jsonEncode(toJson());

  RuleActions copyWith({
    Object? categoryId = _unset,
    List<String>? addTagIds,
    Map<String, Object?>? customFields,
    Object? payee = _unset,
    Object? status = _unset,
    Object? note = _unset,
    bool? overwrite,
  }) => RuleActions(
    categoryId: categoryId == _unset ? this.categoryId : categoryId as String?,
    addTagIds: addTagIds ?? this.addTagIds,
    customFields: customFields ?? this.customFields,
    payee: payee == _unset ? this.payee : payee as String?,
    status: status == _unset ? this.status : status as TxnStatus?,
    note: note == _unset ? this.note : note as String?,
    overwrite: overwrite ?? this.overwrite,
  );

  @override
  bool operator ==(Object other) =>
      other is RuleActions &&
      other.categoryId == categoryId &&
      const ListEquality<String>().equals(other.addTagIds, addTagIds) &&
      const MapEquality<String, Object?>().equals(
        other.customFields,
        customFields,
      ) &&
      other.payee == payee &&
      other.status == status &&
      other.note == note &&
      other.overwrite == overwrite;

  @override
  int get hashCode => Object.hash(
    categoryId,
    Object.hashAll(addTagIds),
    payee,
    status,
    note,
    overwrite,
  );
}

/// A complete rule as used by the engine and the editor.
@immutable
class RuleDef {
  const RuleDef({
    required this.name,
    this.id,
    this.priority = 0,
    this.conditions = const RuleConditions(),
    this.actions = const RuleActions(),
    this.applyOnEntry = true,
    this.applyOnImport = true,
    this.enabled = true,
  });

  /// Null for a rule that has not been saved yet.
  final String? id;
  final String name;

  /// Lower values run first (the list order in the rules screen).
  final int priority;
  final RuleConditions conditions;
  final RuleActions actions;
  final bool applyOnEntry;
  final bool applyOnImport;
  final bool enabled;

  /// A rule needs at least one usable condition and one action.
  bool get isValid =>
      name.trim().isNotEmpty &&
      conditions.effective.isNotEmpty &&
      !actions.isEmpty;

  RuleDef copyWith({
    String? id,
    String? name,
    int? priority,
    RuleConditions? conditions,
    RuleActions? actions,
    bool? applyOnEntry,
    bool? applyOnImport,
    bool? enabled,
  }) => RuleDef(
    id: id ?? this.id,
    name: name ?? this.name,
    priority: priority ?? this.priority,
    conditions: conditions ?? this.conditions,
    actions: actions ?? this.actions,
    applyOnEntry: applyOnEntry ?? this.applyOnEntry,
    applyOnImport: applyOnImport ?? this.applyOnImport,
    enabled: enabled ?? this.enabled,
  );

  @override
  bool operator ==(Object other) =>
      other is RuleDef &&
      other.id == id &&
      other.name == name &&
      other.priority == priority &&
      other.conditions == conditions &&
      other.actions == actions &&
      other.applyOnEntry == applyOnEntry &&
      other.applyOnImport == applyOnImport &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    priority,
    conditions,
    actions,
    applyOnEntry,
    applyOnImport,
    enabled,
  );

  @override
  String toString() => 'RuleDef($name, ${conditions.encode()})';
}

/// Whether [pattern] compiles as a regular expression.
bool isValidRegex(String pattern) {
  try {
    RegExp(pattern);
    return true;
  } on FormatException {
    return false;
  }
}

const _unset = Object();

T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) =>
    values.firstWhereOrNull((v) => v.name == name) ?? fallback;
