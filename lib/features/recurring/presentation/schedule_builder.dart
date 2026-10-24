import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/features/recurring/domain/schedule.dart';
import 'package:personal_finance/features/recurring/domain/schedule_text.dart';

/// Presets shown in the "Repeats" menu.
enum SchedulePreset {
  monthly,
  lastDay,
  lastBusinessDay,
  weekly,
  quarterly,
  yearly,
  daily,
  custom,
}

SchedulePreset presetOf(ScheduleSpec s) => switch (s.kind) {
  ScheduleKind.monthly =>
    s.interval == 3 ? SchedulePreset.quarterly : SchedulePreset.monthly,
  ScheduleKind.lastDay => SchedulePreset.lastDay,
  ScheduleKind.lastBusinessDay => SchedulePreset.lastBusinessDay,
  ScheduleKind.weekly => SchedulePreset.weekly,
  ScheduleKind.yearly => SchedulePreset.yearly,
  ScheduleKind.daily => SchedulePreset.daily,
  ScheduleKind.custom => SchedulePreset.custom,
};

/// Friendly editor for a recurrence schedule producing an RRULE.
class ScheduleBuilder extends ConsumerStatefulWidget {
  const ScheduleBuilder({
    required this.value,
    required this.onChanged,
    required this.start,
    super.key,
  });

  final ScheduleSpec value;
  final ValueChanged<ScheduleSpec> onChanged;

  /// Rule start date (defaults for day/weekday/month when switching).
  final DateTime start;

  @override
  ConsumerState<ScheduleBuilder> createState() => _ScheduleBuilderState();
}

class _ScheduleBuilderState extends ConsumerState<ScheduleBuilder> {
  late final TextEditingController _custom = TextEditingController(
    text: widget.value.kind == ScheduleKind.custom
        ? widget.value.custom
        : widget.value.toRRule(),
  );

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _setPreset(SchedulePreset p) {
    final v = widget.value;
    final s = widget.start;
    final day = v.kind == ScheduleKind.monthly || v.kind == ScheduleKind.yearly
        ? v.monthDay
        : s.day;
    final next = switch (p) {
      SchedulePreset.monthly => ScheduleSpec(monthDay: day),
      SchedulePreset.quarterly => ScheduleSpec(monthDay: day, interval: 3),
      SchedulePreset.lastDay => const ScheduleSpec(kind: ScheduleKind.lastDay),
      SchedulePreset.lastBusinessDay => const ScheduleSpec(
        kind: ScheduleKind.lastBusinessDay,
      ),
      SchedulePreset.weekly => ScheduleSpec(
        kind: ScheduleKind.weekly,
        weekdays: v.kind == ScheduleKind.weekly ? v.weekdays : {s.weekday},
      ),
      SchedulePreset.yearly => ScheduleSpec(
        kind: ScheduleKind.yearly,
        month: s.month,
        monthDay: s.day,
      ),
      SchedulePreset.daily => const ScheduleSpec(kind: ScheduleKind.daily),
      SchedulePreset.custom => ScheduleSpec(
        kind: ScheduleKind.custom,
        custom: v.toRRule(),
      ),
    };
    if (p == SchedulePreset.custom) _custom.text = next.custom;
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = widget.value;
    final preset = presetOf(v);
    final locale = ref.watch(formatLocaleProvider);
    final lang = ref.watch(languageCodeProvider);
    final firstDay = ref.watch(firstDayOfWeekProvider);
    String presetLabel(SchedulePreset p) => switch (p) {
      SchedulePreset.monthly => l.recurringPresetMonthly,
      SchedulePreset.lastDay => l.recurringPresetLastDay,
      SchedulePreset.lastBusinessDay => l.recurringPresetLastBusinessDay,
      SchedulePreset.weekly => l.recurringPresetWeekly,
      SchedulePreset.quarterly => l.recurringPresetQuarterly,
      SchedulePreset.yearly => l.recurringPresetYearly,
      SchedulePreset.daily => l.recurringPresetDaily,
      SchedulePreset.custom => l.recurringPresetCustom,
    };

    final controls = <Widget>[];
    Widget dayDropdown() => DropdownButtonFormField<int>(
      key: ValueKey('monthday-${v.monthDay}'),
      initialValue: v.monthDay.clamp(1, 31),
      decoration: InputDecoration(labelText: l.recurringDayOfMonth),
      items: [
        for (var d = 1; d <= 31; d++)
          DropdownMenuItem(value: d, child: Text('$d')),
      ],
      onChanged: (d) => widget.onChanged(v.copyWith(monthDay: d)),
    );

    switch (preset) {
      case SchedulePreset.monthly:
        controls
          ..add(dayDropdown())
          ..add(
            _IntervalField(
              label: l.recurringEveryNMonths,
              value: v.interval,
              onChanged: (n) => widget.onChanged(v.copyWith(interval: n)),
            ),
          );
        if (v.monthDay > 28) {
          controls.add(
            Text(
              l.recurringMonthEndHint,
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          );
        }
      case SchedulePreset.quarterly:
        controls.add(dayDropdown());
      case SchedulePreset.lastDay:
      case SchedulePreset.lastBusinessDay:
        controls.add(
          _IntervalField(
            label: l.recurringEveryNMonths,
            value: v.interval,
            onChanged: (n) => widget.onChanged(v.copyWith(interval: n)),
          ),
        );
      case SchedulePreset.weekly:
        final order = [for (var i = 0; i < 7; i++) (firstDay - 1 + i) % 7 + 1];
        controls
          ..add(
            Wrap(
              spacing: Space.xxs,
              runSpacing: Space.xxs,
              children: [
                for (final d in order)
                  FilterChip(
                    label: Text(
                      DateFormat.E(locale).format(DateTime(2024, 1, d)),
                    ),
                    selected: v.weekdays.contains(d),
                    onSelected: (sel) {
                      final next = {...v.weekdays};
                      sel ? next.add(d) : next.remove(d);
                      if (next.isEmpty) return;
                      widget.onChanged(v.copyWith(weekdays: next));
                    },
                  ),
              ],
            ),
          )
          ..add(
            _IntervalField(
              label: l.recurringEveryNWeeks,
              value: v.interval,
              onChanged: (n) => widget.onChanged(v.copyWith(interval: n)),
            ),
          );
      case SchedulePreset.yearly:
        final maxDay = DateTime(2024, v.month + 1, 0).day;
        controls
          ..add(
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<int>(
                    key: ValueKey('month-${v.month}'),
                    initialValue: v.month,
                    decoration: InputDecoration(labelText: l.recurringMonth),
                    items: [
                      for (var m = 1; m <= 12; m++)
                        DropdownMenuItem(
                          value: m,
                          child: Text(
                            DateFormat.MMMM(locale).format(DateTime(2024, m)),
                          ),
                        ),
                    ],
                    onChanged: (m) => widget.onChanged(
                      v.copyWith(
                        month: m,
                        monthDay: v.monthDay.clamp(
                          1,
                          DateTime(2024, (m ?? 1) + 1, 0).day,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<int>(
                    key: ValueKey('yearday-${v.month}-${v.monthDay}'),
                    initialValue: v.monthDay.clamp(1, maxDay),
                    decoration: InputDecoration(labelText: l.recurringDay),
                    items: [
                      for (var d = 1; d <= maxDay; d++)
                        DropdownMenuItem(value: d, child: Text('$d')),
                    ],
                    onChanged: (d) => widget.onChanged(v.copyWith(monthDay: d)),
                  ),
                ),
              ],
            ),
          )
          ..add(
            _IntervalField(
              label: l.recurringEveryNYears,
              value: v.interval,
              onChanged: (n) => widget.onChanged(v.copyWith(interval: n)),
            ),
          );
      case SchedulePreset.daily:
        controls.add(
          _IntervalField(
            label: l.recurringEveryNDays,
            value: v.interval,
            onChanged: (n) => widget.onChanged(v.copyWith(interval: n)),
          ),
        );
      case SchedulePreset.custom:
        controls.add(
          TextFormField(
            controller: _custom,
            decoration: InputDecoration(
              labelText: l.recurringRRule,
              helperText: l.recurringRRuleHelp,
              helperMaxLines: 2,
            ),
            style: context.mono,
            autocorrect: false,
            validator: (_) =>
                isValidRRule(v.toRRule()) ? null : l.recurringRRuleInvalid,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onChanged: (t) => widget.onChanged(
              ScheduleSpec(kind: ScheduleKind.custom, custom: t),
            ),
          ),
        );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<SchedulePreset>(
          key: ValueKey(preset),
          initialValue: preset,
          decoration: InputDecoration(labelText: l.recurringRepeats),
          items: [
            for (final p in SchedulePreset.values)
              DropdownMenuItem(value: p, child: Text(presetLabel(p))),
          ],
          onChanged: (p) {
            if (p != null && p != preset) _setPreset(p);
          },
        ),
        for (final c in controls) ...[const SizedBox(height: Space.sm), c],
        const SizedBox(height: Space.xs),
        Row(
          children: [
            Icon(
              Icons.event_repeat_outlined,
              size: 16,
              color: context.colors.onSurfaceVariant,
            ),
            const SizedBox(width: Space.xxs),
            Expanded(
              child: Text(
                isValidRRule(v.toRRule())
                    ? describeSchedule(v.toRRule(), lang)
                    : l.recurringRRuleInvalid,
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// "Every n months" with − / + buttons.
class _IntervalField extends StatelessWidget {
  const _IntervalField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Row(
      children: [
        Expanded(child: Text(label, style: context.text.bodyLarge)),
        IconButton(
          tooltip: l.recurringDecrease,
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: value > 1 ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 32,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: context.text.titleMedium,
          ),
        ),
        IconButton(
          tooltip: l.recurringIncrease,
          icon: const Icon(Icons.add_circle_outline),
          onPressed: value < 99 ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}
