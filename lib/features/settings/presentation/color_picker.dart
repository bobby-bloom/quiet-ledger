import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:personal_finance/app/theme/app_theme.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

/// `#RRGGBB` for [c] (alpha dropped).
String colorToHex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// Parses `#RRGGBB`, `RRGGBB` or `#RGB`; null when invalid.
Color? parseHexColor(String input) {
  var t = input.trim().replaceFirst('#', '');
  if (RegExp(r'^[0-9a-fA-F]{3}$').hasMatch(t)) {
    t = t.split('').map((c) => '$c$c').join();
  }
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(t)) return null;
  return Color(0xFF000000 | int.parse(t, radix: 16));
}

/// The accent presets, taken from the theme so no colour is hard-coded.
List<(AccentScheme, Color)> accentPresets() => [
  for (final a in AccentScheme.values)
    if (a != AccentScheme.custom)
      (a, AppTheme(accent: a).light().colorScheme.primary),
];

/// Picks an accent colour: presets, a hue/saturation/lightness editor and a
/// HEX field. Returns the colour or null when cancelled.
Future<Color?> showAccentColorPicker(
  BuildContext context, {
  required Color initial,
  required String title,
}) => showDialog<Color>(
  context: context,
  builder: (_) => _ColorPickerDialog(initial: initial, title: title),
);

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.initial, required this.title});

  final Color initial;
  final String title;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late HSLColor _hsl = HSLColor.fromColor(widget.initial);
  late final _hex = TextEditingController(text: colorToHex(widget.initial));
  String? _hexError;

  Color get _color => _hsl.toColor();

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _set(HSLColor c, {bool updateHex = true}) {
    setState(() {
      _hsl = c;
      _hexError = null;
      if (updateHex) _hex.text = colorToHex(c.toColor());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final presets = accentPresets();
    final cs = context.colors;
    Widget slider(
      String label,
      double value,
      double max,
      ValueChanged<double> onChanged,
      List<Color> track,
    ) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.text.labelMedium),
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: Space.lg),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: LinearGradient(colors: track),
              ),
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.transparent,
                inactiveTrackColor: Colors.transparent,
                thumbColor: cs.onSurface,
                overlayColor: cs.onSurface.withValues(alpha: 0.1),
              ),
              child: Slider(
                value: value,
                max: max,
                semanticFormatterCallback: (v) => v.round().toString(),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ],
    );

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.settingsUiPresets, style: context.text.labelMedium),
              const SizedBox(height: Space.xs),
              Wrap(
                spacing: Space.xs,
                runSpacing: Space.xs,
                children: [
                  for (final (scheme, c) in presets)
                    _Swatch(
                      color: c,
                      label: accentLabel(l, scheme),
                      selected: c.toARGB32() == _color.toARGB32(),
                      onTap: () => _set(HSLColor.fromColor(c)),
                    ),
                ],
              ),
              const SizedBox(height: Space.md),
              Text(l.settingsUiCustomColor, style: context.text.labelMedium),
              const SizedBox(height: Space.xs),
              slider(
                l.settingsUiHue,
                _hsl.hue,
                360,
                (v) => _set(_hsl.withHue(v)),
                [
                  for (var h = 0; h <= 360; h += 60)
                    HSLColor.fromAHSL(1, h.toDouble(), 0.6, 0.45).toColor(),
                ],
              ),
              slider(
                l.settingsUiSaturation,
                _hsl.saturation * 100,
                100,
                (v) => _set(_hsl.withSaturation(v / 100)),
                [
                  _hsl.withSaturation(0).toColor(),
                  _hsl.withSaturation(1).toColor(),
                ],
              ),
              slider(
                l.settingsUiLightness,
                _hsl.lightness * 100,
                100,
                (v) => _set(_hsl.withLightness(v / 100)),
                [
                  _hsl.withLightness(0).toColor(),
                  _hsl.withLightness(0.5).toColor(),
                  _hsl.withLightness(1).toColor(),
                ],
              ),
              const SizedBox(height: Space.xs),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _color,
                      borderRadius: BorderRadius.circular(Radii.md),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('color-hex'),
                      controller: _hex,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp('[#0-9a-fA-F]'),
                        ),
                        LengthLimitingTextInputFormatter(7),
                      ],
                      decoration: InputDecoration(
                        labelText: l.settingsUiHex,
                        errorText: _hexError,
                      ),
                      onChanged: (t) {
                        final c = parseHexColor(t);
                        if (c == null) {
                          setState(() => _hexError = l.settingsUiInvalidHex);
                        } else {
                          _set(HSLColor.fromColor(c), updateHex: false);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          onPressed: _hexError != null
              ? null
              : () => Navigator.of(context).pop(_color),
          child: Text(l.commonSave),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final on = ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? context.colors.surfaceContainerLowest
        : context.colors.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: Space.minTouch,
            height: Space.minTouch,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? context.colors.onSurface
                    : context.colors.outlineVariant,
                width: selected ? 3 : 1,
              ),
            ),
            child: selected ? Icon(Icons.check, color: on, size: 20) : null,
          ),
        ),
      ),
    );
  }
}

String accentLabel(AppLocalizations l, AccentScheme a) => switch (a) {
  AccentScheme.spruce => l.setOptSpruce,
  AccentScheme.blue => l.setOptBlue,
  AccentScheme.violet => l.setOptViolet,
  AccentScheme.amber => l.setOptAmber,
  AccentScheme.rose => l.setOptRose,
  AccentScheme.slate => l.setOptSlate,
  AccentScheme.custom => l.setOptCustom,
};
