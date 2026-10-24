import 'package:meta/meta.dart';
import 'package:personal_finance/core/db/tables.dart';
import 'package:personal_finance/features/forecast/domain/forecast_dates.dart';
import 'package:personal_finance/features/forecast/domain/forecast_models.dart';
import 'package:personal_finance/features/forecast/domain/projection.dart';
import 'package:personal_finance/features/forecast/domain/recurring_expansion.dart';
import 'package:personal_finance/features/scenarios/domain/scenario.dart';

/// Applies [adjustments] to a baseline cash-flow [model] (pure; the model
/// is not modified). Return and inflation adjustments only affect the
/// projection (see [applyAssumptionAdjustments]).
CashflowModel applyScenario(
  CashflowModel model,
  List<ScenarioAdjustment> adjustments,
) {
  var recurring = model.recurring;
  var events = model.events;
  var spread = model.spread;
  var added = 0;
  for (final adj in adjustments) {
    switch (adj) {
      case OneOffAdjustment():
        events = [
          ...events,
          PlannedEvent(
            date: dayOf(adj.date),
            accountId: adj.accountId,
            amountMinor: adj.amountMinor,
            label: adj.label,
            kind: ForecastEventKind.oneOff,
          ),
        ];
      case CategoryChangeAdjustment(mode: ChangeMode.percent):
        recurring = _modifyWhere(
          recurring,
          (r) => r.booksTo(adj.categoryId),
          AmountModifier(
            from: adj.from,
            categoryId: adj.categoryId,
            percentBp: adj.value,
          ),
        );
        spread = _scaleSpread(spread, adj.categoryId, adj.from, adj.value);
      case CategoryChangeAdjustment(mode: ChangeMode.absolute):
        spread = [...spread, ..._monthlyDelta(model, adj)];
      case RecurringChangeAdjustment():
        recurring = _modifyWhere(
          recurring,
          (r) => r.id == adj.ruleId,
          AmountModifier(
            from: adj.from,
            percentBp: adj.mode == ChangeMode.percent ? adj.value : null,
            deltaMinor: adj.mode == ChangeMode.absolute ? adj.value : null,
          ),
        );
      case AddRecurringAdjustment():
        final transfer =
            adj.transferAccountId != null && adj.transferAccountId!.isNotEmpty;
        recurring = [
          ...recurring,
          RecurringItem(
            id: 'scenario:${added++}',
            name: adj.label,
            rrule: adj.rrule,
            startDate: dayOf(adj.start),
            endDate: adj.end == null ? null : dayOf(adj.end!),
            accountId: adj.accountId,
            amountMinor: adj.amountMinor,
            transferAccountId: transfer ? adj.transferAccountId : null,
            type: transfer
                ? TxnType.transfer
                : (adj.amountMinor >= 0 ? TxnType.income : TxnType.expense),
            categories: transfer
                ? const []
                : [CategoryShare(adj.categoryId, adj.amountMinor)],
          ),
        ];
      case EndRecurringAdjustment():
        final last = addDays(dayOf(adj.from), -1);
        recurring = recurring.map((r) {
          final ends =
              r.id == adj.ruleId &&
              (r.endDate == null || r.endDate!.isAfter(last));
          return ends ? r.copyWith(endDate: last) : r;
        }).toList();
      case ReturnAdjustment() || InflationAdjustment() || UnknownAdjustment():
        break;
    }
  }
  return model.copyWith(recurring: recurring, events: events, spread: spread);
}

List<RecurringItem> _modifyWhere(
  List<RecurringItem> items,
  bool Function(RecurringItem) test,
  AmountModifier modifier,
) => items.map((r) {
  if (!test(r)) return r;
  return r.copyWith(modifiers: [...r.modifiers, modifier]);
}).toList();

/// Applies return and inflation adjustments to projection [assumptions].
ProjectionAssumptions applyAssumptionAdjustments(
  ProjectionAssumptions assumptions,
  List<ScenarioAdjustment> adjustments,
) {
  var a = assumptions;
  for (final adj in adjustments) {
    switch (adj) {
      case ReturnAdjustment(accountId: final String id):
        a = a.copyWith(
          accountReturnBp: {...a.accountReturnBp, id: adj.returnBp},
        );
      case ReturnAdjustment():
        a = a.copyWith(assetReturnBp: adj.returnBp);
      case InflationAdjustment():
        a = a.copyWith(inflationBp: adj.inflationBp);
      default:
        break;
    }
  }
  return a;
}

int _scale(int amount, int percentBp) =>
    amount + divRound(amount * percentBp, 10000);

/// Scales the spread items of [categoryId] from [from] on. An item that
/// straddles [from] is split exactly where the engine's daily allocation
/// splits it, so the part before [from] is unchanged to the cent.
List<SpreadItem> _scaleSpread(
  List<SpreadItem> spread,
  String categoryId,
  DateTime from,
  int percentBp,
) {
  final f = dayOf(from);
  final out = <SpreadItem>[];
  for (final s in spread) {
    if (s.categoryId != categoryId || !s.end.isAfter(f)) {
      out.add(s);
      continue;
    }
    if (!s.start.isBefore(f)) {
      out.add(_withTotal(s, s.start, s.end, _scale(s.totalMinor, percentBp)));
      continue;
    }
    final shares = allocateEvenly(s.totalMinor, s.days);
    final k = daysBetween(s.start, f);
    final before = shares.take(k).fold(0, (a, b) => a + b);
    out
      ..add(_withTotal(s, s.start, f, before))
      ..add(_withTotal(s, f, s.end, _scale(s.totalMinor - before, percentBp)));
  }
  return out;
}

SpreadItem _withTotal(SpreadItem s, DateTime start, DateTime end, int total) =>
    SpreadItem(
      accountId: s.accountId,
      categoryId: s.categoryId,
      start: start,
      end: end,
      totalMinor: total,
    );

/// An absolute monthly change of a category as spread items from
/// `adj.from` to the model's end (the first month prorated by days).
List<SpreadItem> _monthlyDelta(
  CashflowModel model,
  CategoryChangeAdjustment adj,
) {
  final account =
      model.categoryAccount[adj.categoryId] ?? model.primaryAccountId;
  if (account == null || adj.value == 0) return const [];
  final income = model.incomeCategoryIds.contains(adj.categoryId);
  final signed = income ? adj.value : -adj.value;
  final out = <SpreadItem>[];
  final from = dayOf(adj.from);
  for (var m = monthStart(from); !m.isAfter(model.end); m = nextMonthStart(m)) {
    final next = nextMonthStart(m);
    if (!next.isAfter(model.today)) continue;
    final start = m.isBefore(from) ? from : m;
    final total = start == m
        ? signed
        : divRound(
            signed * daysBetween(start, next),
            daysInMonth(m.year, m.month),
          );
    if (total == 0) continue;
    out.add(
      SpreadItem(
        accountId: account,
        categoryId: adj.categoryId,
        start: start,
        end: next,
        totalMinor: total,
      ),
    );
  }
  return out;
}

/// A scenario's cash-flow result compared with the baseline for one
/// account (or the total).
@immutable
class ScenarioComparison {
  const ScenarioComparison({
    required this.baselineLow,
    required this.scenarioLow,
    required this.baselineEnd,
    required this.scenarioEnd,
    required this.baselineDaysBelow,
    required this.scenarioDaysBelow,
    required this.baselineWarning,
    required this.scenarioWarning,
    required this.monthEndDeltas,
  });

  final LowPoint baselineLow;
  final LowPoint scenarioLow;
  final int baselineEnd;
  final int scenarioEnd;

  /// Days below the threshold (or below zero without one).
  final int baselineDaysBelow;
  final int scenarioDaysBelow;
  final WarningKind? baselineWarning;
  final WarningKind? scenarioWarning;

  /// Scenario − baseline month-end balance, aligned with the baseline's
  /// months.
  final List<int> monthEndDeltas;

  int get lowDeltaMinor => scenarioLow.amountMinor - baselineLow.amountMinor;

  int get endDeltaMinor => scenarioEnd - baselineEnd;

  /// The scenario removes a warning the baseline has.
  bool get resolvesWarning =>
      baselineWarning != null && scenarioWarning == null;

  /// The scenario causes a warning the baseline does not have.
  bool get causesWarning => baselineWarning == null && scenarioWarning != null;
}

ScenarioComparison compareScenario(
  CashflowResult baseline,
  CashflowResult scenario, {
  String? accountId,
}) {
  int below(CashflowResult r) =>
      r.daysBelow(accountId, r.threshold(accountId) ?? 0);
  final months = List<int>.generate(baseline.months.length, (i) {
    if (i >= scenario.months.length) return 0;
    return scenario.months[i].endOf(accountId) -
        baseline.months[i].endOf(accountId);
  });
  final bs = baseline.series(accountId);
  final ss = scenario.series(accountId);
  return ScenarioComparison(
    baselineLow: baseline.lowest(accountId) ?? LowPoint(baseline.start, 0),
    scenarioLow: scenario.lowest(accountId) ?? LowPoint(scenario.start, 0),
    baselineEnd: bs.isEmpty ? 0 : bs.last,
    scenarioEnd: ss.isEmpty ? 0 : ss.last,
    baselineDaysBelow: below(baseline),
    scenarioDaysBelow: below(scenario),
    baselineWarning: baseline.warning(accountId)?.kind,
    scenarioWarning: scenario.warning(accountId)?.kind,
    monthEndDeltas: months,
  );
}
