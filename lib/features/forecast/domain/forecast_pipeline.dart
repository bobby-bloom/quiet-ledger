import 'package:meta/meta.dart';
import 'package:personal_finance/core/settings/setting_enums.dart';
import 'package:personal_finance/features/forecast/domain/cashflow_engine.dart';
import 'package:personal_finance/features/forecast/domain/forecast_dates.dart';
import 'package:personal_finance/features/forecast/domain/forecast_models.dart';
import 'package:personal_finance/features/forecast/domain/projection.dart';
import 'package:personal_finance/features/scenarios/domain/apply_scenario.dart';
import 'package:personal_finance/features/scenarios/domain/scenario.dart';

// Top-level entry points of the forecast engine. Each takes one plain
// request object and is a top-level function, so it can be passed to
// `compute` / `Isolate.run` (on the web `compute` runs it inline).

@immutable
class ScenarioRun {
  const ScenarioRun(this.id, this.adjustments);

  final String id;
  final List<ScenarioAdjustment> adjustments;
}

@immutable
class CashflowRequest {
  const CashflowRequest({
    required this.input,
    required this.horizonMonths,
    this.scenarios = const [],
  });

  final ForecastInput input;
  final int horizonMonths;
  final List<ScenarioRun> scenarios;
}

@immutable
class CashflowBatch {
  const CashflowBatch(this.baseline, this.scenarios);

  final CashflowResult baseline;

  /// Scenario id -> result.
  final Map<String, CashflowResult> scenarios;
}

/// Baseline plus each scenario over the same horizon.
CashflowBatch runCashflowBatch(CashflowRequest request) {
  final model = prepareCashflowModel(
    request.input,
    horizonMonths: request.horizonMonths,
  );
  return CashflowBatch(simulateCashflow(model), {
    for (final s in request.scenarios)
      s.id: simulateCashflow(applyScenario(model, s.adjustments)),
  });
}

/// The baseline cash-flow forecast only.
CashflowResult runCashflow(CashflowRequest request) => simulateCashflow(
  prepareCashflowModel(request.input, horizonMonths: request.horizonMonths),
);

@immutable
class AffordabilityRequest {
  const AffordabilityRequest({
    required this.input,
    required this.horizonMonths,
    required this.amountMinor,
    required this.date,
    required this.accountId,
    this.label = '',
    this.scenario = const [],
  });

  final ForecastInput input;
  final int horizonMonths;

  /// Positive amount to spend.
  final int amountMinor;
  final DateTime date;
  final String accountId;
  final String label;

  /// Optional scenario adjustments to check against instead of the
  /// baseline.
  final List<ScenarioAdjustment> scenario;
}

/// "Can I afford X on D?" The horizon is extended to cover at least three
/// months after [AffordabilityRequest.date].
AffordabilityResult runAffordability(AffordabilityRequest r) {
  final today = dayOf(r.input.today);
  final monthsToDate =
      (r.date.year - today.year) * 12 + r.date.month - today.month + 3;
  final horizon = r.horizonMonths > monthsToDate
      ? r.horizonMonths
      : monthsToDate;
  var model = prepareCashflowModel(r.input, horizonMonths: horizon);
  if (r.scenario.isNotEmpty) model = applyScenario(model, r.scenario);
  return checkAffordability(
    model,
    amountMinor: r.amountMinor,
    date: r.date,
    accountId: r.accountId,
    label: r.label,
  );
}

@immutable
class ProjectionRequest {
  const ProjectionRequest({
    required this.input,
    required this.assumptions,
    this.scenarios = const [],
  });

  final ForecastInput input;
  final ProjectionAssumptions assumptions;
  final List<ScenarioRun> scenarios;
}

@immutable
class ProjectionBatch {
  const ProjectionBatch(this.baseline, this.scenarios);

  final NetWorthProjection baseline;
  final Map<String, NetWorthProjection> scenarios;
}

/// Net-worth projection for the baseline and each scenario. With savings
/// from the plan, expected variable spending always comes from the budgets
/// (plan = recurring items + budgets), whatever the forecast's method.
ProjectionBatch runProjectionBatch(ProjectionRequest r) {
  final months = r.assumptions.months;
  final input = r.assumptions.source == SavingsSource.plan
      ? r.input.copyWith(method: VariableSpendingMethod.budget)
      : r.input;
  final model = prepareCashflowModel(
    input,
    scope: AccountScope.netWorth,
    endOverride: addMonthsClamped(dayOf(r.input.today), months),
  );
  final savings = historicMonthlySavings(r.input.history);
  final baseFlows = aggregateMonthly(model, months);
  final baseline = projectNetWorth(
    model,
    r.assumptions,
    goals: r.input.goals,
    historyMonthlySavings: savings,
    flows: baseFlows,
  );
  final scenarios = <String, NetWorthProjection>{};
  for (final s in r.scenarios) {
    final m = applyScenario(model, s.adjustments);
    scenarios[s.id] = projectNetWorth(
      m,
      applyAssumptionAdjustments(r.assumptions, s.adjustments),
      goals: r.input.goals,
      historyMonthlySavings: savings,
      flows: aggregateMonthly(m, months),
      baselineFlows: baseFlows,
    );
  }
  return ProjectionBatch(baseline, scenarios);
}
