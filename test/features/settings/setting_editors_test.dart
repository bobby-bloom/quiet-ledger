import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/setting_def.dart';
import 'package:personal_finance/features/settings/presentation/setting_tiles.dart';

import '../../helpers/test_app.dart';
import '../security/security_test_utils.dart';
import 'settings_test_utils.dart';

void main() {
  late AppDatabase db;

  Future<void> pumpTile(WidgetTester tester, SettingDef<Object?> def) async {
    await tester.runAsync(() async => db = newTestDb());
    await tester.pumpWidget(
      testApp(
        Scaffold(body: ListView(children: [SettingTile(def)])),
        db: db,
        overrides: securityOverrides(),
      ),
    );
    await settle(tester);
  }

  testWidgets('switch editor', (tester) async {
    await pumpTile(tester, AppearanceSettings.showCents);
    expect(find.text('Show cents'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await settle(tester);
    final s = await storedSettings(tester, db);
    expect(s.get(AppearanceSettings.showCents), isFalse);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    await tearDownApp(tester, db);
  });

  testWidgets('choice editor: segmented for ≤ 3 short options', (tester) async {
    await pumpTile(tester, AppearanceSettings.themeMode);
    expect(find.byType(SegmentedButton<String>), findsOneWidget);
    await tester.tap(find.text('Dark'));
    await settle(tester);
    final s = await storedSettings(tester, db);
    expect(s.get(AppearanceSettings.themeMode), AppThemeMode.dark);
    await tearDownApp(tester, db);
  });

  testWidgets('choice editor: radio list for many options', (tester) async {
    await pumpTile(tester, BudgetSettings.periodType);
    expect(find.byType(SegmentedButton<String>), findsNothing);
    expect(find.text('Monthly'), findsOneWidget);
    await tester.tap(find.text('Period'));
    await settle(tester);
    expect(find.byType(RadioListTile<String>), findsNWidgets(5));
    await tester.tap(find.text('Quarterly'));
    await settle(tester);
    final s = await storedSettings(tester, db);
    expect(s.get(BudgetSettings.periodType), BudgetPeriodType.quarterly);
    expect(find.text('Quarterly'), findsOneWidget);
    await tearDownApp(tester, db);
  });

  testWidgets('int editor: stepper and typed value with validation', (
    tester,
  ) async {
    await pumpTile(tester, EntrySettings.recentCategories);
    expect(find.text('6'), findsOneWidget);
    await tester.tap(find.byTooltip('Increase'));
    await settle(tester);
    expect(
      (await storedSettings(tester, db)).get(EntrySettings.recentCategories),
      7,
    );

    await tester.tap(find.text('7'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), '120');
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(find.text('Enter a value from 0 to 20'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '12');
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(
      (await storedSettings(tester, db)).get(EntrySettings.recentCategories),
      12,
    );
    await tearDownApp(tester, db);
  });

  testWidgets('int editor: slider with unit', (tester) async {
    await pumpTile(tester, BudgetSettings.warnThreshold);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('80 %'), findsOneWidget);
    await tester.drag(find.byType(Slider), const Offset(-2000, 0));
    await settle(tester);
    expect(
      (await storedSettings(tester, db)).get(BudgetSettings.warnThreshold),
      1,
    );
    await tearDownApp(tester, db);
  });

  testWidgets('money editor', (tester) async {
    await pumpTile(tester, ForecastSettings.lowBalanceThreshold);
    await tester.enterText(find.byType(TextField), '25,50');
    await tester.pump(const Duration(milliseconds: 600));
    await settle(tester);
    expect(
      (await storedSettings(
        tester,
        db,
      )).get(ForecastSettings.lowBalanceThreshold),
      2550,
    );
    await tearDownApp(tester, db);
  });

  testWidgets('percent editor converts % to basis points and validates', (
    tester,
  ) async {
    await pumpTile(tester, ForecastSettings.inflationBp);
    final field = find.byKey(const ValueKey('percent-forecast.inflationBp'));
    expect(tester.widget<TextField>(field).controller!.text, '2');
    await tester.enterText(field, '35');
    await tester.pump(const Duration(milliseconds: 600));
    await settle(tester);
    expect(find.textContaining('From −5 % to 20 %'), findsWidgets);
    expect(
      (await storedSettings(tester, db)).isSet(ForecastSettings.inflationBp),
      isFalse,
    );
    await tester.enterText(field, '2,5');
    await tester.pump(const Duration(milliseconds: 600));
    await settle(tester);
    expect(
      (await storedSettings(tester, db)).get(ForecastSettings.inflationBp),
      250,
    );
    await tearDownApp(tester, db);
  });

  testWidgets('text editor with validation', (tester) async {
    final def = SettingDef.string(
      key: 'test.nickname',
      section: SettingSection.general,
      defaultValue: '',
      label: (l) => l.setDeviceName,
      validate: (v) => v.length > 10 ? 'too long' : null,
    );
    await pumpTile(tester, def);
    await tester.enterText(find.byType(TextField), 'way too long a name');
    await tester.pump(const Duration(milliseconds: 600));
    await settle(tester);
    expect(find.text('This value is not allowed'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Laptop');
    await tester.pump(const Duration(milliseconds: 600));
    await settle(tester);
    expect((await storedSettings(tester, db)).get(def), 'Laptop');
    await tearDownApp(tester, db);
  });

  testWidgets('colour editor: HEX input', (tester) async {
    await pumpTile(tester, AppearanceSettings.customAccent);
    expect(find.text('#1F5A53'), findsOneWidget);
    await tester.tap(find.text('Custom accent'));
    await settle(tester);
    expect(find.text('Presets'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('color-hex')), '#336699');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(
      (await storedSettings(tester, db)).get(AppearanceSettings.customAccent),
      0xFF336699,
    );
    await tearDownApp(tester, db);
  });

  testWidgets('time editor opens the time picker', (tester) async {
    await pumpTile(tester, RecurringSettings.notificationTime);
    expect(find.text('9:00 AM'), findsOneWidget);
    await tester.tap(find.text('Notification time'));
    await settle(tester);
    // Switch to text input and type 07:30.
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await settle(tester);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '7');
    await tester.enterText(fields.at(1), '30');
    await tester.tap(find.text('OK'));
    await settle(tester);
    expect(
      (await storedSettings(
        tester,
        db,
      )).get(RecurringSettings.notificationTime),
      7 * 60 + 30,
    );
    await tearDownApp(tester, db);
  });

  testWidgets('ordered list editor (reorderable)', (tester) async {
    await pumpTile(tester, EntrySettings.fieldOrder);
    expect(find.byType(ReorderableListView), findsOneWidget);
    await tester.tap(find.text('Note'));
    await settle(tester);
    await tester.tap(find.text('Tags'));
    await settle(tester);
    expect((await storedSettings(tester, db)).get(EntrySettings.fieldOrder), [
      'amount',
      'category',
      'account',
      'date',
      'payee',
      'tags',
    ]);
    await tearDownApp(tester, db);
  });

  testWidgets('ordered list editor (plain checklist)', (tester) async {
    await pumpTile(tester, EntrySettings.requiredFields);
    expect(find.byType(ReorderableListView), findsNothing);
    await tester.tap(find.text('Category'));
    await settle(tester);
    expect(
      (await storedSettings(tester, db)).get(EntrySettings.requiredFields),
      ['amount', 'category', 'account'],
    );
    await tearDownApp(tester, db);
  });

  testWidgets('custom editor: tag multi-picker', (tester) async {
    await tester.runAsync(() async {
      db = newTestDb();
      final c = testContainer(db);
      await c
          .read(syncWriterProvider)
          .insert(
            db.tags,
            const TagsCompanion(name: Value('vacation')),
            id: 't1',
          );
      c.dispose();
    });
    await tester.pumpWidget(
      testApp(
        Scaffold(body: SettingTile(ReportSettings.excludedTags)),
        db: db,
        overrides: securityOverrides(),
      ),
    );
    await settle(tester);
    expect(find.text('None'), findsOneWidget);
    await tester.tap(find.text('Excluded tags'));
    await settle(tester);
    await tester.tap(find.text('#vacation'));
    await tester.pump();
    await tester.tap(find.text('Done'));
    await settle(tester);
    expect(
      (await storedSettings(tester, db)).get(ReportSettings.excludedTags),
      ['t1'],
    );
    expect(find.text('vacation'), findsOneWidget);
    await tearDownApp(tester, db);
  });
}
