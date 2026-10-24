import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/platform/capabilities.dart';
import 'package:personal_finance/features/export/presentation/auto_export_screen.dart';
import 'package:personal_finance/features/export/presentation/csv_options_sheet.dart';
import 'package:personal_finance/features/export/presentation/export_screen.dart';

import '../../helpers/test_app.dart';
import 'auto_export_test.dart' show caps;
import 'export_fixtures.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = newTestDb();
  });

  tearDown(() => db.close());

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    Size size = const Size(400, 900),
    bool folders = true,
    Locale locale = const Locale('en'),
  }) async {
    await tester.runAsync(() => seed(db));
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(
        screen,
        db: db,
        locale: locale,
        overrides: [
          platformCapabilitiesProvider.overrideWithValue(
            caps(folders: folders),
          ),
        ],
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('compact: cards, preview rows and auto-backup shortcut', (
    tester,
  ) async {
    await pumpScreen(tester, const ExportScreen());
    expect(find.text('Export & backup'), findsOneWidget);
    expect(find.text('Transactions as CSV'), findsOneWidget);
    expect(find.text('Export CSV'), findsOneWidget);
    // Preview shows the seeded rows (this year).
    await tester.scrollUntilVisible(
      find.text('Arbeitgeber'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Arbeitgeber'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Automatic backup'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Full backup'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('expanded layout puts the preview beside the options', (
    tester,
  ) async {
    await pumpScreen(tester, const ExportScreen(), size: const Size(1400, 900));
    final options = tester.getTopLeft(find.text('Transactions as CSV'));
    final preview = tester.getTopLeft(find.textContaining('Preview'));
    expect(preview.dx, greaterThan(options.dx + 300));
    expect(preview.dy, closeTo(options.dy, 4));
    await unmount(tester);
  });

  testWidgets('web hides the automatic backup', (tester) async {
    await pumpScreen(tester, const ExportScreen(), folders: false);
    await tester.scrollUntilVisible(
      find.text('Full backup'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Automatic backup'), findsNothing);
    await unmount(tester);
  });

  testWidgets('German strings', (tester) async {
    await pumpScreen(tester, const ExportScreen(), locale: const Locale('de'));
    expect(find.text('Buchungen als CSV'), findsOneWidget);
    expect(find.text('CSV exportieren'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('options sheet changes the column selection', (tester) async {
    await pumpScreen(tester, const ExportScreen());
    expect(find.textContaining('16 of 16 columns'), findsOneWidget);
    await tester.tap(find.text('CSV options'));
    await tester.pumpAndSettle();
    final payee = find.widgetWithText(CheckboxListTile, 'Payee');
    await tester.scrollUntilVisible(
      payee,
      200,
      scrollable: find
          .descendant(
            of: find.byType(CsvOptionsSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(payee);
    await tester.pumpAndSettle();
    await tester.tap(payee);
    await tester.pump();
    expect(tester.widget<CheckboxListTile>(payee).value, isFalse);
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(find.textContaining('15 of 16 columns'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('auto-backup screen', (tester) async {
    await pumpScreen(tester, const AutoExportScreen());
    expect(find.text('Automatic backup settings'), findsOneWidget);
    expect(find.text('No folder chosen'), findsOneWidget);
    final runNow = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Back up now'),
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      ),
    );
    expect(runNow.onPressed, isNull);
    // Keep last N, then the stale-backup warning threshold.
    await tester.tap(find.byTooltip('Decrease').first);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(find.text('9'), findsOneWidget);
    expect(find.text('7 days'), findsOneWidget);
    await tester.tap(find.byTooltip('Increase').last);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(find.text('8 days'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('auto-backup screen on the web', (tester) async {
    await pumpScreen(tester, const AutoExportScreen(), folders: false);
    expect(find.textContaining('not available in the browser'), findsOneWidget);
    await unmount(tester);
  });
}
