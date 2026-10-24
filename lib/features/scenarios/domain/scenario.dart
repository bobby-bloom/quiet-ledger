import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

// Scenario adjustments, stored as a JSON list in `scenarios.adjustments`.
// Every adjustment is an object with a `type` discriminator. Unknown types
// (from a newer app version) are kept verbatim so saving never loses them.
//
// Dates are ISO `yyyy-MM-dd` strings, money is int minor units, rates are
// basis points (1 % = 100 bp).

/// How a change is expressed.
enum ChangeMode {
  /// The value is in basis points of the amount (+500 = +5 %).
  percent,

  /// The value is minor units added to the magnitude (per occurrence for
  /// recurring rules, per month for categories). Positive = more
  /// spending/more income.
  absolute,
}

String _date(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime _parseDate(Object? v) {
  final d = DateTime.parse(v! as String);
  return DateTime(d.year, d.month, d.day);
}

DateTime? _parseDateOrNull(Object? v) => v == null ? null : _parseDate(v);

int _int(Object? v) => (v! as num).toInt();

@immutable
sealed class ScenarioAdjustment {
  const ScenarioAdjustment();

  /// Parses one adjustment; unknown or malformed entries become
  /// [UnknownAdjustment].
  factory ScenarioAdjustment.fromJson(Map<String, Object?> json) {
    try {
      return switch (json['type']) {
        OneOffAdjustment.typeKey => OneOffAdjustment(
          date: _parseDate(json['date']),
          amountMinor: _int(json['amountMinor']),
          accountId: json['accountId']! as String,
          label: json['label'] as String? ?? '',
        ),
        CategoryChangeAdjustment.typeKey => CategoryChangeAdjustment(
          categoryId: json['categoryId']! as String,
          from: _parseDate(json['from']),
          mode: ChangeMode.values.byName(json['mode']! as String),
          value: _int(json['value']),
        ),
        RecurringChangeAdjustment.typeKey => RecurringChangeAdjustment(
          ruleId: json['ruleId']! as String,
          from: _parseDate(json['from']),
          mode: ChangeMode.values.byName(json['mode']! as String),
          value: _int(json['value']),
        ),
        AddRecurringAdjustment.typeKey => AddRecurringAdjustment(
          label: json['label'] as String? ?? '',
          rrule: json['rrule']! as String,
          start: _parseDate(json['start']),
          end: _parseDateOrNull(json['end']),
          amountMinor: _int(json['amountMinor']),
          accountId: json['accountId']! as String,
          transferAccountId: json['transferAccountId'] as String?,
          categoryId: json['categoryId'] as String?,
        ),
        EndRecurringAdjustment.typeKey => EndRecurringAdjustment(
          ruleId: json['ruleId']! as String,
          from: _parseDate(json['from']),
        ),
        ReturnAdjustment.typeKey => ReturnAdjustment(
          returnBp: _int(json['returnBp']),
          accountId: json['accountId'] as String?,
        ),
        InflationAdjustment.typeKey => InflationAdjustment(
          inflationBp: _int(json['inflationBp']),
        ),
        _ => UnknownAdjustment(json),
      };
    } on Object {
      return UnknownAdjustment(json);
    }
  }

  String get type;

  Map<String, Object?> toJson();

  /// Encodes a list for the `scenarios.adjustments` column.
  static String encodeList(List<ScenarioAdjustment> list) =>
      jsonEncode([for (final a in list) a.toJson()]);

  /// Decodes the `scenarios.adjustments` column; invalid JSON yields an
  /// empty list.
  static List<ScenarioAdjustment> decodeList(String? source) {
    if (source == null || source.trim().isEmpty) return const [];
    try {
      final raw = jsonDecode(source);
      if (raw is! List) return const [];
      return [
        for (final e in raw)
          if (e is Map) ScenarioAdjustment.fromJson(e.cast<String, Object?>()),
      ];
    } on FormatException {
      return const [];
    }
  }
}

/// A one-off income (positive) or expense (negative) on [date].
final class OneOffAdjustment extends ScenarioAdjustment {
  const OneOffAdjustment({
    required this.date,
    required this.amountMinor,
    required this.accountId,
    this.label = '',
  });

  static const typeKey = 'oneOff';

  final DateTime date;
  final int amountMinor;
  final String accountId;
  final String label;

  @override
  String get type => typeKey;

  @override
  Map<String, Object?> toJson() => {
    'type': type,
    'date': _date(date),
    'amountMinor': amountMinor,
    'accountId': accountId,
    'label': label,
  };

  @override
  bool operator ==(Object other) =>
      other is OneOffAdjustment &&
      other.date == date &&
      other.amountMinor == amountMinor &&
      other.accountId == accountId &&
      other.label == label;

  @override
  int get hashCode => Object.hash(type, date, amountMinor, accountId, label);
}

/// Changes a category's spending (or income) from [from]: percent scales
/// the expected variable spending and the category's share of recurring
/// rules; absolute adds [value] per month, spread over the days.
final class CategoryChangeAdjustment extends ScenarioAdjustment {
  const CategoryChangeAdjustment({
    required this.categoryId,
    required this.from,
    required this.mode,
    required this.value,
  });

  static const typeKey = 'categoryChange';

  final String categoryId;
  final DateTime from;
  final ChangeMode mode;
  final int value;

  @override
  String get type => typeKey;

  @override
  Map<String, Object?> toJson() => {
    'type': type,
    'categoryId': categoryId,
    'from': _date(from),
    'mode': mode.name,
    'value': value,
  };

  @override
  bool operator ==(Object other) =>
      other is CategoryChangeAdjustment &&
      other.categoryId == categoryId &&
      other.from == from &&
      other.mode == mode &&
      other.value == value;

  @override
  int get hashCode => Object.hash(type, categoryId, from, mode, value);
}

/// Changes every occurrence of a recurring rule (e.g. a salary raise) from
/// [from].
final class RecurringChangeAdjustment extends ScenarioAdjustment {
  const RecurringChangeAdjustment({
    required this.ruleId,
    required this.from,
    required this.mode,
    required this.value,
  });

  static const typeKey = 'recurringChange';

  final String ruleId;
  final DateTime from;
  final ChangeMode mode;
  final int value;

  @override
  String get type => typeKey;

  @override
  Map<String, Object?> toJson() => {
    'type': type,
    'ruleId': ruleId,
    'from': _date(from),
    'mode': mode.name,
    'value': value,
  };

  @override
  bool operator ==(Object other) =>
      other is RecurringChangeAdjustment &&
      other.ruleId == ruleId &&
      other.from == from &&
      other.mode == mode &&
      other.value == value;

  @override
  int get hashCode => Object.hash(type, ruleId, from, mode, value);
}

/// Adds a recurring item that does not exist in the plan.
final class AddRecurringAdjustment extends ScenarioAdjustment {
  const AddRecurringAdjustment({
    required this.rrule,
    required this.start,
    required this.amountMinor,
    required this.accountId,
    this.label = '',
    this.end,
    this.transferAccountId,
    this.categoryId,
  });

  static const typeKey = 'addRecurring';

  final String label;

  /// RRULE without the `RRULE:` prefix.
  final String rrule;
  final DateTime start;
  final DateTime? end;

  /// Signed amount for [accountId] (negative = expense).
  final int amountMinor;
  final String accountId;
  final String? transferAccountId;
  final String? categoryId;

  @override
  String get type => typeKey;

  @override
  Map<String, Object?> toJson() => {
    'type': type,
    'label': label,
    'rrule': rrule,
    'start': _date(start),
    if (end != null) 'end': _date(end!),
    'amountMinor': amountMinor,
    'accountId': accountId,
    if (transferAccountId != null) 'transferAccountId': transferAccountId,
    if (categoryId != null) 'categoryId': categoryId,
  };

  @override
  bool operator ==(Object other) =>
      other is AddRecurringAdjustment &&
      other.label == label &&
      other.rrule == rrule &&
      other.start == start &&
      other.end == end &&
      other.amountMinor == amountMinor &&
      other.accountId == accountId &&
      other.transferAccountId == transferAccountId &&
      other.categoryId == categoryId;

  @override
  int get hashCode => Object.hash(
    type,
    label,
    rrule,
    start,
    end,
    amountMinor,
    accountId,
    transferAccountId,
    categoryId,
  );
}

/// Ends an existing recurring rule: no occurrences on or after [from].
final class EndRecurringAdjustment extends ScenarioAdjustment {
  const EndRecurringAdjustment({required this.ruleId, required this.from});

  static const typeKey = 'endRecurring';

  final String ruleId;
  final DateTime from;

  @override
  String get type => typeKey;

  @override
  Map<String, Object?> toJson() => {
    'type': type,
    'ruleId': ruleId,
    'from': _date(from),
  };

  @override
  bool operator ==(Object other) =>
      other is EndRecurringAdjustment &&
      other.ruleId == ruleId &&
      other.from == from;

  @override
  int get hashCode => Object.hash(type, ruleId, from);
}

/// Changed expected return: for one account, or (no account) for every
/// asset account except checking and cash.
final class ReturnAdjustment extends ScenarioAdjustment {
  const ReturnAdjustment({required this.returnBp, this.accountId});

  static const typeKey = 'return';

  final int returnBp;
  final String? accountId;

  @override
  String get type => typeKey;

  @override
  Map<String, Object?> toJson() => {
    'type': type,
    'returnBp': returnBp,
    if (accountId != null) 'accountId': accountId,
  };

  @override
  bool operator ==(Object other) =>
      other is ReturnAdjustment &&
      other.returnBp == returnBp &&
      other.accountId == accountId;

  @override
  int get hashCode => Object.hash(type, returnBp, accountId);
}

/// Changed inflation assumption.
final class InflationAdjustment extends ScenarioAdjustment {
  const InflationAdjustment({required this.inflationBp});

  static const typeKey = 'inflation';

  final int inflationBp;

  @override
  String get type => typeKey;

  @override
  Map<String, Object?> toJson() => {'type': type, 'inflationBp': inflationBp};

  @override
  bool operator ==(Object other) =>
      other is InflationAdjustment && other.inflationBp == inflationBp;

  @override
  int get hashCode => Object.hash(type, inflationBp);
}

/// An adjustment this version does not understand; kept verbatim and
/// ignored by the engine.
final class UnknownAdjustment extends ScenarioAdjustment {
  const UnknownAdjustment(this.raw);

  final Map<String, Object?> raw;

  @override
  String get type => raw['type'] as String? ?? 'unknown';

  @override
  Map<String, Object?> toJson() => raw;

  @override
  bool operator ==(Object other) =>
      other is UnknownAdjustment &&
      const DeepCollectionEquality().equals(other.raw, raw);

  @override
  int get hashCode => const DeepCollectionEquality().hash(raw);
}

/// A named set of adjustments over the baseline.
@immutable
class ScenarioDef {
  const ScenarioDef({
    required this.id,
    required this.name,
    this.color,
    this.enabled = false,
    this.adjustments = const [],
  });

  final String id;
  final String name;

  /// ARGB colour chosen by the user; null = the comparison slot colour.
  final int? color;

  /// Shown in the comparison on the forecast board.
  final bool enabled;
  final List<ScenarioAdjustment> adjustments;

  static const _unset = Object();

  ScenarioDef copyWith({
    String? id,
    String? name,
    Object? color = _unset,
    bool? enabled,
    List<ScenarioAdjustment>? adjustments,
  }) => ScenarioDef(
    id: id ?? this.id,
    name: name ?? this.name,
    color: color == _unset ? this.color : color as int?,
    enabled: enabled ?? this.enabled,
    adjustments: adjustments ?? this.adjustments,
  );

  @override
  bool operator ==(Object other) =>
      other is ScenarioDef &&
      other.id == id &&
      other.name == name &&
      other.color == color &&
      other.enabled == enabled &&
      const ListEquality<ScenarioAdjustment>().equals(
        other.adjustments,
        adjustments,
      );

  @override
  int get hashCode =>
      Object.hash(id, name, color, enabled, Object.hashAll(adjustments));
}

/// At most this many scenarios are compared with the baseline.
const maxComparedScenarios = 3;

/// The scenarios shown in the comparison: the enabled ones, in order, at
/// most [maxComparedScenarios].
List<ScenarioDef> comparedScenarios(List<ScenarioDef> all) =>
    all.where((s) => s.enabled).take(maxComparedScenarios).toList();
