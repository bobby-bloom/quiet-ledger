import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/amount_text.dart';
import 'package:personal_finance/app/ui/breakpoints.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/features/plan/plan_providers.dart';
import 'package:personal_finance/features/plan/presentation/plan_widgets.dart';
import 'package:personal_finance/features/recurring/data/recurring_providers.dart';
import 'package:table_calendar/table_calendar.dart';

StartingDayOfWeek _startingDay(int weekday) => switch (weekday) {
  DateTime.sunday => StartingDayOfWeek.sunday,
  DateTime.saturday => StartingDayOfWeek.saturday,
  DateTime.tuesday => StartingDayOfWeek.tuesday,
  DateTime.wednesday => StartingDayOfWeek.wednesday,
  DateTime.thursday => StartingDayOfWeek.thursday,
  DateTime.friday => StartingDayOfWeek.friday,
  _ => StartingDayOfWeek.monday,
};

DateTime _local(DateTime d) => DateTime(d.year, d.month, d.day);

/// '/plan/calendar' — month view of recurring items with a day list.
class BillsCalendarScreen extends ConsumerStatefulWidget {
  const BillsCalendarScreen({super.key});

  @override
  ConsumerState<BillsCalendarScreen> createState() =>
      _BillsCalendarScreenState();
}

class _BillsCalendarScreenState extends ConsumerState<BillsCalendarScreen> {
  late DateTime _focused = ref.read(planTodayProvider);
  late DateTime _selected = _focused;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locale = ref.watch(formatLocaleProvider);
    final firstDay = ref.watch(firstDayOfWeekProvider);
    final today = ref.watch(planTodayProvider);
    final from = DateTime(_focused.year, _focused.month, 1 - 7);
    final to = DateTime(_focused.year, _focused.month + 1, 7);
    final data = ref.watch(calendarOccurrencesProvider((from, to)));
    final occurrences = data.value ?? const <UpcomingOccurrence>[];
    final byDay = <DateTime, List<UpcomingOccurrence>>{};
    for (final o in occurrences) {
      byDay.putIfAbsent(o.date, () => []).add(o);
    }
    var monthOut = 0;
    var monthIn = 0;
    for (final o in occurrences) {
      if (o.date.month != _focused.month || o.type == TxnType.transfer) {
        continue;
      }
      if (o.amountMinor < 0) {
        monthOut -= o.amountMinor;
      } else {
        monthIn += o.amountMinor;
      }
    }

    final calendar = TableCalendar<UpcomingOccurrence>(
      locale: locale,
      firstDay: DateTime(today.year - 5),
      lastDay: DateTime(today.year + 10, 12, 31),
      focusedDay: _focused,
      currentDay: today,
      startingDayOfWeek: _startingDay(firstDay),
      availableCalendarFormats: const {CalendarFormat.month: ''},
      availableGestures: AvailableGestures.horizontalSwipe,
      selectedDayPredicate: (d) => isSameDay(d, _selected),
      eventLoader: (d) => byDay[_local(d)] ?? const [],
      onDaySelected: (selected, focused) => setState(() {
        _selected = _local(selected);
        _focused = _local(focused);
      }),
      onPageChanged: (focused) => setState(() => _focused = _local(focused)),
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: context.text.titleMedium!.copyWith(
          fontWeight: FontWeight.w700,
        ),
        leftChevronIcon: Icon(
          Icons.chevron_left,
          semanticLabel: l.planPreviousPeriod,
        ),
        rightChevronIcon: Icon(
          Icons.chevron_right,
          semanticLabel: l.planNextPeriod,
        ),
      ),
      calendarStyle: CalendarStyle(
        todayDecoration: BoxDecoration(
          color: context.colors.secondaryContainer,
          shape: BoxShape.circle,
        ),
        todayTextStyle: TextStyle(color: context.colors.onSecondaryContainer),
        selectedDecoration: BoxDecoration(
          color: context.colors.primary,
          shape: BoxShape.circle,
        ),
        selectedTextStyle: TextStyle(color: context.colors.onPrimary),
        weekendTextStyle: TextStyle(color: context.colors.onSurfaceVariant),
        outsideTextStyle: TextStyle(color: context.colors.outline),
      ),
      calendarBuilders: CalendarBuilders<UpcomingOccurrence>(
        markerBuilder: (context, day, events) {
          if (events.isEmpty) return null;
          return Positioned(
            bottom: 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final e in events.take(3))
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: e.isPosted
                          ? context.colors.outline
                          : e.type == TxnType.income
                          ? context.finance.income
                          : e.type == TxnType.transfer
                          ? context.finance.transfer
                          : context.finance.expense,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );

    final dayItems = byDay[_selected] ?? const <UpcomingOccurrence>[];
    final dates = ref.watch(dateFormatsProvider);
    final dayList = ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        PlanSectionHeader(dates.dayHeader(_selected)),
        if (dayItems.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.listInset,
              vertical: Space.sm,
            ),
            child: Text(
              l.recurringNothingOnDay,
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
        for (final o in dayItems)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: Space.listInset,
            ),
            leading: Icon(
              o.isPosted
                  ? Icons.check_circle_outline
                  : o.isOverdue
                  ? Icons.error_outline
                  : Icons.schedule,
              color: o.isOverdue ? context.colors.error : null,
            ),
            title: Text(o.name),
            subtitle: Text(
              [
                o.account?.name ?? '',
                if (o.isPosted)
                  l.recurringPostedLabel
                else if (o.postingMode == PostingMode.autoPost)
                  l.recurringAutoPostShort
                else
                  l.recurringConfirmShort,
              ].where((s) => s.isNotEmpty).join(' · '),
            ),
            trailing: AmountText(o.amountMinor, type: o.type),
            onTap: () => context.push('/plan/recurring/${o.ruleId}'),
          ),
      ],
    );

    final summary = Padding(
      padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.xs),
      child: Row(
        children: [
          Expanded(
            child: Metric(
              label: l.recurringMonthOut,
              value: AmountText(-monthOut, type: TxnType.expense),
            ),
          ),
          Expanded(
            child: Metric(
              alignEnd: true,
              label: l.recurringMonthIn,
              value: AmountText(monthIn, type: TxnType.income),
            ),
          ),
        ],
      ),
    );

    final wide = !WindowSize.of(context).isCompact;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.planBillsCalendar),
        actions: [
          if (!isSameDay(_focused, today) || !isSameDay(_selected, today))
            TextButton(
              onPressed: () => setState(() {
                _focused = today;
                _selected = today;
              }),
              child: Text(l.planToday),
            ),
        ],
      ),
      body: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 440,
                  child: SingleChildScrollView(
                    child: Column(children: [calendar, summary]),
                  ),
                ),
                VerticalDivider(width: 1, color: context.colors.outlineVariant),
                Expanded(child: dayList),
              ],
            )
          : Column(
              children: [
                calendar,
                summary,
                const Divider(height: 1),
                Expanded(child: dayList),
              ],
            ),
    );
  }
}
