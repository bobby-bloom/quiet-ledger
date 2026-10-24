import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/calendar/budget_period.dart';
import 'package:personal_finance/features/reports/data/report_queries.dart';
import 'package:personal_finance/features/reports/domain/report_models.dart';
import 'package:personal_finance/features/reports/domain/report_periods.dart';

import '../../helpers/test_app.dart';

/// Smoke test: the main report queries stay fast on a large ledger. Rows
/// are inserted with raw SQL (tests only) to keep the setup quick.
void main() {
  test('main queries finish quickly with 50k transactions', () async {
    final db = newTestDb();
    addTearDown(db.close);
    const n = 50000;
    final rnd = Random(42);
    final start = DateTime(2024);

    await db.transaction(() async {
      Future<void> exec(String sql, List<Object?> args) =>
          db.customStatement(sql, args);
      const meta = "1, 'hlc', NULL, 'dev'";
      for (var a = 0; a < 4; a++) {
        await exec(
          'INSERT INTO accounts (id, name, type, currency, '
          'opening_balance_minor, opening_date, include_in_net_worth, '
          'include_in_budgets, include_in_forecast, archived, sort_order, '
          'created_at, updated_at, deleted_at, origin_device_id) '
          "VALUES (?, ?, ?, 'EUR', 100000, ?, 1, 1, 1, 0, 0, $meta)",
          [
            'acc$a',
            'Account $a',
            if (a == 3) 'creditCard' else 'checking',
            start.millisecondsSinceEpoch ~/ 1000,
          ],
        );
      }
      for (var c = 0; c < 30; c++) {
        await exec(
          'INSERT INTO categories (id, parent_id, name, kind, archived, '
          'sort_order, favourite, created_at, updated_at, deleted_at, '
          'origin_device_id) VALUES (?, ?, ?, ?, 0, 0, 0, $meta)',
          [
            'cat$c',
            if (c >= 10) 'cat${c % 10}' else null,
            'Category $c',
            if (c == 0) 'income' else 'expense',
          ],
        );
      }
      for (var i = 0; i < n; i++) {
        final date = DateTime(start.year, start.month, start.day + i % 1000);
        final income = i % 20 == 0;
        final split = i % 50 == 1;
        final amount = income ? 250000 : -(100 + rnd.nextInt(20000));
        await exec(
          'INSERT INTO transactions (id, account_id, date, amount_minor, '
          'currency, type, payee, category_id, status, created_at, '
          "updated_at, deleted_at, origin_device_id) VALUES (?, ?, ?, ?, 'EUR', "
          "?, ?, ?, 'cleared', $meta)",
          [
            't$i',
            'acc${i % 4}',
            date.millisecondsSinceEpoch ~/ 1000,
            amount,
            if (income) 'income' else 'expense',
            'Payee ${rnd.nextInt(300)}',
            if (income)
              'cat0'
            else if (split)
              null
            else
              'cat${1 + rnd.nextInt(29)}',
          ],
        );
        if (split) {
          for (var s = 0; s < 2; s++) {
            await exec(
              'INSERT INTO transaction_splits (id, transaction_id, '
              'category_id, amount_minor, sort_order, created_at, updated_at, '
              'deleted_at, origin_device_id) VALUES (?, ?, ?, ?, 0, $meta)',
              ['s${i}_$s', 't$i', 'cat${11 + s}', if (s == 0) amount else 0],
            );
          }
        }
        if (i % 10 == 0) {
          await exec(
            'INSERT INTO transaction_tags (id, transaction_id, tag_id, '
            'created_at, updated_at, deleted_at, origin_device_id) VALUES '
            '(?, ?, ?, $meta)',
            ['tt$i', 't$i', 'tag${i % 3}'],
          );
        }
      }
    });
    final count = await db
        .customSelect('SELECT COUNT(*) AS c FROM transactions')
        .getSingle();
    expect(count.read<int>('c'), n);

    final q = ReportQueries(db);
    final year = DateRange(DateTime(2025), DateTime(2026));
    final f = ReportFilter(range: year);
    const ex = ReportExclusions(categoryIds: {'cat5'}, tagIds: {'tag1'});

    Future<Duration> time(Future<Object?> Function() run) async {
      final sw = Stopwatch()..start();
      await run();
      return sw.elapsed;
    }

    final timings = <String, Duration>{
      'byCategory': await time(() => q.watchByCategory(f, ex).first),
      'drill': await time(
        () => q.watchByCategory(f, ex, parentId: 'cat1').first,
      ),
      'incomeExpense': await time(
        () => q
            .watchIncomeExpense(f, ex, bucketsFor(year, ReportInterval.month))
            .first,
      ),
      'netWorth': await time(
        () => q
            .watchNetWorth(
              monthBuckets(DateRange(DateTime(2024), DateTime(2026, 10))),
              ex,
            )
            .first,
      ),
      'trend': await time(
        () => q.watchCategoryTrend(f, ex, [
          'cat1',
          'cat2',
          'cat11',
        ], bucketsFor(year, ReportInterval.month)).first,
      ),
      'payees': await time(() => q.watchTopPayees(f, ex).first),
      'comparison': await time(
        () => q
            .watchComparison(
              ReportFilter(range: monthOf(DateTime(2025, 6))),
              ex,
            )
            .first,
      ),
      'tagFilter': await time(
        () => q
            .watchByCategory(
              f.copyWith(tagIds: {'tag0'}),
              ReportExclusions.none,
            )
            .first,
      ),
    };
    // Generous bound for slow CI machines; typically far below.
    for (final e in timings.entries) {
      expect(
        e.value,
        lessThan(const Duration(seconds: 1)),
        reason: '${e.key} took ${e.value.inMilliseconds} ms',
      );
    }
    // Timings help spot regressions in CI logs.
    // ignore: avoid_print
    print({for (final e in timings.entries) e.key: e.value.inMilliseconds});

    final rows = await q.watchByCategory(f, ReportExclusions.none).first;
    expect(rows, isNotEmpty);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
