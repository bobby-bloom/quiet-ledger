import 'package:flutter/foundation.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

/// Sections of the settings screen (PLAN.md §2.7).
enum SettingSection {
  general,
  appearance,
  privacy,
  navigation,
  dashboard,
  entry,
  transactions,
  categories,
  budgets,
  recurring,
  forecast,
  reports,
  security,
  importExport,
  data,
  sync,
}

/// Where a setting may be stored. Account/category scopes override global.
enum SettingScope { global, account, category }

typedef L10nText = String Function(AppLocalizations l);

/// Describes how the generic settings UI edits a value.
sealed class SettingEditor {
  const SettingEditor();
}

class SwitchEditor extends SettingEditor {
  const SwitchEditor();
}

/// A fixed set of choices. [labels] maps each stored value to its label.
class ChoiceEditor extends SettingEditor {
  const ChoiceEditor(this.values, this.labels);
  final List<String> values;
  final String Function(AppLocalizations l, String value) labels;
}

class IntEditor extends SettingEditor {
  const IntEditor({
    required this.min,
    required this.max,
    this.step = 1,
    this.unit,
  });
  final int min;
  final int max;
  final int step;
  final L10nText? unit;
}

/// An amount in minor units (cents).
class MoneyEditor extends SettingEditor {
  const MoneyEditor({this.allowNull = true});
  final bool allowNull;
}

/// A rate in basis points shown as percent.
class PercentBpEditor extends SettingEditor {
  const PercentBpEditor({required this.min, required this.max});
  final int min;
  final int max;
}

class TextEditor extends SettingEditor {
  const TextEditor({this.hint});
  final String? hint;
}

class ColorEditor extends SettingEditor {
  const ColorEditor();
}

/// Time of day stored as minutes after midnight.
class TimeOfDayEditor extends SettingEditor {
  const TimeOfDayEditor();
}

/// Ordered multi-choice (e.g. nav tabs, quick-add field order).
class OrderedListEditor extends SettingEditor {
  const OrderedListEditor(this.values, this.labels, {this.reorderable = true});
  final List<String> values;
  final String Function(AppLocalizations l, String value) labels;
  final bool reorderable;
}

/// Edited by a dedicated screen (route path), e.g. the dashboard editor.
class CustomEditor extends SettingEditor {
  const CustomEditor(this.route);
  final String route;
}

/// A typed, validated setting (PLAN.md §2.7). Values are stored as JSON in
/// the `settings` table.
@immutable
class SettingDef<T> {
  const SettingDef({
    required this.key,
    required this.section,
    required this.defaultValue,
    required this.label,
    required this.editor,
    required this.decode,
    required this.encode,
    this.description,
    this.validate,
    this.scopes = const {SettingScope.global},
    this.keywords = const [],
    this.hidden = false,
    this.bootstrap = false,
    this.module,
  });

  static SettingDef<bool> boolean({
    required String key,
    required SettingSection section,
    required bool defaultValue,
    required L10nText label,
    L10nText? description,
    Set<SettingScope> scopes = const {SettingScope.global},
    List<String> keywords = const [],
    bool hidden = false,
    bool bootstrap = false,
    String? module,
  }) => SettingDef<bool>(
    key: key,
    section: section,
    defaultValue: defaultValue,
    label: label,
    description: description,
    editor: const SwitchEditor(),
    decode: (j) => j is bool ? j : defaultValue,
    encode: (v) => v,
    scopes: scopes,
    keywords: keywords,
    hidden: hidden,
    bootstrap: bootstrap,
    module: module,
  );

  /// Enum-backed choice setting. Stored as the enum's `name`.
  static SettingDef<E> choice<E extends Enum>({
    required String key,
    required SettingSection section,
    required List<E> values,
    required E defaultValue,
    required L10nText label,
    required String Function(AppLocalizations l, E value) valueLabel,
    L10nText? description,
    List<String> keywords = const [],
    bool hidden = false,
    bool bootstrap = false,
    String? module,
  }) => SettingDef<E>(
    key: key,
    section: section,
    defaultValue: defaultValue,
    label: label,
    description: description,
    editor: ChoiceEditor(
      values.map((e) => e.name).toList(),
      (l, v) => valueLabel(l, values.byName(v)),
    ),
    decode: (j) => values.where((e) => e.name == j).firstOrNull ?? defaultValue,
    encode: (v) => v.name,
    keywords: keywords,
    hidden: hidden,
    bootstrap: bootstrap,
    module: module,
  );

  static SettingDef<int> integer({
    required String key,
    required SettingSection section,
    required int defaultValue,
    required L10nText label,
    required int min,
    required int max,
    int step = 1,
    L10nText? unit,
    L10nText? description,
    Set<SettingScope> scopes = const {SettingScope.global},
    List<String> keywords = const [],
    bool hidden = false,
    bool bootstrap = false,
    String? module,
    SettingEditor? editor,
  }) => SettingDef<int>(
    key: key,
    section: section,
    defaultValue: defaultValue,
    label: label,
    description: description,
    editor: editor ?? IntEditor(min: min, max: max, step: step, unit: unit),
    decode: (j) => j is num ? j.toInt().clamp(min, max) : defaultValue,
    encode: (v) => v,
    validate: (v) => v < min || v > max ? 'out of range $min..$max' : null,
    scopes: scopes,
    keywords: keywords,
    hidden: hidden,
    bootstrap: bootstrap,
    module: module,
  );

  /// Nullable integer, e.g. an optional money threshold.
  static SettingDef<int?> optionalInt({
    required String key,
    required SettingSection section,
    required L10nText label,
    required SettingEditor editor,
    int? defaultValue,
    L10nText? description,
    Set<SettingScope> scopes = const {SettingScope.global},
    List<String> keywords = const [],
    bool hidden = false,
    String? module,
  }) => SettingDef<int?>(
    key: key,
    section: section,
    defaultValue: defaultValue,
    label: label,
    description: description,
    editor: editor,
    decode: (j) => j is num ? j.toInt() : null,
    encode: (v) => v,
    scopes: scopes,
    keywords: keywords,
    hidden: hidden,
    module: module,
  );

  static SettingDef<String> string({
    required String key,
    required SettingSection section,
    required String defaultValue,
    required L10nText label,
    L10nText? description,
    String? hint,
    List<String> keywords = const [],
    bool hidden = false,
    bool bootstrap = false,
    String? module,
    SettingEditor? editor,
    String? Function(String)? validate,
  }) => SettingDef<String>(
    key: key,
    section: section,
    defaultValue: defaultValue,
    label: label,
    description: description,
    editor: editor ?? TextEditor(hint: hint),
    decode: (j) => j is String ? j : defaultValue,
    encode: (v) => v,
    validate: validate,
    keywords: keywords,
    hidden: hidden,
    bootstrap: bootstrap,
    module: module,
  );

  static SettingDef<String?> optionalString({
    required String key,
    required SettingSection section,
    required L10nText label,
    L10nText? description,
    SettingEditor editor = const TextEditor(),
    List<String> keywords = const [],
    bool hidden = false,
    String? module,
  }) => SettingDef<String?>(
    key: key,
    section: section,
    defaultValue: null,
    label: label,
    description: description,
    editor: editor,
    decode: (j) => j is String ? j : null,
    encode: (v) => v,
    keywords: keywords,
    hidden: hidden,
    module: module,
  );

  static SettingDef<List<String>> stringList({
    required String key,
    required SettingSection section,
    required List<String> defaultValue,
    required L10nText label,
    required SettingEditor editor,
    L10nText? description,
    List<String> keywords = const [],
    bool hidden = false,
    String? module,
  }) => SettingDef<List<String>>(
    key: key,
    section: section,
    defaultValue: defaultValue,
    label: label,
    description: description,
    editor: editor,
    decode: (j) => j is List ? j.whereType<String>().toList() : defaultValue,
    encode: (v) => v,
    keywords: keywords,
    hidden: hidden,
    module: module,
  );

  /// Dotted key, e.g. `appearance.themeMode`.
  final String key;
  final SettingSection section;
  final T defaultValue;
  final L10nText label;
  final L10nText? description;
  final SettingEditor editor;
  final T Function(Object? json) decode;
  final Object? Function(T value) encode;

  /// Returns an error message when the value is invalid.
  final String? Function(T value)? validate;
  final Set<SettingScope> scopes;

  /// Extra search terms (EN and DE) for the settings search.
  final List<String> keywords;

  /// Not shown in the settings UI (internal state such as onboarding).
  final bool hidden;

  /// Mirrored to shared_preferences so it is available before the DB opens.
  final bool bootstrap;

  /// Module this setting belongs to; hidden when the module is switched off.
  final String? module;

  /// Encodes [value] to JSON. Safe to call through a `SettingDef<Object?>`
  /// (reading the [encode] field that way fails Dart's covariance check).
  Object? encodeValue(Object? value) => encode(value as T);

  /// Validates [value]; safe through a `SettingDef<Object?>`.
  String? validateValue(Object? value) => validate?.call(value as T);

  @override
  bool operator ==(Object other) => other is SettingDef && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'SettingDef($key)';
}
