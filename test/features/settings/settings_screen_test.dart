import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/setting_def.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/export/data/safety_copies.dart';
import 'package:personal_finance/features/settings/presentation/section_view.dart';
import 'package:personal_finance/features/settings/presentation/setting_tiles.dart';
import 'package:personal_finance/features/settings/presentation/settings_catalog.dart';

import '../../helpers/test_app.dart';
import 'settings_test_utils.dart';

void main() {
  late AppDatabase db;

  Future<void> seed(
    WidgetTester tester, [
    Future<void> Function(SettingsController c)? write,
  ]) async {
    await tester.runAsync(() async {
      db = newTestDb();
      if (write != null) {
        final c = testContainer(db);
        await write(c.read(settingsProvider.notifier));
        c.dispose();
      }
    });
  }

  testWidgets('phone: sections with summaries, search jumps to setting', (
    tester,
  ) async {
    setWindow(tester, const Size(400, 900));
    await seed(tester);
    await tester.pumpWidget(settingsRouterApp(db));
    await settle(tester);

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('General'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('System'), findsOneWidget); // appearance summary

    await tester.enterText(
      find.byKey(const ValueKey('settings-search')),
      'weekend',
    );
    await settle(tester);
    expect(find.text('Weekend & holiday shift'), findsOneWidget);
    expect(find.text('Appearance'), findsNothing);

    await tester.tap(find.text('Weekend & holiday shift'));
    await settle(tester);
    // Section page with its own app bar and the setting highlighted.
    expect(find.widgetWithText(AppBar, 'Budgets'), findsOneWidget);
    expect(find.text('Weekend & holiday shift'), findsOneWidget);
    final highlight = tester.widget<SettingHighlight>(
      find.ancestor(
        of: find.text('Weekend & holiday shift'),
        matching: find.byType(SettingHighlight),
      ),
    );
    expect(highlight.active, isTrue);
    await tearDownApp(tester, db);
  });

  testWidgets('search in German, no results message', (tester) async {
    setWindow(tester, const Size(400, 900));
    await seed(tester);
    await tester.pumpWidget(settingsRouterApp(db, locale: const Locale('de')));
    await settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey('settings-search')),
      'dunkel',
    );
    await settle(tester);
    expect(find.text('Design'), findsWidgets);
    await tester.enterText(
      find.byKey(const ValueKey('settings-search')),
      'xyzzy',
    );
    await settle(tester);
    expect(find.textContaining('xyzzy'), findsWidgets);
    await tearDownApp(tester, db);
  });

  testWidgets('desktop: two panes', (tester) async {
    setWindow(tester, const Size(1280, 900));
    await seed(tester);
    await tester.pumpWidget(settingsRouterApp(db));
    await settle(tester);
    // List on the left, first section on the right.
    expect(find.text('Language'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('page-appearance')));
    await settle(tester);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Language'), findsNothing);
    // Search result opens in the right pane.
    await tester.enterText(
      find.byKey(const ValueKey('settings-search')),
      'lock on start',
    );
    await settle(tester);
    expect(find.text('Lock on start'), findsNothing); // hidden: lock is off
    await tester.enterText(
      find.byKey(const ValueKey('settings-search')),
      'calculator',
    );
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('hit-entry.calculatorKeypad')));
    await settle(tester);
    expect(find.text('Quick-add field order'), findsOneWidget);
    await tearDownApp(tester, db);
  });

  testWidgets('purge with nothing to purge takes no safety copy', (
    tester,
  ) async {
    setWindow(tester, const Size(1280, 900));
    await seed(tester);
    await tester.pumpWidget(
      testApp(
        const Scaffold(
          body: SettingsSectionView(
            page: SettingsPage.section(SettingSection.data),
          ),
        ),
        db: db,
      ),
    );
    await settle(tester);
    await tester.ensureVisible(find.text('Purge deleted items'));
    await tester.tap(find.text('Purge deleted items'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Purge'));
    await settle(tester);
    expect(find.text('Nothing to purge'), findsOneWidget);
    final copies = await tester.runAsync(() => watchSafetyCopies(db).first);
    expect(copies, isEmpty);
    await tearDownApp(tester, db);
  });

  testWidgets('reset section restores defaults and keeps hidden values', (
    tester,
  ) async {
    setWindow(tester, const Size(1280, 900));
    await seed(tester, (c) async {
      await c.set(BudgetSettings.warnThreshold, 95);
      await c.set(BudgetSettings.mode, BudgetMode.envelope);
      await c.set(GeneralSettings.onboardingDone, true);
      await c.set(GeneralSettings.firstDayOfWeek, FirstDayOfWeek.sunday);
    });
    await tester.pumpWidget(
      testApp(
        const Scaffold(
          body: SettingsSectionView(
            page: SettingsPage.section(SettingSection.budgets),
          ),
        ),
        db: db,
      ),
    );
    await settle(tester);
    expect(find.text('95 %'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reset-section')));
    await settle(tester);
    expect(find.text('Reset “Budgets”?'), findsOneWidget);
    await tester.tap(find.text('Reset'));
    await settle(tester);
    var s = await storedSettings(tester, db);
    expect(s.get(BudgetSettings.warnThreshold), 80);
    expect(s.get(BudgetSettings.mode), BudgetMode.tracking);
    expect(find.text('80 %'), findsOneWidget);

    // General: the hidden onboarding flag survives a reset.
    await tester.runAsync(() async {
      final c = testContainer(db);
      await resetSettingsPage(
        c.read(settingsProvider.notifier),
        SettingSection.general,
      );
      c.dispose();
    });
    s = await storedSettings(tester, db);
    expect(s.get(GeneralSettings.firstDayOfWeek), FirstDayOfWeek.locale);
    expect(s.get(GeneralSettings.onboardingDone), isTrue);
    await tearDownApp(tester, db);
  });

  testWidgets('budgets section with the module off offers to turn it on', (
    tester,
  ) async {
    await seed(
      tester,
      (c) => c.set(NavigationSettings.module(AppModule.budgets), false),
    );
    await tester.pumpWidget(
      testApp(
        const Scaffold(
          body: SettingsSectionView(
            page: SettingsPage.section(SettingSection.budgets),
          ),
        ),
        db: db,
      ),
    );
    await settle(tester);
    expect(find.text('Period'), findsNothing);
    expect(find.textContaining('switched off'), findsOneWidget);
    await tester.tap(find.text('Turn on'));
    await settle(tester);
    expect(find.text('Period'), findsOneWidget);
    await tearDownApp(tester, db);
  });

  testWidgets('navigation: tab editor constraints and module toggles', (
    tester,
  ) async {
    setWindow(tester, const Size(1280, 1400));
    await seed(tester);
    await tester.pumpWidget(
      testApp(
        const Scaffold(
          body: SettingsSectionView(
            page: SettingsPage.section(SettingSection.navigation),
          ),
        ),
        db: db,
      ),
    );
    await settle(tester);

    CheckboxListTile tile(String label) => tester.widget<CheckboxListTile>(
      find.ancestor(
        of: find.text(label),
        matching: find.byType(CheckboxListTile),
      ),
    );
    // Default: 4 tabs + More = 5 → no more can be added.
    expect(tile('Accounts').value, isFalse);
    expect(tile('Accounts').onChanged, isNull);
    expect(find.text('Always shown, always last'), findsOneWidget);

    await tester.tap(find.text('Plan'));
    await settle(tester);
    await tester.tap(find.text('Accounts'));
    await settle(tester);
    expect((await storedSettings(tester, db)).get(NavigationSettings.tabs), [
      'home',
      'transactions',
      'forecast',
      'accounts',
      'more',
    ]);

    // Down to 2 (incl. More): the last tab cannot be removed.
    for (final t in ['Transactions', 'Forecast', 'Accounts']) {
      await tester.tap(find.text(t).first);
      await settle(tester);
    }
    expect((await storedSettings(tester, db)).get(NavigationSettings.tabs), [
      'home',
      'more',
    ]);
    expect(tile('Home').onChanged, isNull);

    await tester.tap(find.text('Enable Goals'));
    await settle(tester);
    expect(
      (await storedSettings(tester, db)).moduleEnabled(AppModule.goals),
      isFalse,
    );
    await tearDownApp(tester, db);
  });
}
