import 'dart:async';

import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/forecast/data/forecast_data_source.dart';
import 'package:personal_finance/features/forecast/domain/cashflow_engine.dart';
import 'package:personal_finance/features/forecast/domain/forecast_dates.dart';
import 'package:personal_finance/features/forecast/domain/forecast_models.dart';
import 'package:personal_finance/features/forecast/domain/forecast_pipeline.dart';
import 'package:personal_finance/features/forecast/domain/projection.dart';
import 'package:personal_finance/features/scenarios/data/scenario_repository.dart';
import 'package:personal_finance/features/scenarios/domain/scenario.dart';

// ------------------------------------------------------------ plumbing ---

/// "Today" for the forecast (local midnight). Overridable in tests.
final forecastTodayProvider = Provider<DateTime>(
  (ref) => dayOf(DateTime.now()),
);

final forecastDataSourceProvider = Provider<ForecastDataSource>(
  (ref) => ForecastDataSource(ref.watch(databaseProvider)),
);

/// Runs the pure engine. The default runs it in a background isolate via
/// `compute` (inline on the web); tests use [ForecastRunner.inline].
class ForecastRunner {
  const ForecastRunner() : _inline = false;

  const ForecastRunner.inline() : _inline = true;

  final bool _inline;

  Future<R> _run<Q, R>(R Function(Q) fn, Q request) =>
      _inline ? Future.value(fn(request)) : compute(fn, request);

  Future<CashflowBatch> cashflow(CashflowRequest r) =>
      _run(runCashflowBatch, r);

  Future<CashflowResult> baseline(CashflowRequest r) => _run(runCashflow, r);

  Future<AffordabilityResult> affordability(AffordabilityRequest r) =>
      _run(runAffordability, r);

  Future<ProjectionBatch> projection(ProjectionRequest r) =>
      _run(runProjectionBatch, r);
}

final forecastRunnerProvider = Provider<ForecastRunner>(
  (ref) => const ForecastRunner(),
);

/// Ticks (debounced) whenever a table the forecast reads changes.
final _forecastDataTickProvider = StreamProvider<int>((ref) {
  final ds = ref.watch(forecastDataSourceProvider);
  final controller = StreamController<int>();
  var n = 0;
  Timer? debounce;
  controller.add(n);
  final sub = ds.db
      .tableUpdates(TableUpdateQuery.onAllTables(ds.watchedTables))
      .listen((_) {
        debounce?.cancel();
        debounce = Timer(const Duration(milliseconds: 250), () {
          if (!controller.isClosed) controller.add(++n);
        });
      });
  ref.onDispose(() {
    debounce?.cancel();
    unawaited(sub.cancel());
    unawaited(controller.close());
  });
  return controller.stream;
});

/// Setting keys that change the gathered input.
bool _isInputSetting(String rowId) {
  final key = rowId.substring(rowId.indexOf('|') + 1);
  return key.startsWith('forecast.include') ||
      key == ForecastSettings.variableMethod.key ||
      key == ForecastSettings.lowBalanceThreshold.key ||
      key.startsWith('budgets.') ||
      key == EntrySettings.defaultAccountId.key ||
      key == GeneralSettings.fiscalYearStartMonth.key ||
      key == GeneralSettings.firstDayOfWeek.key;
}

/// The gathered engine input for the current data and settings.
final forecastInputProvider = FutureProvider<ForecastInput>((ref) async {
  await ref.watch(_forecastDataTickProvider.future);
  ref.watch(
    settingsProvider.select(
      (s) => Object.hashAll([
        for (final e in s.raw.entries)
          if (_isInputSetting(e.key)) '${e.key}=${e.value}',
      ]),
    ),
  );
  final settings = ref.read(settingsProvider);
  return await ref
      .watch(forecastDataSourceProvider)
      .gather(
        today: ref.watch(forecastTodayProvider),
        settings: settings,
        firstDayOfWeek: ref.watch(firstDayOfWeekProvider),
      );
});

// ----------------------------------------------------- board selection ---

/// Horizon shown on the forecast board (defaults to the setting).
final forecastHorizonProvider = NotifierProvider<ForecastHorizon, int>(
  ForecastHorizon.new,
);

class ForecastHorizon extends Notifier<int> {
  @override
  int build() => ref.watch(
    settingsProvider.select((s) => s.get(ForecastSettings.horizonMonths)),
  );

  void set(int months) =>
      state = months.clamp(1, ForecastSettings.maxHorizonMonths);
}

/// Account shown on the forecast board; null = all forecast accounts.
final forecastAccountProvider =
    NotifierProvider<ForecastAccountChoice, String?>(ForecastAccountChoice.new);

class ForecastAccountChoice extends Notifier<String?> {
  @override
  String? build() => null;

  String? get accountId => state;
  set accountId(String? id) => state = id;
}

/// Whether the board lists months or budget periods.
final forecastShowPeriodsProvider = NotifierProvider<ForecastShowPeriods, bool>(
  ForecastShowPeriods.new,
);

class ForecastShowPeriods extends Notifier<bool> {
  @override
  bool build() => false;

  bool get periods => state;
  set periods(bool value) => state = value;
}

/// Scenarios compared on the board (none when the module is off).
final comparedScenariosProvider = Provider<List<ScenarioDef>>((ref) {
  final on = ref.watch(
    settingsProvider.select((s) => s.moduleEnabled(AppModule.scenarios)),
  );
  if (!on) return const [];
  return comparedScenarios(
    ref.watch(scenariosProvider).value ?? const <ScenarioDef>[],
  );
});

/// Whether the charts add a line with all compared scenarios applied
/// together (setting on and at least two compared).
final showCombinedScenariosProvider = Provider<bool>((ref) {
  final on = ref.watch(
    settingsProvider.select((s) => s.get(ForecastSettings.combineScenarios)),
  );
  return on && ref.watch(comparedScenariosProvider).length >= 2;
});

/// Engine runs for the compared scenarios, plus the combined run (id
/// [combinedScenarioId]) when it is shown.
final scenarioRunsProvider = Provider<List<ScenarioRun>>((ref) {
  final scenarios = ref.watch(comparedScenariosProvider);
  return [
    for (final s in scenarios) ScenarioRun(s.id, s.adjustments),
    if (ref.watch(showCombinedScenariosProvider))
      ScenarioRun(combinedScenarioId, combinedAdjustments(scenarios)),
  ];
});

// ------------------------------------------------------------- results ---

/// Baseline cash-flow forecast for the current settings (horizon from
/// Settings › Forecast). Used by the dashboard.
final forecastProvider = FutureProvider<CashflowResult>((ref) async {
  final input = await ref.watch(forecastInputProvider.future);
  final horizon = ref.watch(
    settingsProvider.select((s) => s.get(ForecastSettings.horizonMonths)),
  );
  return await ref
      .watch(forecastRunnerProvider)
      .baseline(CashflowRequest(input: input, horizonMonths: horizon));
});

/// Baseline plus compared scenarios over the board's horizon.
final forecastBoardProvider = FutureProvider<CashflowBatch>((ref) async {
  final input = await ref.watch(forecastInputProvider.future);
  final horizon = ref.watch(forecastHorizonProvider);
  return await ref
      .watch(forecastRunnerProvider)
      .cashflow(
        CashflowRequest(
          input: input,
          horizonMonths: horizon,
          scenarios: ref.watch(scenarioRunsProvider),
        ),
      );
});

/// One point of a sparkline.
@immutable
class MiniPoint {
  const MiniPoint(this.date, this.balanceMinor);

  final DateTime date;
  final int balanceMinor;
}

/// Compact forecast for the dashboard card.
@immutable
class MiniForecast {
  const MiniForecast({
    required this.accountId,
    required this.start,
    required this.end,
    required this.lowest,
    required this.points,
    required this.endBalanceMinor,
    this.thresholdMinor,
    this.warning,
    this.daysBelow = 0,
  });

  /// null = all forecast accounts.
  final String? accountId;
  final DateTime start;
  final DateTime end;
  final LowPoint lowest;

  /// At most [MiniForecast.maxPoints] points; each is the lowest day of
  /// its bucket, so dips (and the lowest point) are always visible.
  final List<MiniPoint> points;
  final int endBalanceMinor;
  final int? thresholdMinor;
  final WarningKind? warning;
  final int daysBelow;

  static const maxPoints = 60;

  bool get belowThreshold =>
      thresholdMinor != null && lowest.amountMinor < thresholdMinor!;

  bool get belowZero => lowest.amountMinor < 0;
}

MiniForecast miniForecastOf(CashflowResult r, String? accountId) {
  final s = r.series(accountId);
  final points = <MiniPoint>[];
  if (s.isNotEmpty) {
    final bucket = (s.length / MiniForecast.maxPoints).ceil().clamp(
      1,
      s.length,
    );
    for (var i = 0; i < s.length; i += bucket) {
      var best = i;
      for (var k = i + 1; k < i + bucket && k < s.length; k++) {
        if (s[k] < s[best]) best = k;
      }
      points.add(MiniPoint(r.dateAt(best), s[best]));
    }
  }
  final w = r.warning(accountId);
  final t = r.threshold(accountId);
  return MiniForecast(
    accountId: accountId,
    start: r.start,
    end: r.end,
    lowest: r.lowest(accountId) ?? LowPoint(r.start, 0),
    points: points,
    endBalanceMinor: s.isEmpty ? 0 : s.last,
    thresholdMinor: t,
    warning: w?.kind,
    daysBelow: r.daysBelow(accountId, t ?? 0),
  );
}

/// Dashboard mini forecast for one account, or for the total when null.
final miniForecastProvider = FutureProvider.family<MiniForecast, String?>((
  ref,
  accountId,
) async {
  final r = await ref.watch(forecastProvider.future);
  return miniForecastOf(
    r,
    accountId != null && r.accountIds.contains(accountId) ? accountId : null,
  );
});

/// Lowest total balance within the default horizon (null without forecast
/// accounts).
final cashflowLowPointProvider = FutureProvider<LowPoint?>((ref) async {
  final r = await ref.watch(forecastProvider.future);
  return r.accountIds.isEmpty ? null : r.lowestTotal;
});

// ---------------------------------------------------------- projection ---

/// Savings source of the projection (session state).
final projectionSourceProvider =
    NotifierProvider<ProjectionSource, SavingsSource>(ProjectionSource.new);

class ProjectionSource extends Notifier<SavingsSource> {
  @override
  SavingsSource build() => SavingsSource.history;

  SavingsSource get source => state;
  set source(SavingsSource value) => state = value;
}

final projectionAssumptionsProvider = Provider<ProjectionAssumptions>((ref) {
  final s = ref.watch(settingsProvider);
  return ProjectionAssumptions(
    years: s.get(ForecastSettings.projectionYears),
    inflationBp: s.get(ForecastSettings.inflationBp),
    defaultReturnBp: s.get(ForecastSettings.defaultReturnBp),
    source: ref.watch(projectionSourceProvider),
  );
});

/// The projection in nominal values; the screen switches to real values
/// with [ProjectionBatch.withReal], without a new projection.
final projectionProvider = FutureProvider<ProjectionBatch>((ref) async {
  final input = await ref.watch(forecastInputProvider.future);
  return await ref
      .watch(forecastRunnerProvider)
      .projection(
        ProjectionRequest(
          input: input,
          assumptions: ref.watch(projectionAssumptionsProvider),
          scenarios: ref.watch(scenarioRunsProvider),
        ),
      );
});
