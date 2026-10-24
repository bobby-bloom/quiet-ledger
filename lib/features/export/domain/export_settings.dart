import 'package:meta/meta.dart';
import 'package:personal_finance/core/csv/csv_writer.dart';
import 'package:personal_finance/core/settings/setting_def.dart';

// Hidden settings owned by the export feature (not listed in the settings
// catalogue; edited from the export screen).

/// A named set of CSV options (delimiter, encoding, date format, decimal
/// separator, header, column selection/order).
@immutable
class CsvPreset {
  const CsvPreset(this.name, this.options);

  factory CsvPreset.fromJson(Map<String, Object?> j) => CsvPreset(
    j['name'] as String? ?? '',
    CsvOptions.fromJson(
      (j['options'] as Map?)?.cast<String, Object?>() ?? const {},
    ),
  );

  final String name;
  final CsvOptions options;

  Map<String, Object?> toJson() => {'name': name, 'options': options.toJson()};

  @override
  bool operator ==(Object other) =>
      other is CsvPreset && other.name == name && other.options == options;

  @override
  int get hashCode => Object.hash(name, options);
}

abstract final class ExportSettings {
  /// Saved CSV presets, stored as a JSON list.
  static final csvPresets = SettingDef<List<CsvPreset>>(
    key: 'export.csvPresets',
    section: SettingSection.importExport,
    defaultValue: const [],
    label: (l) => l.exportPresets,
    editor: const CustomEditor('/more/export'),
    decode: (j) => j is List
        ? [
            for (final e in j)
              if (e is Map) CsvPreset.fromJson(e.cast<String, Object?>()),
          ].where((p) => p.name.isNotEmpty).toList()
        : const [],
    encode: (v) => [for (final p in v) p.toJson()],
    hidden: true,
  );
}

/// Adds or replaces (by case-insensitive name) [preset]; keeps names sorted.
List<CsvPreset> upsertPreset(List<CsvPreset> presets, CsvPreset preset) {
  final key = preset.name.trim().toLowerCase();
  return [
    for (final p in presets)
      if (p.name.trim().toLowerCase() != key) p,
    preset,
  ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}

List<CsvPreset> removePreset(List<CsvPreset> presets, String name) => [
  for (final p in presets)
    if (p.name != name) p,
];
