import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/core/calendar/budget_period.dart';

/// A short name for a budget period: the month ("October 2026"), quarter
/// ("Q4 2026") or year that contains most of its days (start days may be
/// shifted to business days or follow the salary); otherwise the range.
String periodTitle(DateRange p, String locale) {
  final days = p.days;
  final mid = DateTime(p.start.year, p.start.month, p.start.day + days ~/ 2);
  if (days >= 26 && days <= 33) return DateFormat.yMMMM(locale).format(mid);
  if (days >= 85 && days <= 96) {
    return 'Q${(mid.month - 1) ~/ 3 + 1} ${mid.year}';
  }
  if (days >= 358 && days <= 372) return DateFormat.y(locale).format(mid);
  return periodRange(p, locale);
}

/// "25 Sep – 24 Oct 2026".
String periodRange(DateRange p, String locale) {
  final last = p.last;
  final sameYear = p.start.year == last.year;
  final a = sameYear
      ? DateFormat.MMMd(locale).format(p.start)
      : DateFormat.yMMMd(locale).format(p.start);
  return '$a – ${DateFormat.yMMMd(locale).format(last)}';
}

/// Parses `yyyy-MM-dd` (route query parameters).
DateTime? parseIsoDate(String? s) {
  if (s == null || s.isEmpty) return null;
  final d = DateTime.tryParse(s);
  return d == null ? null : DateTime(d.year, d.month, d.day);
}

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Previous / next period navigation with the period title and range.
class PeriodSwitcher extends ConsumerWidget {
  const PeriodSwitcher({
    required this.period,
    required this.onPrevious,
    required this.onNext,
    super.key,
    this.onToday,
  });

  final DateRange period;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  /// Shown as "Today" when not null (i.e. not on the current period).
  final VoidCallback? onToday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final locale = ref.watch(formatLocaleProvider);
    final title = periodTitle(period, locale);
    final range = periodRange(period, locale);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.xxs),
      child: Row(
        children: [
          IconButton(
            tooltip: l.planPreviousPeriod,
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrevious,
          ),
          Expanded(
            child: Semantics(
              liveRegion: true,
              label: l.planPeriodSemantics(title, range),
              excludeSemantics: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: context.text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (title != range)
                    Text(
                      range,
                      style: context.text.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (onToday != null)
            TextButton(onPressed: onToday, child: Text(l.planToday)),
          IconButton(
            tooltip: l.planNextPeriod,
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

/// A label above a value (summary cards).
class Metric extends StatelessWidget {
  const Metric({
    required this.label,
    required this.value,
    super.key,
    this.alignEnd = false,
  });

  final String label;
  final Widget value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: context.text.labelMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        DefaultTextStyle.merge(
          style: context.text.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          child: value,
        ),
      ],
    );
  }
}

/// Muted section title inside lists.
class PlanSectionHeader extends StatelessWidget {
  const PlanSectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.listInset,
        Space.md,
        Space.xs,
        4,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: context.text.titleSmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// List and detail side by side on expanded screens. Without [detail]
/// (nothing opened) the list takes the whole width.
class ListDetail extends StatelessWidget {
  const ListDetail({
    required this.list,
    required this.detail,
    super.key,
    this.listWidth = 420,
  });

  final Widget list;
  final Widget? detail;
  final double listWidth;

  @override
  Widget build(BuildContext context) {
    final detail = this.detail;
    if (detail == null) return list;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: listWidth, child: list),
        VerticalDivider(width: 1, color: context.colors.outlineVariant),
        Expanded(child: detail),
      ],
    );
  }
}

/// The × that ends the header of a [ListDetail] detail pane and closes it.
class ClosePanelButton extends StatelessWidget {
  const ClosePanelButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.l10n.commonClose,
      icon: const Icon(Icons.close),
      onPressed: onPressed,
    );
  }
}

/// Constrains form/detail content to a readable width.
class ReadableWidth extends StatelessWidget {
  const ReadableWidth({required this.child, super.key, this.maxWidth = 720});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
