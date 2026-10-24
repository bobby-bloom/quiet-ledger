import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/app/app.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/forecast/presentation/forecast_providers.dart';
import 'package:personal_finance/features/security/data/secret_store.dart';

import '../helpers/test_app.dart';

/// Full app: first start on an empty database goes through onboarding and
/// lands on the dashboard with the account and default categories created.
void main() {
  late AppDatabase db;

  Future<void> settle(WidgetTester tester, [int rounds = 8]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final f = find.text(text);
    await tester.ensureVisible(f.first);
    await tester.tap(f.first);
    await settle(tester);
  }

  for (final size in const [Size(390, 844), Size(1440, 960)]) {
    testWidgets('onboarding → dashboard at ${size.width.toInt()} px', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      db = newTestDb();
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...dbOverrides(db, 'test-device', clock: testClock()),
              initialSettingsProvider.overrideWithValue(
                SettingsSnapshot({
                  SettingsSnapshot.rowId(
                    GeneralSettings.language.key,
                    'global',
                  ): 'en',
                }),
              ),
              forecastRunnerProvider.overrideWithValue(
                const ForecastRunner.inline(),
              ),
              secretStoreProvider.overrideWithValue(MemorySecretStore()),
            ],
            child: const PersonalFinanceApp(),
          ),
        );
        await settle(tester);

        expect(find.text('Get started'), findsOneWidget);
        await tapText(tester, 'Get started');
        expect(find.text('Language & formats'), findsOneWidget);
        await tapText(tester, 'Next');
        expect(find.text('Budget period'), findsOneWidget);
        await tapText(tester, 'Next');
        expect(find.text('How do you want to start?'), findsOneWidget);
        await tapText(tester, 'Next');
        expect(find.text('Your accounts'), findsOneWidget);
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Current balance'),
          '1.250,00',
        );
        await tapText(tester, 'Next');
        expect(find.text('Protect your data'), findsOneWidget);
        await tapText(tester, 'Not now, finish');
        await settle(tester, 12);

        expect(
          find.textContaining('Net worth', findRichText: true),
          findsWidgets,
        );
        expect(tester.takeException(), isNull);

        final accounts = await tester.runAsync(
          () => db.select(db.accounts).get(),
        );
        expect(accounts!.single.name, 'Checking account');
        expect(accounts.single.openingBalanceMinor, 125000);
        final cats = await tester.runAsync(
          () => db.select(db.categories).get(),
        );
        expect(cats!.length, greaterThan(10));
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
        unawaited(db.close());
        await tester.pump(const Duration(seconds: 1));
      }
    });
  }
}
