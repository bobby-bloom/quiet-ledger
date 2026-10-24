import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/core/settings/setting_def.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

// The generic settings UI handles defs as `SettingDef<Object?>`. Calling
// `SettingsController.set` with such a def fails at runtime (its `encode`
// and `validate` functions take the concrete `T`), so values are written at
// the JSON level through a proxy def with the same key.

/// The stored (JSON-level) value of [def]: enums by name, everything else
/// as is.
Object? currentJson(SettingsSnapshot s, SettingDef<Object?> def) {
  final v = s.get(def);
  return v is Enum ? v.name : v;
}

/// Writes the JSON-level [json] for [def] (enum name, int, bool, string,
/// list of strings or null).
Future<void> writeSettingJson(
  WidgetRef ref,
  SettingDef<Object?> def,
  Object? json,
) => writeSettingJsonWith(ref.read(settingsProvider.notifier), def, json);

Future<void> writeSettingJsonWith(
  SettingsController controller,
  SettingDef<Object?> def,
  Object? json,
) {
  final proxy = SettingDef<Object?>(
    key: def.key,
    section: def.section,
    defaultValue: null,
    label: def.label,
    editor: def.editor,
    decode: (j) => j,
    encode: (v) => v,
    bootstrap: def.bootstrap,
  );
  return controller.set<Object?>(proxy, json);
}

/// Localised validation for a candidate value; null when valid.
String? validateSettingJson(
  AppLocalizations l,
  SettingDef<Object?> def,
  Object? json,
) {
  final e = def.editor;
  switch (e) {
    case IntEditor(:final min, :final max):
      if (json is! int) return l.settingsUiInvalidNumber;
      if (json < min || json > max) return l.settingsUiOutOfRange(min, max);
    case PercentBpEditor(:final min, :final max):
      if (json is! int) return l.settingsUiInvalidNumber;
      if (json < min || json > max) {
        return l.settingsUiOutOfRangeText(formatBp(min), formatBp(max));
      }
    case MoneyEditor(:final allowNull):
      if (json == null && !allowNull) return l.settingsUiInvalidNumber;
    default:
      break;
  }
  if (def is SettingDef<String> && json is String) {
    if (def.validate?.call(json) != null) return l.settingsUiInvalidValue;
  }
  if (def is SettingDef<int> && json is int && e is! IntEditor) {
    if (def.validate?.call(json) != null) return l.settingsUiInvalidValue;
  }
  return null;
}

/// Basis points → "2.5 %"-style text without trailing zeros.
String formatBp(int bp, {String decimal = '.'}) {
  final neg = bp < 0;
  final a = bp.abs();
  final whole = a ~/ 100;
  final frac = a % 100;
  var s = '$whole';
  if (frac != 0) {
    final f = frac.toString().padLeft(2, '0').replaceAll(RegExp(r'0$'), '');
    s = '$s$decimal$f';
  }
  return '${neg ? '−' : ''}$s %';
}

/// Parses "2,5", "2.5", "-1.25" (percent) into basis points; null if not a
/// number or more than two decimals.
int? parsePercentToBp(String input) {
  final t = input
      .replaceAll('%', '')
      .replaceAll('−', '-')
      .replaceAll(' ', '')
      .replaceAll(',', '.');
  final m = RegExp(r'^(-?)(\d+)(?:\.(\d{1,2}))?$').firstMatch(t);
  if (m == null) return null;
  final whole = int.parse(m[2]!);
  final frac = int.parse((m[3] ?? '').padRight(2, '0'));
  final v = whole * 100 + frac;
  return m[1] == '-' ? -v : v;
}
