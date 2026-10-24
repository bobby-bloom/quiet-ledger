import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/calendar/budget_period.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/features/reports/data/report_queries.dart';
import 'package:personal_finance/features/reports/domain/report_models.dart';
import 'package:personal_finance/features/reports/domain/report_periods.dart';

import '../../helpers/test_app.dart';
import 'report_fixture.dart';

void main() {
  late AppDatabase db;
  late ReportFixture fx;
  late ReportQueries q;
  final march = monthOf(DateTime(2026, 3));
  final marchFilter = ReportFilter(range: march);

  setUp(() async {
    db = newTestDb();
    fx = await ReportFixture.create(db);
    q = ReportQueries(db);
  });

  tearDown(() => db.close());

  Map<String?, int> totals(List<CategoryAmount> rows) => {
    for (final r in rows) r.categoryId: r.amountMinor,
  };

  group('by category', () {
    test('rolls children up, uses split lines, skips noise', () async {
      final rows = await q
          .watchByCategory(marchFilter, ReportExclusions.none)
          .first;
      expect(totals(rows), {
        fx.rent: 100000,
        fx.food: 19500,
        fx.fun: 4000,
        null: 500,
      });
      // Sorted descending.
      expect(rows.map((r) => r.amountMinor), [100000, 19500, 4000, 500]);
      final food = rows.firstWhere((r) => r.categoryId == fx.food);
      expect(food.hasChildren, isTrue);
      expect(food.name, 'Food');
      expect(
        rows.firstWhere((r) => r.categoryId == fx.rent).hasChildren,
        false,
      );
      final fun = rows.firstWhere((r) => r.categoryId == fx.fun);
      expect(fun.archived, isTrue);
      expect(fun.count, 1);
    });

    test('drill-down lists the parent and its children', () async {
      final rows = await q
          .watchByCategory(
            marchFilter,
            ReportExclusions.none,
            parentId: fx.food,
          )
          .first;
      expect(totals(rows), {
        fx.groceries: 10000,
        fx.restaurants: 7500,
        fx.food: 2000,
      });
      final groceries = rows.firstWhere((r) => r.categoryId == fx.groceries);
      // Corner Grocer, split, refund.
      expect(groceries.count, 3);
    });

    test('income by category', () async {
      final rows = await q
          .watchByCategory(
            marchFilter,
            ReportExclusions.none,
            kind: CategoryKind.income,
          )
          .first;
      expect(totals(rows), {fx.salary: 300000});
    });

    test('account, tag and custom field filters', () async {
      final byAccount = await q
          .watchByCategory(
            marchFilter.copyWith(accountIds: {fx.card}),
            ReportExclusions.none,
          )
          .first;
      expect(totals(byAccount), {fx.food: 4500});

      final byTag = await q
          .watchByCategory(
            marchFilter.copyWith(tagIds: {fx.vacation}),
            ReportExclusions.none,
          )
          .first;
      expect(totals(byTag), {fx.food: 4500});

      final byField = await q
          .watchByCategory(
            marchFilter.copyWith(
              customField: CustomFieldFilter(
                fieldId: fx.projectField,
                value: 'trip',
              ),
            ),
            ReportExclusions.none,
          )
          .first;
      expect(totals(byField), {fx.food: 4500});

      final noMatch = await q
          .watchByCategory(
            marchFilter.copyWith(
              customField: CustomFieldFilter(
                fieldId: fx.projectField,
                value: 'Home',
              ),
            ),
            ReportExclusions.none,
          )
          .first;
      expect(noMatch, isEmpty);
    });

    test(
      'exclusions: parent category removes children, tags, accounts',
      () async {
        final noFood = await q
            .watchByCategory(
              marchFilter,
              ReportExclusions(categoryIds: {fx.food}),
            )
            .first;
        expect(totals(noFood), {fx.rent: 100000, fx.fun: 4000, null: 500});

        final noChild = await q
            .watchByCategory(
              marchFilter,
              ReportExclusions(categoryIds: {fx.restaurants}),
            )
            .first;
        expect(totals(noChild)[fx.food], 12000);

        final noOneOff = await q
            .watchByCategory(marchFilter, ReportExclusions(tagIds: {fx.oneOff}))
            .first;
        expect(totals(noOneOff).containsKey(fx.rent), isFalse);

        final noCard = await q
            .watchByCategory(
              marchFilter,
              ReportExclusions(accountIds: {fx.card}),
            )
            .first;
        expect(totals(noCard)[fx.food], 15000);
      },
    );

    test('is reactive', () async {
      final stream = q.watchByCategory(marchFilter, ReportExclusions.none);
      final values = <int>[];
      final sub = stream.listen(
        (rows) => values.add(totals(rows)[fx.rent] ?? 0),
      );
      await pumpEventQueue();
      await fx.expense(DateTime(2026, 3, 30), -1000, category: fx.rent);
      await pumpEventQueue();
      await sub.cancel();
      expect(values.first, 100000);
      expect(values.last, 101000);
    });
  });

  group('income vs expense', () {
    test('monthly buckets across the year boundary', () async {
      final range = DateRange(DateTime(2025, 12), DateTime(2026, 4));
      final rows = await q
          .watchIncomeExpense(
            ReportFilter(range: range),
            ReportExclusions.none,
            bucketsFor(range, ReportInterval.month),
          )
          .first;
      expect(rows.map((r) => r.range.start), [
        DateTime(2025, 12),
        DateTime(2026),
        DateTime(2026, 2),
        DateTime(2026, 3),
      ]);
      expect(rows.map((r) => r.expenseMinor), [1100, 2200, 4000, 124000]);
      expect(rows.map((r) => r.incomeMinor), [0, 0, 0, 300000]);
      expect(rows.last.netMinor, 176000);
      expect(rows.last.savingsRateBp, 5867);
      expect(rows.first.savingsRateBp, isNull);
    });

    test('quarter and year buckets', () async {
      final range = DateRange(DateTime(2025, 11), DateTime(2026, 4));
      final quarters = await q
          .watchIncomeExpense(
            ReportFilter(range: range),
            ReportExclusions.none,
            bucketsFor(range, ReportInterval.quarter),
          )
          .first;
      expect(quarters.map((r) => r.range), [
        DateRange(DateTime(2025, 11), DateTime(2026)),
        DateRange(DateTime(2026), DateTime(2026, 4)),
      ]);
      expect(quarters.map((r) => r.expenseMinor), [1100, 2200 + 4000 + 124000]);

      final all = DateRange(DateTime(2025), DateTime(2027));
      final years = await q
          .watchIncomeExpense(
            ReportFilter(range: all),
            ReportExclusions.none,
            bucketsFor(all, ReportInterval.year),
          )
          .first;
      expect(years.map((r) => r.expenseMinor), [2500 + 1100, 130200]);
    });

    test('summary', () async {
      final s = await q.watchSummary(marchFilter, ReportExclusions.none).first;
      expect(s.incomeMinor, 300000);
      expect(s.expenseMinor, 124000);
    });
  });

  test(
    'net worth with liabilities, opening dates and includeInNetWorth',
    () async {
      final buckets = monthBuckets(
        DateRange(DateTime(2026), DateTime(2026, 4)),
      );
      final points = await q
          .watchNetWorth(buckets, ReportExclusions.none)
          .first;
      expect(points.map((p) => p.assetsMinor), [94200, 70200, 260700]);
      expect(points.map((p) => p.liabilitiesMinor), [
        -500000,
        -480000,
        -484500,
      ]);
      expect(points.last.netWorthMinor, 260700 - 484500);

      final onlyChecking = await q
          .watchNetWorth(
            buckets,
            ReportExclusions.none,
            accountIds: {fx.checking},
          )
          .first;
      expect(onlyChecking.map((p) => p.netWorthMinor), [94200, 70200, 200700]);

      final noLoan = await q
          .watchNetWorth(buckets, ReportExclusions(accountIds: {fx.loan}))
          .first;
      expect(noLoan.last.liabilitiesMinor, -4500);
    },
  );

  test('category trend with roll-up and income categories', () async {
    final range = DateRange(DateTime(2026), DateTime(2026, 4));
    final report = await q.watchCategoryTrend(
      ReportFilter(range: range),
      ReportExclusions.none,
      [fx.groceries, fx.food, fx.salary, 'unknown'],
      bucketsFor(range, ReportInterval.month),
    ).first;
    expect(report.series.map((s) => s.categoryId), [
      fx.groceries,
      fx.food,
      fx.salary,
    ]);
    expect(report.series[0].values, [2200, 4000, 10000]);
    expect(report.series[1].values, [2200, 4000, 19500]);
    expect(report.series[2].values, [0, 0, 300000]);
    expect(report.series[2].kind, CategoryKind.income);
  });

  test('top payees by total, count and average', () async {
    final byTotal = await q
        .watchTopPayees(marchFilter, ReportExclusions.none)
        .first;
    expect(byTotal.map((p) => p.payee), [
      'Landlord',
      'Market',
      'Corner Grocer',
      'Trattoria',
      'Pizza',
    ]);
    final grocer = byTotal.firstWhere((p) => p.payee == 'Corner Grocer');
    expect(grocer.totalMinor, 6000);
    expect(grocer.count, 3);
    expect(grocer.averageMinor, 2000);

    final byCount = await q
        .watchTopPayees(
          marchFilter,
          ReportExclusions.none,
          sort: PayeeSort.count,
          limit: 2,
        )
        .first;
    expect(byCount.map((p) => p.payee), ['Corner Grocer', 'Landlord']);

    final byAvg = await q
        .watchTopPayees(
          marchFilter,
          ReportExclusions.none,
          sort: PayeeSort.average,
        )
        .first;
    expect(byAvg.first.payee, 'Landlord');
    expect(byAvg[1].payee, 'Market');
  });

  test('period comparison against previous period and last year', () async {
    final r = await q.watchComparison(marchFilter, ReportExclusions.none).first;
    expect(r.previous, monthOf(DateTime(2026, 2)));
    expect(r.lastYear, monthOf(DateTime(2025, 3)));
    final food = r.rows.firstWhere((x) => x.categoryId == fx.food);
    expect(food.currentMinor, 19500);
    expect(food.previousMinor, 4000);
    expect(food.lastYearMinor, 2500);
    expect(food.deltaPreviousMinor, 15500);
    expect(food.deltaPreviousBp, 38750);
    expect(r.rows.first.categoryId, fx.rent);
    expect(r.total.currentMinor, 124000);
    expect(r.total.previousMinor, 4000);
  });

  test('dashboard providers', () async {
    final c = testContainer(db);
    addTearDown(c.dispose);
    final sub = c.listen(monthSummaryProvider(march), (_, _) {});
    final top = c.listen(
      topCategoriesProvider((range: march, limit: 2)),
      (_, _) {},
    );
    await c.read(monthSummaryProvider(march).future);
    await c.read(topCategoriesProvider((range: march, limit: 2)).future);
    expect(sub.read().value!.expenseMinor, 124000);
    expect(top.read().value!.map((r) => r.categoryId), [fx.rent, fx.food]);
    c.listen(netWorthSeriesProvider(3), (_, _) {});
    final nw = await c.read(netWorthSeriesProvider(3).future);
    expect(nw, hasLength(3));
  });
}
