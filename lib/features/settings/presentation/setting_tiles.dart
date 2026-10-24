import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/breakpoints.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/app/ui/pickers.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/ledger/lookups.dart';
import 'package:personal_finance/core/money/money.dart';
import 'package:personal_finance/core/platform/capabilities.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/setting_def.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/recurring/presentation/rule_picker.dart';
import 'package:personal_finance/features/settings/presentation/color_picker.dart';
import 'package:personal_finance/features/settings/presentation/setting_access.dart';
import 'package:personal_finance/features/settings/presentation/settings_catalog.dart';
import 'package:personal_finance/features/settings/presentation/tag_picker.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

// --------------------------------------------------------------- layout ----

/// Card with hairline-separated rows (design: Settings · Budgets card).
class SettingsGroupCard extends StatelessWidget {
  const SettingsGroupCard({
    required this.children,
    super.key,
    this.title,
    this.action,
  });

  final String? title;
  final Widget? action;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final hairline = context.colors.surfaceContainer;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0 || title != null) {
        rows.add(
          Divider(
            height: 1,
            indent: Space.md,
            endIndent: Space.md,
            color: hairline,
          ),
        );
      }
      rows.add(children[i]);
    }
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: Space.sm,
        vertical: Space.xxs,
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.only(bottom: Space.xxs + 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(left: Space.md, right: Space.xs),
                child: SizedBox(
                  height: 52,
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            title!,
                            style: context.text.titleSmall?.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      ?action,
                    ],
                  ),
                ),
              ),
            ...rows,
          ],
        ),
      ),
    );
  }
}

/// One setting row: title and optional subtitle on the left, a control on
/// the right, optional content below (segmented button, slider, list) and
/// an inline error.
class SettingRow extends StatelessWidget {
  const SettingRow({
    required this.title,
    super.key,
    this.subtitle,
    this.trailing,
    this.below,
    this.onTap,
    this.error,
    this.leading,
    this.titleColor,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? below;
  final VoidCallback? onTap;
  final String? error;
  final Widget? leading;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.md,
        vertical: Space.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: subtitle == null ? 36 : 44),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: Space.sm),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: context.text.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty)
                        Text(
                          subtitle!,
                          style: context.text.labelMedium?.copyWith(
                            fontWeight: FontWeight.w400,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: Space.sm),
                  trailing!,
                ],
              ],
            ),
          ),
          if (below != null) ...[const SizedBox(height: Space.xs), below!],
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: Space.xxs),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  error!,
                  style: context.text.labelMedium?.copyWith(color: cs.error),
                ),
              ),
            ),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}

/// Briefly tints its child (used when the search jumps to a setting).
class SettingHighlight extends StatefulWidget {
  const SettingHighlight({
    required this.active,
    required this.child,
    super.key,
  });

  final bool active;
  final Widget child;

  @override
  State<SettingHighlight> createState() => _SettingHighlightState();
}

class _SettingHighlightState extends State<SettingHighlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.forward(from: 0);
  }

  @override
  void didUpdateWidget(SettingHighlight old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = context.colors.primaryContainer;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.isAnimating || _c.value < 1 ? _c.value : 1.0;
        final a = widget.active && _c.isAnimating
            ? (t < 0.6 ? 0.9 : 0.9 * (1 - (t - 0.6) / 0.4))
            : 0.0;
        return ColoredBox(
          color: base.withValues(alpha: a.clamp(0, 1)),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ------------------------------------------------------------- dispatch ----

/// Renders [def] with the editor its [SettingDef.editor] asks for.
class SettingTile extends ConsumerWidget {
  const SettingTile(this.def, {super.key});

  final SettingDef<Object?> def;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (def.editor) {
      SwitchEditor() => _SwitchTile(def),
      final ChoiceEditor e => _ChoiceTile(def, e),
      final IntEditor e => _IntTile(def, e),
      final MoneyEditor e => _MoneyTile(def, e),
      final PercentBpEditor e => _PercentTile(def, e),
      final TextEditor e => _TextTile(def, e),
      ColorEditor() => _ColorTile(def),
      TimeOfDayEditor() => _TimeTile(def),
      final OrderedListEditor e => OrderedListTile(def: def, editor: e),
      final CustomEditor e => _CustomTile(def, e),
    };
  }
}

/// Validates and writes; returns a localised error or null.
Future<String?> _write(
  WidgetRef ref,
  AppLocalizations l,
  SettingDef<Object?> def,
  Object? json,
) async {
  final err = validateSettingJson(l, def, json);
  if (err != null) return err;
  try {
    await writeSettingJson(ref, def, json);
    return null;
    // The controller throws ArgumentError when its own validation fails.
    // ignore: avoid_catching_errors
  } on ArgumentError {
    return l.settingsUiInvalidValue;
  }
}

String? _desc(AppLocalizations l, SettingDef<Object?> def) =>
    def.description?.call(l);

// --------------------------------------------------------------- switch ----

class _SwitchTile extends ConsumerWidget {
  const _SwitchTile(this.def);

  final SettingDef<Object?> def;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final v = ref.watch(settingsProvider.select((s) => currentJson(s, def)));
    final on = v == true;
    final label = def.label(l);
    return MergeSemantics(
      child: SettingRow(
        title: label,
        subtitle: _desc(l, def),
        onTap: () => _write(ref, l, def, !on),
        trailing: Switch(value: on, onChanged: (x) => _write(ref, l, def, x)),
      ),
    );
  }
}

// --------------------------------------------------------------- choice ----

class _ChoiceTile extends ConsumerWidget {
  const _ChoiceTile(this.def, this.editor);

  final SettingDef<Object?> def;
  final ChoiceEditor editor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final caps = ref.watch(platformCapabilitiesProvider);
    final current = ref.watch(
      settingsProvider.select((s) => currentJson(s, def)),
    );
    final values = visibleChoiceValues(def, editor, caps);
    final labels = {for (final v in values) v: editor.labels(l, v)};
    final title = def.label(l);
    final segmented =
        values.length <= 3 && labels.values.every((t) => t.length <= 14);
    if (segmented && values.contains(current)) {
      return SettingRow(
        title: title,
        subtitle: _desc(l, def),
        below: SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              for (final v in values)
                ButtonSegment(value: v, label: Text(labels[v]!)),
            ],
            selected: {current! as String},
            onSelectionChanged: (s) => _write(ref, l, def, s.first),
          ),
        ),
      );
    }
    final currentLabel = current is String && values.contains(current)
        ? labels[current]!
        : '$current';
    return SettingRow(
      title: title,
      subtitle: _desc(l, def),
      onTap: () async {
        final picked = await showChoicePicker(
          context,
          title: title,
          values: values,
          labels: labels,
          selected: current is String ? current : null,
        );
        if (picked != null) await _write(ref, l, def, picked);
      },
      trailing: _ValueChip(label: currentLabel),
    );
  }
}

/// Select-style trailing value with a chevron (design: field · select).
class _ValueChip extends StatelessWidget {
  const _ValueChip({required this.label, this.icon = Icons.expand_more});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220, minHeight: 40),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: cs.outline),
          borderRadius: BorderRadius.circular(Radii.sm),
          color: cs.surfaceContainerLowest,
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: Space.sm, right: Space.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: Space.xxs),
              Icon(icon, size: 18, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Radio list in a bottom sheet (compact) or dialog. Returns the picked
/// value or null when dismissed.
Future<String?> showChoicePicker(
  BuildContext context, {
  required String title,
  required List<String> values,
  required Map<String, String> labels,
  String? selected,
}) {
  Widget list(BuildContext ctx) => RadioGroup<String>(
    groupValue: selected,
    onChanged: (v) => Navigator.of(ctx).pop(v),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final v in values)
          RadioListTile<String>(value: v, title: Text(labels[v] ?? v)),
      ],
    ),
  );

  if (WindowSize.of(context).isCompact) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.lg,
                  Space.xs,
                  Space.lg,
                  Space.xs,
                ),
                child: Text(title, style: ctx.text.titleMedium),
              ),
              list(ctx),
              const SizedBox(height: Space.xs),
            ],
          ),
        ),
      ),
    );
  }
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      contentPadding: const EdgeInsets.symmetric(vertical: Space.sm),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(child: list(ctx)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(ctx.l10n.commonCancel),
        ),
      ],
    ),
  );
}

// ------------------------------------------------------------------ int ----

/// Display text for special integer settings.
String intDisplay(
  AppLocalizations l,
  String locale,
  SettingDef<Object?> def,
  int v,
  IntEditor e,
) {
  if (def == BudgetSettings.startDay && v == 0) return l.settingsUiLastDay;
  if (def == GeneralSettings.fiscalYearStartMonth) {
    return DateFormat.MMMM(locale).format(DateTime(2000, v));
  }
  if (def == SecuritySettings.lockTimeout) return lockTimeoutLabel(l, v);
  final unit = e.unit?.call(l);
  if (unit == null) return '$v';
  return unit == '%' ? '$v %' : '$v $unit';
}

/// "Immediately", "30 s", "5 min", "1 h".
String lockTimeoutLabel(AppLocalizations l, int seconds) {
  if (seconds == 0) return l.securityTimeoutImmediately;
  if (seconds < 60) return l.securityTimeoutSeconds(seconds);
  if (seconds % 3600 == 0) return l.securityTimeoutHours(seconds ~/ 3600);
  if (seconds % 60 == 0) return l.securityTimeoutMinutes(seconds ~/ 60);
  return l.securityTimeoutSeconds(seconds);
}

class _IntTile extends ConsumerStatefulWidget {
  const _IntTile(this.def, this.editor);

  final SettingDef<Object?> def;
  final IntEditor editor;

  @override
  ConsumerState<_IntTile> createState() => _IntTileState();
}

class _IntTileState extends ConsumerState<_IntTile> {
  double? _drag;
  String? _error;

  IntEditor get e => widget.editor;

  bool get _slider {
    final steps = (e.max - e.min) ~/ e.step;
    return e.unit != null && steps <= 120;
  }

  Future<void> _set(int v) async {
    final err = await _write(ref, context.l10n, widget.def, v);
    if (mounted) setState(() => _error = err);
  }

  Future<void> _typeValue(int current) async {
    final l = context.l10n;
    final r = await showDialog<int>(
      context: context,
      builder: (_) => _IntInputDialog(
        title: widget.def.label(l),
        initial: current,
        min: e.min,
        max: e.max,
      ),
    );
    if (r != null) await _set(r);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locale = ref.watch(formatLocaleProvider);
    final stored = ref.watch(
      settingsProvider.select((s) => currentJson(s, widget.def)),
    );
    final value = stored is int ? stored : e.min;
    final shown = _drag?.round() ?? value;
    final text = intDisplay(l, locale, widget.def, shown, e);
    final title = widget.def.label(l);

    if (_slider) {
      return SettingRow(
        title: title,
        subtitle: _desc(l, widget.def),
        error: _error,
        trailing: Text(
          text,
          style: context.text.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: context.colors.primary,
          ),
        ),
        below: Slider(
          value: shown.clamp(e.min, e.max).toDouble(),
          min: e.min.toDouble(),
          max: e.max.toDouble(),
          divisions: (e.max - e.min) ~/ e.step,
          label: text,
          semanticFormatterCallback: (v) =>
              intDisplay(l, locale, widget.def, v.round(), e),
          onChanged: (v) => setState(() => _drag = v),
          onChangeEnd: (v) {
            setState(() => _drag = null);
            unawaited(_set(_snap(v.round())));
          },
        ),
      );
    }

    final cs = context.colors;
    return SettingRow(
      title: title,
      subtitle: _desc(l, widget.def),
      error: _error,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: l.settingsUiDecrease,
            onPressed: value - e.step >= e.min
                ? () => _set(value - e.step)
                : null,
            icon: const Icon(Icons.remove),
          ),
          Semantics(
            button: true,
            label: '$title: $text',
            hint: l.settingsUiTapToType,
            excludeSemantics: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.sm),
              onTap: () => _typeValue(value),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: 56,
                  minHeight: Space.minTouch,
                ),
                child: Center(
                  child: Text(
                    text,
                    style: context.text.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: l.settingsUiIncrease,
            onPressed: value + e.step <= e.max
                ? () => _set(value + e.step)
                : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  int _snap(int v) {
    final k = ((v - e.min) / e.step).round();
    return (e.min + k * e.step).clamp(e.min, e.max);
  }
}

class _IntInputDialog extends StatefulWidget {
  const _IntInputDialog({
    required this.title,
    required this.initial,
    required this.min,
    required this.max,
  });

  final String title;
  final int initial;
  final int min;
  final int max;

  @override
  State<_IntInputDialog> createState() => _IntInputDialogState();
}

class _IntInputDialogState extends State<_IntInputDialog> {
  late final _c = TextEditingController(text: '${widget.initial}');
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() {
    final l = context.l10n;
    final v = int.tryParse(_c.text.trim().replaceAll('−', '-'));
    if (v == null) {
      setState(() => _error = l.settingsUiInvalidNumber);
    } else if (v < widget.min || v > widget.max) {
      setState(() => _error = l.settingsUiOutOfRange(widget.min, widget.max));
    } else {
      Navigator.of(context).pop(v);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _c,
        autofocus: true,
        keyboardType: TextInputType.numberWithOptions(signed: widget.min < 0),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9-]'))],
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          errorText: _error,
          helperText: l.settingsUiOutOfRange(widget.min, widget.max),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.commonCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l.commonSave)),
      ],
    );
  }
}

// ---------------------------------------------------------------- money ----

/// Debounced writes for text-like editors.
mixin _Debounced<W extends ConsumerStatefulWidget> on ConsumerState<W> {
  Timer? _timer;
  Future<void> Function()? _pending;

  void debounce(Future<void> Function() action) {
    _timer?.cancel();
    _pending = action;
    _timer = Timer(const Duration(milliseconds: 500), flush);
  }

  void flush() {
    _timer?.cancel();
    final p = _pending;
    _pending = null;
    if (p != null) unawaited(p());
  }

  @override
  void dispose() {
    flush();
    super.dispose();
  }
}

class _MoneyTile extends ConsumerStatefulWidget {
  const _MoneyTile(this.def, this.editor);

  final SettingDef<Object?> def;
  final MoneyEditor editor;

  @override
  ConsumerState<_MoneyTile> createState() => _MoneyTileState();
}

class _MoneyTileState extends ConsumerState<_MoneyTile>
    with _Debounced<_MoneyTile> {
  String? _error;
  late final AppLocalizations _l = context.l10n;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = ref.read(settingsProvider);
    final v = currentJson(s, widget.def);
    final fmt = ref.watch(moneyFormatterProvider);
    return SettingRow(
      title: widget.def.label(l),
      subtitle:
          _desc(l, widget.def) ??
          (v is int ? fmt.format(Money(v)) : l.settingsUiNotSet),
      error: _error,
      trailing: SizedBox(
        width: 150,
        child: Semantics(
          label: widget.def.label(l),
          child: MoneyField(
            key: ValueKey('money-${widget.def.key}'),
            initialMinor: v is int ? v : null,
            onChanged: (minor) {
              if (minor == null && !widget.editor.allowNull) {
                setState(() => _error = l.settingsUiInvalidNumber);
                return;
              }
              setState(() => _error = null);
              debounce(() async {
                final err = await _write(ref, _l, widget.def, minor);
                if (mounted) setState(() => _error = err);
              });
            },
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- percent ----

class _PercentTile extends ConsumerStatefulWidget {
  const _PercentTile(this.def, this.editor);

  final SettingDef<Object?> def;
  final PercentBpEditor editor;

  @override
  ConsumerState<_PercentTile> createState() => _PercentTileState();
}

class _PercentTileState extends ConsumerState<_PercentTile>
    with _Debounced<_PercentTile> {
  late final TextEditingController _c;
  String? _error;
  late final AppLocalizations _l = context.l10n;

  String get _decimal {
    final locale = ref.read(formatLocaleProvider);
    return NumberFormat.decimalPattern(locale).symbols.DECIMAL_SEP;
  }

  @override
  void initState() {
    super.initState();
    final v = currentJson(ref.read(settingsProvider), widget.def);
    _c = TextEditingController(
      text: v is int ? formatBp(v, decimal: _decimal).replaceAll(' %', '') : '',
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _changed(String text) {
    final l = context.l10n;
    final bp = parsePercentToBp(text);
    if (bp == null) {
      setState(() => _error = l.settingsUiInvalidNumber);
      return;
    }
    final err = validateSettingJson(l, widget.def, bp);
    setState(() => _error = err);
    if (err != null) return;
    debounce(() async {
      final e = await _write(ref, _l, widget.def, bp);
      if (mounted && e != null) setState(() => _error = e);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final e = widget.editor;
    return SettingRow(
      title: widget.def.label(l),
      subtitle:
          _desc(l, widget.def) ??
          l.settingsUiOutOfRangeText(
            formatBp(e.min, decimal: _decimal),
            formatBp(e.max, decimal: _decimal),
          ),
      error: _error,
      trailing: SizedBox(
        width: 110,
        child: TextField(
          key: ValueKey('percent-${widget.def.key}'),
          controller: _c,
          textAlign: TextAlign.end,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-−]')),
          ],
          decoration: InputDecoration(
            suffixText: '%',
            isDense: true,
            hintText: '0',
            errorText: _error == null ? null : '',
            errorStyle: const TextStyle(height: 0, fontSize: 0),
          ),
          onChanged: _changed,
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- text ----

class _TextTile extends ConsumerStatefulWidget {
  const _TextTile(this.def, this.editor);

  final SettingDef<Object?> def;
  final TextEditor editor;

  @override
  ConsumerState<_TextTile> createState() => _TextTileState();
}

class _TextTileState extends ConsumerState<_TextTile>
    with _Debounced<_TextTile> {
  late final TextEditingController _c;
  String? _error;
  late final AppLocalizations _l = context.l10n;

  @override
  void initState() {
    super.initState();
    final v = currentJson(ref.read(settingsProvider), widget.def);
    _c = TextEditingController(text: v is String ? v : '');
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SettingRow(
      title: widget.def.label(l),
      subtitle: _desc(l, widget.def),
      below: TextField(
        key: ValueKey('text-${widget.def.key}'),
        controller: _c,
        decoration: InputDecoration(
          hintText: widget.editor.hint,
          errorText: _error,
        ),
        onChanged: (t) {
          final err = validateSettingJson(l, widget.def, t);
          setState(() => _error = err);
          if (err != null) return;
          debounce(() async {
            final e = await _write(ref, _l, widget.def, t);
            if (mounted && e != null) setState(() => _error = e);
          });
        },
      ),
    );
  }
}

// ---------------------------------------------------------------- color ----

class _ColorTile extends ConsumerWidget {
  const _ColorTile(this.def);

  final SettingDef<Object?> def;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final v = ref.watch(settingsProvider.select((s) => currentJson(s, def)));
    final color = Color(v is int ? v : 0xFF000000);
    final title = def.label(l);
    return SettingRow(
      title: title,
      subtitle: _desc(l, def) ?? colorToHex(color),
      onTap: () async {
        final picked = await showAccentColorPicker(
          context,
          initial: color,
          title: title,
        );
        if (picked != null) await _write(ref, l, def, picked.toARGB32());
      },
      trailing: Semantics(
        label: colorToHex(color),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: context.colors.outlineVariant),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- time ----

class _TimeTile extends ConsumerWidget {
  const _TimeTile(this.def);

  final SettingDef<Object?> def;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final v = ref.watch(settingsProvider.select((s) => currentJson(s, def)));
    final minutes = v is int ? v : 0;
    final time = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    final text = MaterialLocalizations.of(context).formatTimeOfDay(
      time,
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    return SettingRow(
      title: def.label(l),
      subtitle: _desc(l, def),
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
        );
        if (picked != null) {
          await _write(ref, l, def, picked.hour * 60 + picked.minute);
        }
      },
      trailing: _ValueChip(label: text, icon: Icons.schedule),
    );
  }
}

// --------------------------------------------------------- ordered list ----

/// Checklist (reorderable when [OrderedListEditor.reorderable]). The stored
/// value is the checked items in display order.
class OrderedListTile extends ConsumerWidget {
  const OrderedListTile({
    required this.def,
    required this.editor,
    super.key,
    this.canToggle,
    this.footer,
    this.write,
  });

  final SettingDef<Object?> def;
  final OrderedListEditor editor;

  /// Whether a value may be (un)checked now; default always.
  final bool Function(List<String> checked, String value)? canToggle;
  final Widget? footer;

  /// Custom writer (e.g. with constraints); default stores the list.
  final Future<void> Function(List<String> checked)? write;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final v = ref.watch(settingsProvider.select((s) => currentJson(s, def)));
    final checked = v is List ? v.whereType<String>().toList() : <String>[];
    final shownChecked = checked.where(editor.values.contains).toList();
    final unchecked = editor.values
        .where((x) => !shownChecked.contains(x))
        .toList();
    final ordered = editor.reorderable
        ? [...shownChecked, ...unchecked]
        : editor.values;

    Future<void> store(List<String> list) async {
      if (write != null) {
        await write!(list);
        return;
      }
      await writeSettingJson(ref, def, list);
    }

    Future<void> toggle(String x) async {
      if (canToggle != null && !canToggle!(shownChecked, x)) return;
      if (shownChecked.contains(x)) {
        await store([...shownChecked]..remove(x));
      } else if (editor.reorderable) {
        await store([...shownChecked, x]);
      } else {
        await store([
          for (final e in editor.values)
            if (e == x || shownChecked.contains(e)) e,
        ]);
      }
    }

    Future<void> move(int from, int to) async {
      final list = [...ordered];
      final item = list.removeAt(from);
      list.insert(to.clamp(0, list.length), item);
      await store(list.where(shownChecked.contains).toList());
    }

    Widget item(int i, String x) {
      final on = shownChecked.contains(x);
      final allowed = canToggle?.call(shownChecked, x) ?? true;
      final label = editor.labels(l, x);
      return Semantics(
        key: ValueKey('ol-${def.key}-$x'),
        customSemanticsActions: editor.reorderable
            ? {
                if (i > 0)
                  CustomSemanticsAction(label: l.settingsUiMoveUp): () =>
                      move(i, i - 1),
                if (i < ordered.length - 1)
                  CustomSemanticsAction(label: l.settingsUiMoveDown): () =>
                      move(i, i + 1),
              }
            : null,
        child: Material(
          type: MaterialType.transparency,
          child: CheckboxListTile(
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.only(left: Space.xs),
            value: on,
            onChanged: allowed ? (_) => toggle(x) : null,
            title: Text(label),
            secondary: editor.reorderable
                ? ReorderableDragStartListener(
                    index: i,
                    child: Tooltip(
                      message: l.settingsUiDragHandle,
                      child: const Padding(
                        padding: EdgeInsets.all(Space.sm),
                        child: Icon(Icons.drag_handle),
                      ),
                    ),
                  )
                : null,
          ),
        ),
      );
    }

    final list = editor.reorderable
        ? ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderItem: move,
            children: [
              for (var i = 0; i < ordered.length; i++) item(i, ordered[i]),
            ],
          )
        : Column(
            children: [
              for (var i = 0; i < ordered.length; i++) item(i, ordered[i]),
            ],
          );
    return SettingRow(
      title: def.label(l),
      subtitle: _desc(l, def),
      below: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [list, ?footer],
      ),
    );
  }
}

// --------------------------------------------------------------- custom ----

/// Name of a recurring rule (for the salary-rule subtitle).
final _recurringRuleNameProvider = FutureProvider.family<String?, String>((
  ref,
  id,
) async {
  final db = ref.watch(databaseProvider);
  final row = await (db.select(
    db.recurringRules,
  )..where((r) => r.id.equals(id) & r.deletedAt.isNull())).getSingleOrNull();
  return row?.name;
});

String _names(AppLocalizations l, List<String> ids, Map<String, String> m) {
  final names = [for (final id in ids) ?m[id]];
  if (names.isEmpty) return l.commonNone;
  if (names.length <= 2) return names.join(', ');
  return '${names.take(2).join(', ')} ${l.settingsUiAndMore(names.length - 2)}';
}

class _CustomTile extends ConsumerWidget {
  const _CustomTile(this.def, this.editor);

  final SettingDef<Object?> def;
  final CustomEditor editor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final v = ref.watch(settingsProvider.select((s) => currentJson(s, def)));
    final ids = v is List ? v.whereType<String>().toList() : const <String>[];
    final id = v is String && v.isNotEmpty ? v : null;
    final route = editor.route;

    String? subtitle;
    VoidCallback onTap;
    Widget? clear;
    switch (route) {
      case '/accounts/pick':
        final m = ref.watch(accountMapProvider);
        subtitle = id == null ? l.settingsUiNotSet : (m[id]?.name ?? '—');
        onTap = () async {
          final r = await showAccountPicker(context, selectedId: id);
          if (r != null) await _write(ref, l, def, r);
        };
        if (id != null) {
          clear = IconButton(
            tooltip: l.settingsUiClear,
            icon: const Icon(Icons.close),
            onPressed: () => _write(ref, l, def, null),
          );
        }
      case '/accounts/pick-multi':
        final m = ref.watch(accountMapProvider);
        subtitle = _names(l, ids, {
          for (final e in m.entries) e.key: e.value.name,
        });
        onTap = () async {
          final r = await showAccountMultiPicker(
            context,
            selected: ids.toSet(),
          );
          if (r != null) await _write(ref, l, def, r.toList());
        };
      case '/more/categories/pick-multi':
        final m = ref.watch(categoryMapProvider);
        subtitle = _names(l, ids, {
          for (final e in m.entries) e.key: e.value.name,
        });
        onTap = () async {
          final r = await showCategoryMultiPicker(
            context,
            selected: ids.toSet(),
          );
          if (r != null) await _write(ref, l, def, r.toList());
        };
      case '/more/tags/pick-multi':
        final m = ref.watch(tagMapProvider);
        subtitle = _names(l, ids, {
          for (final e in m.entries) e.key: e.value.name,
        });
        onTap = () async {
          final r = await showTagMultiPicker(context, selected: ids.toSet());
          if (r != null) await _write(ref, l, def, r.toList());
        };
      case '/plan/recurring/pick':
        subtitle = id == null
            ? l.settingsUiNotSet
            : (ref.watch(_recurringRuleNameProvider(id)).value ?? '—');
        onTap = () async {
          final r = await showRecurringRulePicker(
            context,
            incomeOnly: true,
            allowNone: true,
            selectedId: id,
          );
          if (r == null) return;
          await _write(ref, l, def, r.isEmpty ? null : r);
        };
      default:
        subtitle = _desc(l, def);
        onTap = () => context.push(route);
    }

    return SettingRow(
      title: def.label(l),
      subtitle: subtitle,
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [?clear, const Icon(Icons.chevron_right)],
      ),
    );
  }
}
