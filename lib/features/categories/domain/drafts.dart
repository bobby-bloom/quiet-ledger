import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/settings/app_settings.dart';

/// Editable values of a category.
@immutable
class CategoryDraft {
  const CategoryDraft({
    required this.name,
    required this.kind,
    this.parentId,
    this.icon,
    this.color,
    this.favourite = false,
    this.archived = false,
    this.rolloverOverride,
    this.warnThresholdOverride,
  });

  factory CategoryDraft.fromCategory(Category c) => CategoryDraft(
    name: c.name,
    kind: c.kind,
    parentId: c.parentId,
    icon: c.icon,
    color: c.color,
    favourite: c.favourite,
    archived: c.archived,
    rolloverOverride: parseRollover(c.rolloverOverride),
    warnThresholdOverride: c.warnThresholdOverride,
  );

  final String name;
  final CategoryKind kind;
  final String? parentId;

  /// AppIcons key.
  final String? icon;

  /// ARGB colour.
  final int? color;
  final bool favourite;
  final bool archived;

  /// null = use the global budget setting.
  final RolloverMode? rolloverOverride;

  /// Percent (1–100); null = global setting.
  final int? warnThresholdOverride;

  List<DraftProblem> validate() => [
    if (name.trim().isEmpty) DraftProblem.nameRequired,
    if (name.trim().length > 60) DraftProblem.nameTooLong,
    if (warnThresholdOverride != null &&
        (warnThresholdOverride! < 1 || warnThresholdOverride! > 100))
      DraftProblem.thresholdOutOfRange,
  ];

  static const _unset = Object();

  CategoryDraft copyWith({
    String? name,
    CategoryKind? kind,
    Object? parentId = _unset,
    Object? icon = _unset,
    Object? color = _unset,
    bool? favourite,
    bool? archived,
    Object? rolloverOverride = _unset,
    Object? warnThresholdOverride = _unset,
  }) => CategoryDraft(
    name: name ?? this.name,
    kind: kind ?? this.kind,
    parentId: parentId == _unset ? this.parentId : parentId as String?,
    icon: icon == _unset ? this.icon : icon as String?,
    color: color == _unset ? this.color : color as int?,
    favourite: favourite ?? this.favourite,
    archived: archived ?? this.archived,
    rolloverOverride: rolloverOverride == _unset
        ? this.rolloverOverride
        : rolloverOverride as RolloverMode?,
    warnThresholdOverride: warnThresholdOverride == _unset
        ? this.warnThresholdOverride
        : warnThresholdOverride as int?,
  );

  @override
  bool operator ==(Object other) =>
      other is CategoryDraft &&
      other.name == name &&
      other.kind == kind &&
      other.parentId == parentId &&
      other.icon == icon &&
      other.color == color &&
      other.favourite == favourite &&
      other.archived == archived &&
      other.rolloverOverride == rolloverOverride &&
      other.warnThresholdOverride == warnThresholdOverride;

  @override
  int get hashCode => Object.hash(
    name,
    kind,
    parentId,
    icon,
    color,
    favourite,
    archived,
    rolloverOverride,
    warnThresholdOverride,
  );
}

/// Parses `categories.rollover_override` ('none', 'leftover', 'overspent',
/// 'both'); null or unknown = no override.
RolloverMode? parseRollover(String? v) =>
    RolloverMode.values.where((m) => m.name == v).firstOrNull;

enum DraftProblem {
  nameRequired,
  nameTooLong,
  nameTaken,
  thresholdOutOfRange,
  optionsRequired,
}

/// Editable values of a custom field definition.
@immutable
class CustomFieldDraft {
  const CustomFieldDraft({
    required this.name,
    required this.type,
    this.options = const [],
    this.appliesTo = CustomFieldTarget.transaction,
    this.archived = false,
  });

  factory CustomFieldDraft.fromDef(CustomFieldDef d) => CustomFieldDraft(
    name: d.name,
    type: d.type,
    options: decodeOptions(d.options),
    appliesTo:
        CustomFieldTarget.values
            .where((t) => t.name == d.appliesTo)
            .firstOrNull ??
        CustomFieldTarget.transaction,
    archived: d.archived,
  );

  final String name;
  final CustomFieldType type;

  /// Choices for select/multiselect; ignored for other types.
  final List<String> options;
  final CustomFieldTarget appliesTo;
  final bool archived;

  bool get hasOptions => typeHasOptions(type);

  /// Trimmed, non-empty, de-duplicated options.
  List<String> get cleanOptions {
    final seen = <String>{};
    return [
      for (final o in options.map((o) => o.trim()))
        if (o.isNotEmpty && seen.add(o.toLowerCase())) o,
    ];
  }

  List<DraftProblem> validate() => [
    if (name.trim().isEmpty) DraftProblem.nameRequired,
    if (name.trim().length > 60) DraftProblem.nameTooLong,
    if (hasOptions && cleanOptions.isEmpty) DraftProblem.optionsRequired,
  ];

  CustomFieldDraft copyWith({
    String? name,
    CustomFieldType? type,
    List<String>? options,
    CustomFieldTarget? appliesTo,
    bool? archived,
  }) => CustomFieldDraft(
    name: name ?? this.name,
    type: type ?? this.type,
    options: options ?? this.options,
    appliesTo: appliesTo ?? this.appliesTo,
    archived: archived ?? this.archived,
  );
}

/// Entity a custom field applies to (`custom_field_defs.applies_to`).
enum CustomFieldTarget { transaction, account }

bool typeHasOptions(CustomFieldType t) =>
    t == CustomFieldType.select || t == CustomFieldType.multiselect;

/// Decodes the JSON option list of a custom field definition.
List<String> decodeOptions(String json) {
  try {
    final v = jsonDecode(json);
    if (v is List) return [for (final o in v) o.toString()];
  } on FormatException {
    // fall through
  }
  return const [];
}
