import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/app/theme/app_theme.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/security/app_lock_gate.dart';
import 'package:personal_finance/features/security/data/secret_store.dart';
import 'package:personal_finance/features/security/presentation/lock_screen.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

import '../../helpers/test_app.dart';
import 'security_test_utils.dart';

void main() {
  late AppDatabase db;
  late MemorySecretStore store;
  late SettingsSnapshot initial;

  Future<void> seed(WidgetTester tester, {required bool lockOn}) async {
    await tester.runAsync(() async {
      db = newTestDb();
      store = MemorySecretStore();
      if (lockOn) {
        storePin(store, '2468');
        final c = testContainer(db);
        await c
            .read(settingsProvider.notifier)
            .set(SecuritySettings.appLock, true);
        c.dispose();
      }
      initial = await loadSettings(db);
    });
  }

  Widget app() => ProviderScope(
    overrides: [
      ...dbOverrides(db, 'test-device', clock: testClock()),
      initialSettingsProvider.overrideWithValue(initial),
      ...securityOverrides(store: store),
    ],
    child: MaterialApp(
      theme: const AppTheme().light(),
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => AppLockGate(child: child!),
      home: const Scaffold(body: Text('Balance 1.234,56 €')),
    ),
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> tearDownApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(db.close);
  }

  Future<void> tapPin(WidgetTester tester, String pin) async {
    for (final d in pin.split('')) {
      await tester.tap(find.byKey(ValueKey('pin-key-$d')));
      await tester.pump();
    }
    await settle(tester);
  }

  testWidgets('no lock screen when the lock is off', (tester) async {
    await seed(tester, lockOn: false);
    await tester.pumpWidget(app());
    await settle(tester);
    expect(find.byType(LockScreen), findsNothing);
    expect(find.text('Balance 1.234,56 €'), findsOneWidget);
    await tearDownApp(tester);
  });

  testWidgets('shows the lock screen and unlocks with the right PIN', (
    tester,
  ) async {
    await seed(tester, lockOn: true);
    await tester.pumpWidget(app());
    await settle(tester);

    expect(find.byType(LockScreen), findsOneWidget);
    expect(find.text('Quiet Ledger is locked'), findsOneWidget);
    // The app content is not painted or reachable while locked.
    expect(find.text('Balance 1.234,56 €'), findsNothing);

    await tapPin(tester, '1111');
    expect(find.byType(LockScreen), findsOneWidget);
    expect(find.textContaining('Wrong PIN'), findsOneWidget);
    expect(find.textContaining('4 attempts left'), findsOneWidget);

    await tapPin(tester, '2468');
    expect(find.byType(LockScreen), findsNothing);
    expect(find.text('Balance 1.234,56 €'), findsOneWidget);
    await tearDownApp(tester);
  });

  testWidgets('keyboard input works on the lock screen', (tester) async {
    await seed(tester, lockOn: true);
    await tester.pumpWidget(app());
    await settle(tester);
    const keys = {
      '2': LogicalKeyboardKey.digit2,
      '4': LogicalKeyboardKey.digit4,
      '6': LogicalKeyboardKey.digit6,
      '8': LogicalKeyboardKey.digit8,
    };
    for (final e in keys.entries) {
      await tester.sendKeyEvent(e.value, character: e.key);
      await tester.pump();
    }
    await settle(tester);
    expect(find.byType(LockScreen), findsNothing);
    await tearDownApp(tester);
  });
}
