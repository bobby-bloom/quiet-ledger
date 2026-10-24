import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/core/calendar/budget_period.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/budgets/data/budget_period_provider.dart';

/// Computes the period containing a date: the budget period or the
/// calendar month, per Settings › Dashboard › period.
final dashboardPeriodOfProvider = Provider<DateRange Function(DateTime)>((ref) {
  final mode = ref.watch(
    settingsProvider.select((s) => s.get(DashboardSettings.period)),
  );
  if (mode == DashboardPeriod.budgetPeriod) {
    return ref.watch(budgetPeriodsProvider).periodOf;
  }
  return (d) =>
      DateRange(DateTime(d.year, d.month), DateTime(d.year, d.month + 1));
});

/// The period shown on the dashboard (Settings › Dashboard › period),
/// steppable with previous/next.
final dashboardPeriodProvider =
    NotifierProvider<DashboardPeriodNotifier, DateRange>(
      DashboardPeriodNotifier.new,
    );

class DashboardPeriodNotifier extends Notifier<DateRange> {
  @override
  DateRange build() {
    ref.watch(dashboardPeriodOfProvider);
    return _periodOf(DateTime.now());
  }

  DateRange _periodOf(DateTime d) => ref.read(dashboardPeriodOfProvider)(d);

  void previous() => state = _periodOf(
    DateTime(state.start.year, state.start.month, state.start.day - 1),
  );

  void next() => state = _periodOf(state.end);

  void today() => state = _periodOf(DateTime.now());
}
