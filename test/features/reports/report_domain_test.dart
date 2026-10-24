import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/calendar/budget_period.dart';
import 'package:personal_finance/core/csv/csv_writer.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/features/reports/data/report_queries.dart';
import 'package:personal_finance/features/reports/domain/report_links.dart';
import 'package:personal_finance/features/reports/domain/report_models.dart';
import 'package:personal_finance/features/reports/domain/report_periods.dart';
import 'package:personal_finance/features/reports/domain/report_table.dart';

import '../../helpers/test_app.dart';
import 'report_fixture.dart';

void main() {
  group('periods', () {
    final today = DateTime(2026, 10, 23);

    test('presets', () {
      expect(
        reportPeriodRange(ReportPeriod.thisMonth, today),
        DateRange(DateTime(2026, 10), DateTime(2026, 11)),
      );
      expect(
        reportPeriodRange(ReportPeriod.lastMonth, DateTime(2026, 1, 5)),
        DateRange(DateTime(2025, 12), DateTime(2026)),
      );
      expect(
        reportPeriodRange(ReportPeriod.last12Months, today),
        DateRange(DateTime(2025, 11), DateTime(2026, 11)),
      );
      expect(
        reportPeriodRange(ReportPeriod.yearToDate, today),
        DateRange(DateTime(2026), DateTime(2026, 10, 24)),
      );
      expect(
        reportPeriodRange(ReportPeriod.lastYear, today),
        DateRange(DateTime(2025), DateTime(2026)),
      );
    });

    test('shifting by months, years and days', () {
      final jan = monthOf(DateTime(2026));
      expect(shiftRange(jan, -1), monthOf(DateTime(2025, 12)));
      final q = DateRange(DateTime(2026), DateTime(2026, 4));
      expect(shiftRange(q, 1), DateRange(DateTime(2026, 4), DateTime(2026, 7)));
      final ytd = DateRange(DateTime(2026), DateTime(2026, 10, 24));
      expect(
        shiftRange(ytd, -1),
        DateRange(DateTime(2025), DateTime(2025, 10, 24)),
      );
      final week = DateRange(DateTime(2026, 3, 9), DateTime(2026, 3, 16));
      expect(
        shiftRange(week, -1),
        DateRange(DateTime(2026, 3, 2), DateTime(2026, 3, 9)),
      );
      final (cur, prev, ly) = comparisonRanges(monthOf(DateTime(2026, 3)));
      expect(cur, monthOf(DateTime(2026, 3)));
      expect(prev, monthOf(DateTime(2026, 2)));
      expect(ly, monthOf(DateTime(2025, 3)));
    });

    test('buckets are clipped and follow the fiscal year', () {
      final r = DateRange(DateTime(2026, 1, 15), DateTime(2026, 3, 10));
      expect(bucketsFor(r, ReportInterval.month), [
        DateRange(DateTime(2026, 1, 15), DateTime(2026, 2)),
        DateRange(DateTime(2026, 2), DateTime(2026, 3)),
        DateRange(DateTime(2026, 3), DateTime(2026, 3, 10)),
      ]);
      final year = DateRange(DateTime(2026), DateTime(2027));
      expect(
        bucketsFor(
          year,
          ReportInterval.quarter,
          fiscalYearStartMonth: 4,
        ).map((b) => b.start),
        [
          DateTime(2026),
          DateTime(2026, 4),
          DateTime(2026, 7),
          DateTime(2026, 10),
        ],
      );
      expect(
        bucketsFor(year, ReportInterval.quarter).first.end,
        DateTime(2026, 4),
      );
      final budget = BudgetPeriods(const BudgetPeriodConfig(startDay: 25));
      final b = bucketsFor(
        DateRange(DateTime(2026), DateTime(2026, 3)),
        ReportInterval.budgetPeriod,
        budget: budget,
      );
      expect(b.map((x) => x.start), [
        DateTime(2026),
        DateTime(2026, 1, 25),
        DateTime(2026, 2, 25),
      ]);
    });
  });

  test('transactions link carries range, category and filters', () {
    final link = transactionsLocation(
      range: monthOf(DateTime(2026, 3)),
      filter: ReportFilter(
        range: monthOf(DateTime(2026, 3)),
        accountIds: const {'b', 'a'},
        tagIds: const {'t'},
      ),
      kind: CategoryKind.expense,
      categoryId: 'food',
      childIds: const ['groceries', 'restaurants'],
    );
    final uri = Uri.parse(link);
    expect(uri.path, '/transactions');
    expect(uri.queryParameters, {
      'from': '2026-03-01',
      'to': '2026-03-31',
      'type': 'expense',
      'category': 'food,groceries,restaurants',
      'account': 'a,b',
      'tag': 't',
    });
    final none = Uri.parse(
      transactionsLocation(
        range: monthOf(DateTime(2026, 3)),
        uncategorized: true,
        payee: 'Corner Grocer',
      ),
    );
    expect(none.queryParameters['category'], uncategorizedParam);
    expect(none.queryParameters['payee'], 'Corner Grocer');
  });

  test('CSV export of the spending report honours the CSV settings', () async {
    final db = newTestDb();
    addTearDown(db.close);
    final fx = await ReportFixture.create(db);
    final rows = await ReportQueries(db)
        .watchByCategory(
          ReportFilter(range: monthOf(DateTime(2026, 3))),
          ReportExclusions.none,
        )
        .first;
    final table = ReportTable(
      columns: const [
        ReportColumn('Category'),
        ReportColumn('Amount', numeric: true),
        ReportColumn('Share', numeric: true),
        ReportColumn('Date'),
      ],
      rows: [
        for (final r in rows)
          ReportRow([
            ReportCell.text(r.name ?? 'Uncategorised'),
            ReportCell.money(r.amountMinor),
            ReportCell.percent(r.categoryId == fx.rent ? 8065 : null),
            ReportCell.date(DateTime(2026, 3, 31)),
          ]),
        const ReportRow([
          ReportCell.text('Refund; "net"'),
          ReportCell.money(-1050),
          ReportCell.percent(null),
          ReportCell.text(''),
        ]),
      ],
    );

    final de = reportTableCsvBytes(
      table,
      const CsvOptions(
        dateFormat: 'dd.MM.yyyy',
        decimalSeparator: DecimalSeparator.comma,
      ),
    );
    expect(de.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
    expect(
      utf8.decode(de.sublist(3)),
      'Category;Amount;Share;Date\r\n'
      'Rent;1000,00;80,65;31.03.2026\r\n'
      'Food;195,00;;31.03.2026\r\n'
      'Fun;40,00;;31.03.2026\r\n'
      'Uncategorised;5,00;;31.03.2026\r\n'
      '"Refund; ""net""";-10,50;;\r\n',
    );

    final en = reportTableCsvBytes(
      table,
      const CsvOptions(
        delimiter: CsvDelimiter.comma,
        encoding: CsvEncoding.utf8,
        decimalSeparator: DecimalSeparator.point,
      ),
    );
    final text = utf8.decode(en);
    expect(
      text,
      startsWith(
        'Category,Amount,Share,Date\r\nRent,1000.00,80.65,2026-03-31\r\n',
      ),
    );
  });
}
