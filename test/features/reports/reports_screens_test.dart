import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/features/reports/domain/report_models.dart';
import 'package:personal_finance/features/reports/presentation/report_detail_screen.dart';
import 'package:personal_finance/features/reports/presentation/report_providers.dart';
import 'package:personal_finance/features/reports/presentation/reports_overview_screen.dart';

import '../../helpers/test_app.dart';
import 'report_fixture.dart';

void main() {
  late AppDatabase db;

  Future<void> seed(WidgetTester tester) async {
    await tester.runAsync(() async {
      db = newTestDb();
      await ReportFixture.create(db);
    });
  }

  final clock = reportClockProvider.overrideWithValue(
    () => DateTime(2026, 3, 31),
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> tearDownApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(db.close);
  }

  testWidgets('overview shows a card per report with previews', (tester) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await seed(tester);
    await tester.pumpWidget(
      testApp(const ReportsOverviewScreen(), db: db, overrides: [clock]),
    );
    await settle(tester);

    expect(find.text('Reports'), findsOneWidget);
    expect(find.textContaining('Spending by category'), findsOneWidget);
    expect(find.textContaining('Income vs expenses'), findsOneWidget);
    expect(find.textContaining('Net worth'), findsOneWidget);
    expect(find.textContaining('Category trend'), findsOneWidget);
    expect(find.textContaining('Top payees'), findsOneWidget);
    expect(find.textContaining('Period comparison'), findsOneWidget);
    // Spending preview: March 2026 total and top category in the legend.
    expect(find.textContaining('Rent'), findsWidgets);
    expect(find.text('€1,240.00'), findsWidgets);
    await tearDownApp(tester);
  });

  testWidgets('spending detail shows chart, table and drills down', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await seed(tester);
    await tester.pumpWidget(
      testApp(
        const ReportDetailScreen(type: ReportType.spending),
        db: db,
        overrides: [clock],
      ),
    );
    await settle(tester);

    expect(find.text('March 2026'), findsOneWidget);
    expect(find.text('Data'), findsOneWidget);
    // Table rows (top level, children rolled up).
    expect(find.text('Food'), findsWidgets);
    expect(find.text('€195.00'), findsWidgets);
    expect(find.text('Fun (archived)'), findsOneWidget);
    expect(find.text('Uncategorised'), findsWidgets);
    expect(find.byTooltip('Export CSV'), findsOneWidget);

    // Accessible chart summary.
    expect(
      find.bySemanticsLabel(RegExp('Spending by category, total')),
      findsOneWidget,
    );

    // Drill into Food via the table chevron.
    await tester.tap(find.byTooltip('Show subcategories'));
    await settle(tester);
    expect(find.text('All categories'), findsOneWidget);
    expect(find.text('Groceries'), findsWidgets);
    expect(find.text('€100.00'), findsWidgets);

    // Step to the previous period.
    await tester.tap(find.text('All categories'));
    await settle(tester);
    await tester.tap(find.byTooltip('Previous period'));
    await settle(tester);
    expect(find.text('February 2026'), findsOneWidget);
    expect(find.text('€40.00'), findsWidgets);
    await tearDownApp(tester);
  });

  testWidgets('income vs expense detail on a phone, in German', (tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await seed(tester);
    await tester.pumpWidget(
      testApp(
        const ReportDetailScreen(type: ReportType.incomeExpense),
        db: db,
        overrides: [clock],
        locale: const Locale('de'),
        themeMode: ThemeMode.dark,
      ),
    );
    await settle(tester);
    expect(find.text('Einnahmen und Ausgaben'), findsOneWidget);
    expect(find.text('Sparquote'), findsWidgets);
    expect(find.text('Daten'), findsOneWidget);
    await tearDownApp(tester);
  });

  for (final size in const [Size(390, 1400), Size(1400, 1000)]) {
    testWidgets('every report renders without layout errors at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await seed(tester);
      for (final type in ReportType.values) {
        await tester.pumpWidget(
          testApp(
            ReportDetailScreen(type: type),
            db: db,
            overrides: [clock],
            themeMode: size.width > 1000 ? ThemeMode.dark : ThemeMode.light,
          ),
        );
        await settle(tester);
        expect(tester.takeException(), isNull, reason: type.name);
        expect(find.text('Data'), findsOneWidget, reason: type.name);
        expect(
          find.text('No data for this period'),
          findsNothing,
          reason: type.name,
        );
      }
      await tester.pumpWidget(
        testApp(const ReportsOverviewScreen(), db: db, overrides: [clock]),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
      await tearDownApp(tester);
    });
  }
}
