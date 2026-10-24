import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/setting_def.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/security/data/secret_store.dart';
import 'package:personal_finance/features/settings/presentation/section_view.dart';
import 'package:personal_finance/features/settings/presentation/settings_catalog.dart';

import '../../helpers/test_app.dart';
import '../security/security_test_utils.dart';
import 'settings_test_utils.dart';

void main() {
  late AppDatabase db;

  Future<void> tapPin(WidgetTester tester, String pin) async {
    for (final d in pin.split('')) {
      await tester.tap(find.byKey(ValueKey('pin-key-$d')));
      await tester.pump();
    }
  }

  testWidgets('enable app lock with a PIN, then turn it off again', (
    tester,
  ) async {
    setWindow(tester, const Size(500, 1000));
    await tester.runAsync(() async => db = newTestDb());
    final store = MemorySecretStore();
    await tester.pumpWidget(
      testApp(
        const Scaffold(
          body: SettingsSectionView(
            page: SettingsPage.section(SettingSection.security),
          ),
        ),
        db: db,
        overrides: securityOverrides(store: store),
      ),
    );
    await settle(tester);
    expect(find.text('App lock'), findsOneWidget);
    expect(find.text('Lock now'), findsNothing);

    await tester.tap(find.byType(Switch));
    await settle(tester);
    expect(find.text('Set up app lock'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await settle(tester);
    expect(find.text('Choose a PIN'), findsOneWidget);
    await tapPin(tester, '135');
    // Too short: Next stays disabled.
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Next'))
          .onPressed,
      isNull,
    );
    await tapPin(tester, '7');
    await tester.tap(find.text('Next'));
    await settle(tester);
    expect(find.text('Enter the PIN again'), findsOneWidget);
    await tapPin(tester, '1358');
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(find.text("The entries don't match. Try again."), findsOneWidget);
    await tapPin(tester, '1357');
    await tester.tap(find.text('Next'));
    await settle(tester);
    await tapPin(tester, '1357');
    await tester.tap(find.text('Save'));
    await settle(tester, 12);

    expect(find.text('Set up app lock'), findsNothing);
    expect(find.text('Change PIN'), findsOneWidget);
    expect(find.text('Lock now'), findsOneWidget);
    expect(find.text('Lock on start'), findsOneWidget);
    expect(store.values[CredentialRepository.credentialKey], isNotNull);
    var s = await storedSettings(tester, db);
    expect(s.get(SecuritySettings.appLock), isTrue);
    expect(s.get(SecuritySettings.lockMethod), LockMethod.pin);

    // Turning it off asks for the PIN first.
    await tester.tap(find.byType(Switch).first);
    await settle(tester);
    expect(find.text("Confirm it's you"), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('verify-secret')), '0000');
    await tester.tap(find.text('Confirm'));
    await settle(tester);
    expect(find.text('Wrong PIN'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('verify-secret')), '1357');
    await tester.tap(find.text('Confirm'));
    await settle(tester);
    expect(find.text('Turn off app lock?'), findsOneWidget);
    await tester.tap(find.text('Turn off'));
    await settle(tester);
    s = await storedSettings(tester, db);
    expect(s.get(SecuritySettings.appLock), isFalse);
    expect(store.values, isEmpty);
    expect(find.text('Lock now'), findsNothing);
    await tearDownApp(tester, db);
  });

  testWidgets('reset section never switches the lock off', (tester) async {
    await tester.runAsync(() async => db = newTestDb());
    final store = MemorySecretStore();
    storePin(store, '2468');
    await tester.runAsync(() async {
      final c = testContainer(db, overrides: securityOverrides(store: store));
      final n = c.read(settingsProvider.notifier);
      await n.set(SecuritySettings.appLock, true);
      await n.set(SecuritySettings.lockTimeout, 300);
      await resetSettingsPage(n, SettingSection.security);
      c.dispose();
    });
    final s = await storedSettings(tester, db);
    expect(s.get(SecuritySettings.appLock), isTrue);
    expect(s.get(SecuritySettings.lockTimeout), 60);
    await tester.runAsync(db.close);
  });
}
