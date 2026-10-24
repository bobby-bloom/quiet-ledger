import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/db/tables.dart';
import 'package:personal_finance/features/forecast/domain/cashflow_engine.dart';
import 'package:personal_finance/features/forecast/domain/forecast_models.dart';
import 'package:personal_finance/features/forecast/domain/forecast_pipeline.dart';
import 'package:personal_finance/features/forecast/domain/projection.dart';
import 'package:personal_finance/features/scenarios/domain/apply_scenario.dart';
import 'package:personal_finance/features/scenarios/domain/scenario.dart';

import '../forecast/forecast_fixtures.dart';

CashflowModel baseModel({ForecastInput? input}) =>
    prepareCashflowModel(input ?? baseInput());

CashflowResult withAdjustments(
  List<ScenarioAdjustment> adjustments, {
  ForecastInput? input,
}) => simulateCashflow(applyScenario(baseModel(input: input), adjustments));

void main() {
  final all = <ScenarioAdjustment>[
    OneOffAdjustment(
      date: d(2027, 2, 10),
      amountMinor: -140000,
      accountId: 'checking',
      label: 'New laptop',
    ),
    CategoryChangeAdjustment(
      categoryId: 'groceries',
      from: d(2027, 1, 1),
      mode: ChangeMode.percent,
      value: -1000,
    ),
    RecurringChangeAdjustment(
      ruleId: 'salary',
      from: d(2027, 1, 1),
      mode: ChangeMode.absolute,
      value: 16500,
    ),
    AddRecurringAdjustment(
      label: 'Gym',
      rrule: 'FREQ=MONTHLY;BYMONTHDAY=15',
      start: d(2026, 11, 15),
      end: d(2027, 6, 15),
      amountMinor: -3990,
      accountId: 'checking',
      categoryId: 'sport',
    ),
    EndRecurringAdjustment(ruleId: 'car', from: d(2027, 3, 1)),
    const ReturnAdjustment(returnBp: 300),
    const ReturnAdjustment(returnBp: 450, accountId: 'etf'),
    const InflationAdjustment(inflationBp: 350),
  ];

  group('JSON', () {
    test('every adjustment type round-trips', () {
      final json = ScenarioAdjustment.encodeList(all);
      final back = ScenarioAdjustment.decodeList(json);
      expect(back, all);
      expect(ScenarioAdjustment.encodeList(back), json);
    });

    test('stable wire format', () {
      expect(all.first.toJson(), {
        'type': 'oneOff',
        'date': '2027-02-10',
        'amountMinor': -140000,
        'accountId': 'checking',
        'label': 'New laptop',
      });
      expect(all[2].toJson()['mode'], 'absolute');
      expect(all[3].toJson().containsKey('transferAccountId'), isFalse);
    });

    test('unknown and malformed entries are preserved verbatim', () {
      const source =
          '[{"type":"futureThing","x":1},{"type":"oneOff","date":"bad"},3]';
      final list = ScenarioAdjustment.decodeList(source);
      expect(list, hasLength(2));
      expect(list.every((a) => a is UnknownAdjustment), isTrue);
      expect(jsonDecode(ScenarioAdjustment.encodeList(list)), [
        {'type': 'futureThing', 'x': 1},
        {'type': 'oneOff', 'date': 'bad'},
      ]);
    });

    test('invalid JSON yields an empty list', () {
      expect(ScenarioAdjustment.decodeList('{nope'), isEmpty);
      expect(ScenarioAdjustment.decodeList(''), isEmpty);
      expect(ScenarioAdjustment.decodeList('{"a":1}'), isEmpty);
    });

    test('scenario copyWith and comparedScenarios caps at five', () {
      final s = [
        for (var i = 0; i < 7; i++)
          ScenarioDef(id: '$i', name: 's$i', enabled: i != 1),
      ];
      expect(comparedScenarios(s).map((e) => e.id), ['0', '2', '3', '4', '5']);
      final c = s.first.copyWith(color: 0xFF000000, name: 'x');
      expect(c.color, 0xFF000000);
      expect(c.copyWith(color: null).color, isNull);
      expect(c, s.first.copyWith(color: 0xFF000000, name: 'x'));
    });
  });

  group('apply', () {
    final base = simulateCashflow(baseModel());

    test('one-off event', () {
      final r = withAdjustments([
        OneOffAdjustment(
          date: d(2026, 11, 10),
          amountMinor: -50000,
          accountId: 'checking',
          label: 'Laptop',
        ),
      ]);
      expect(
        r.balanceOn('checking', d(2026, 11, 9)),
        base.balanceOn('checking', d(2026, 11, 9)),
      );
      expect(r.series('checking').last, base.series('checking').last - 50000);
      expect(
        r.events.singleWhere((e) => e.kind == ForecastEventKind.oneOff).label,
        'Laptop',
      );
    });

    test('percent change of a recurring income from a date', () {
      final r = withAdjustments([
        RecurringChangeAdjustment(
          ruleId: 'salary',
          from: d(2026, 12, 1),
          mode: ChangeMode.percent,
          value: 500,
        ),
      ]);
      // Only the December salary (+5 % = +150.00) is in the horizon.
      expect(r.series('checking').last, base.series('checking').last + 15000);
    });

    test('absolute change of a recurring rule per occurrence', () {
      final r = withAdjustments([
        RecurringChangeAdjustment(
          ruleId: 'rent',
          from: d(2026, 11, 1),
          mode: ChangeMode.absolute,
          value: 10000,
        ),
      ]);
      // Three rent payments, each 100.00 more.
      expect(r.series('checking').last, base.series('checking').last - 30000);
    });

    test('combined scenarios stack their effects', () {
      final laptop = ScenarioDef(
        id: 'a',
        name: 'Laptop',
        adjustments: [
          OneOffAdjustment(
            date: d(2026, 11, 10),
            amountMinor: -50000,
            accountId: 'checking',
            label: 'Laptop',
          ),
          const InflationAdjustment(inflationBp: 300),
        ],
      );
      final rent = ScenarioDef(
        id: 'b',
        name: 'Rent',
        adjustments: [
          RecurringChangeAdjustment(
            ruleId: 'rent',
            from: d(2026, 11, 1),
            mode: ChangeMode.absolute,
            value: 10000,
          ),
          const InflationAdjustment(inflationBp: 450),
        ],
      );
      final adjustments = combinedAdjustments([laptop, rent]);
      expect(adjustments, [...laptop.adjustments, ...rent.adjustments]);
      final r = withAdjustments(adjustments);
      expect(
        r.series('checking').last,
        base.series('checking').last - 50000 - 30000,
      );
      // The last scenario's inflation wins.
      expect(
        applyAssumptionAdjustments(
          const ProjectionAssumptions(),
          adjustments,
        ).inflationBp,
        450,
      );
    });

    test('percent change of a category scales its rules', () {
      final r = withAdjustments([
        CategoryChangeAdjustment(
          categoryId: 'cat-rent',
          from: d(2027, 1, 1),
          mode: ChangeMode.percent,
          value: 1000,
        ),
      ]);
      // January rent 1,300 + 10 %.
      expect(r.series('checking').last, base.series('checking').last - 13000);
    });

    test('percent change of variable spending splits the window exactly', () {
      final input = baseInput(
        recurring: const [],
        history: SpendingHistory(
          months: [
            for (final m in [7, 8, 9])
              CategoryMonthTotal(
                categoryId: 'groceries',
                year: 2026,
                month: m,
                spentMinor: 31000,
              ),
          ],
          firstTxnDate: d(2026, 1, 1),
          categoryAccount: const {'groceries': 'checking'},
        ),
      );
      final b = simulateCashflow(baseModel(input: input));
      final r = withAdjustments([
        CategoryChangeAdjustment(
          categoryId: 'groceries',
          from: d(2026, 12, 16),
          mode: ChangeMode.percent,
          value: -5000,
        ),
      ], input: input);
      // Up to 15 Dec nothing changes, to the cent.
      expect(
        r.balanceOn('checking', d(2026, 12, 15)),
        b.balanceOn('checking', d(2026, 12, 15)),
      );
      // 16–31 Dec: 16 of 31 daily 10.00 shares, halved.
      final bDec =
          b.balanceOn('checking', d(2026, 12, 15)) -
          b.balanceOn('checking', d(2026, 12, 31));
      final rDec =
          r.balanceOn('checking', d(2026, 12, 15)) -
          r.balanceOn('checking', d(2026, 12, 31));
      expect(bDec, 16000);
      expect(rDec, 8000);
    });

    test('absolute change of a category is spread per month', () {
      final r = withAdjustments([
        CategoryChangeAdjustment(
          categoryId: 'groceries',
          from: d(2026, 12, 1),
          mode: ChangeMode.absolute,
          value: 3100,
        ),
      ]);
      // December: 31.00 over 31 days; January: 23 of 31 days of 1.00.
      expect(
        r.series('checking').last,
        base.series('checking').last - 3100 - 2300,
      );
    });

    test('absolute change of an income category adds money', () {
      final input = baseInput();
      final model = prepareCashflowModel(input);
      final incomeModel = CashflowModel(
        today: model.today,
        end: model.end,
        accounts: model.accounts,
        recurring: model.recurring,
        events: model.events,
        spread: model.spread,
        incomeCategoryIds: const {'cat-side'},
        primaryAccountId: 'checking',
      );
      final r = simulateCashflow(
        applyScenario(incomeModel, [
          CategoryChangeAdjustment(
            categoryId: 'cat-side',
            from: d(2026, 11, 1),
            mode: ChangeMode.absolute,
            value: 3000,
          ),
        ]),
      );
      // Nov + Dec full; January books 23 of its 31 daily shares
      // (⌊23 · 30.00 / 31⌋ = 22.25).
      expect(
        r.series('checking').last,
        base.series('checking').last + 3000 + 3000 + 2225,
      );
    });

    test('add a recurring item', () {
      final r = withAdjustments([all[3]]);
      // Gym on 15 Nov, 15 Dec, 15 Jan.
      expect(
        r.series('checking').last,
        base.series('checking').last - 3 * 3990,
      );
      expect(r.events.where((e) => e.label == 'Gym').map((e) => e.date), [
        d(2026, 11, 15),
        d(2026, 12, 15),
        d(2027, 1, 15),
      ]);
    });

    test('add a recurring transfer', () {
      final r = withAdjustments([
        AddRecurringAdjustment(
          label: 'Extra saving',
          rrule: 'FREQ=MONTHLY;BYMONTHDAY=20',
          start: d(2026, 11, 20),
          amountMinor: -10000,
          accountId: 'checking',
          transferAccountId: 'savings',
        ),
      ]);
      expect(r.series('savings').last, base.series('savings').last + 30000);
      expect(r.total.last, base.total.last);
    });

    test('end an existing recurring rule from a date', () {
      final r = withAdjustments([
        EndRecurringAdjustment(ruleId: 'save', from: d(2026, 12, 2)),
      ]);
      // Only the November transfer happens.
      expect(r.series('savings').last, 250000);
      expect(r.series('checking').last, base.series('checking').last + 100000);
    });

    test('assumption adjustments do not touch the cash flow', () {
      final r = withAdjustments([
        const ReturnAdjustment(returnBp: 900),
        const InflationAdjustment(inflationBp: 900),
        const UnknownAdjustment({'type': 'x'}),
      ]);
      expect(r.total, base.total);
    });

    test('assumption adjustments change the projection assumptions', () {
      final a = applyAssumptionAdjustments(
        const ProjectionAssumptions(defaultReturnBp: 500),
        all,
      );
      expect(a.inflationBp, 350);
      expect(a.assetReturnBp, 300);
      expect(a.accountReturnBp, {'etf': 450});
      final etf = account('etf', type: AccountType.investment);
      expect(a.rateOf(etf), 450);
      expect(a.rateOf(account('sav', type: AccountType.savings)), 300);
      expect(a.rateOf(account('chk')), 0);
      expect(
        a.rateOf(account('loan', type: AccountType.loan, interestBp: 400)),
        400,
      );
    });
  });

  group('compare', () {
    test('lowest point, end and month-end deltas', () {
      final base = simulateCashflow(baseModel());
      final scen = withAdjustments([
        OneOffAdjustment(
          date: d(2026, 10, 24),
          amountMinor: 100000,
          accountId: 'checking',
          label: 'Gift',
        ),
      ]);
      final c = compareScenario(base, scen, accountId: 'checking');
      expect(c.baselineLow, LowPoint(today, 100000));
      expect(c.scenarioLow, LowPoint(today, 100000));
      expect(c.endDeltaMinor, 100000);
      expect(c.monthEndDeltas, [100000, 100000, 100000, 100000]);
      // Baseline below 1,500 for 5 days, the gift cuts it to 1 day.
      expect(c.baselineDaysBelow, 5);
      expect(c.scenarioDaysBelow, 1);
      expect(c.resolvesWarning, isFalse);
      expect(c.causesWarning, isFalse);
    });

    test('a scenario that causes a warning', () {
      final base = simulateCashflow(baseModel());
      final scen = withAdjustments([
        OneOffAdjustment(
          date: d(2026, 11, 5),
          amountMinor: -300000,
          accountId: 'savings',
          label: 'Car',
        ),
      ]);
      final c = compareScenario(base, scen, accountId: 'savings');
      expect(c.causesWarning, isTrue);
      expect(c.lowDeltaMinor, -300000 + 50000);
    });

    test('batch runs baseline and scenarios on the same horizon', () {
      final batch = runCashflowBatch(
        CashflowRequest(
          input: baseInput(),
          horizonMonths: 6,
          scenarios: [
            ScenarioRun('raise', [all[2]]),
            ScenarioRun('laptop', [all[0]]),
          ],
        ),
      );
      expect(batch.scenarios.keys, ['raise', 'laptop']);
      expect(batch.scenarios['raise']!.end, batch.baseline.end);
      // Salaries of 28 Jan, 26 Feb and 26 Mar get +165.00 (28 Apr is after
      // the horizon end of 23 Apr).
      expect(
        batch.scenarios['raise']!.total.last - batch.baseline.total.last,
        3 * 16500,
      );
      expect(
        batch.scenarios['laptop']!.total.last - batch.baseline.total.last,
        -140000,
      );
    });

    test('projection batch applies scenario savings and assumptions', () {
      final input = ForecastInput(
        today: today,
        accounts: [
          account('chk', balance: 100000),
          account(
            'etf',
            balance: 1000000,
            type: AccountType.investment,
            returnBp: 600,
          ),
        ],
        recurring: [
          rule(
            'salary',
            rrule: 'FREQ=MONTHLY;BYMONTHDAY=28',
            amount: 300000,
            accountId: 'chk',
          ),
        ],
        history: SpendingHistory(monthlyNet: List.filled(12, 50000)),
      );
      final batch = runProjectionBatch(
        ProjectionRequest(
          input: input,
          assumptions: const ProjectionAssumptions(years: 1, inflationBp: 0),
          scenarios: [
            ScenarioRun('raise', [
              RecurringChangeAdjustment(
                ruleId: 'salary',
                from: d(2026, 1, 1),
                mode: ChangeMode.absolute,
                value: 10000,
              ),
            ]),
            const ScenarioRun('bear', [
              ReturnAdjustment(returnBp: 0, accountId: 'etf'),
            ]),
          ],
        ),
      );
      final base = batch.baseline.last.nominalMinor;
      expect(base, 100000 + 12 * 50000 + 1061679);
      // History savings + the scenario's extra 100.00 per salary.
      expect(batch.scenarios['raise']!.last.nominalMinor, base + 12 * 10000);
      expect(batch.scenarios['bear']!.last.nominalMinor, base - 61679);
    });
  });
}
