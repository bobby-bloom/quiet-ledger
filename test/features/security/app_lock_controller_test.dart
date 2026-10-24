import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/security/data/secret_store.dart';
import 'package:personal_finance/features/security/domain/lock_credential.dart';
import 'package:personal_finance/features/security/presentation/app_lock_controller.dart';

import '../../helpers/test_app.dart';
import 'security_test_utils.dart';

void main() {
  var now = DateTime.utc(2026, 10, 23, 9);

  setUp(() => now = DateTime.utc(2026, 10, 23, 9));

  test('enable, lock, verify PIN, escalate after 5 failures', () async {
    final db = newTestDb();
    final store = MemorySecretStore();
    final c = testContainer(
      db,
      overrides: securityOverrides(store: store, clock: () => now),
    );
    addTearDown(() async {
      c.dispose();
      await db.close();
    });
    final ctrl = c.read(appLockProvider.notifier);
    await ctrl.loaded;
    expect(c.read(appLockProvider).enabled, isFalse);

    await ctrl.enable(kind: SecretKind.pin, secret: '4711');
    final s = c.read(settingsProvider);
    expect(s.get(SecuritySettings.appLock), isTrue);
    expect(s.get(SecuritySettings.lockMethod), LockMethod.pin);
    expect(
      store.values[CredentialRepository.credentialKey],
      isNot(contains('4711')),
    );
    expect(c.read(appLockProvider).pinLength, 4);

    ctrl.lock();
    expect(c.read(appLockProvider).locked, isTrue);

    for (var i = 1; i <= 4; i++) {
      expect(await ctrl.submit('0000'), UnlockResult.wrong);
      expect(ctrl.throttleRemaining, Duration.zero);
    }
    expect(await ctrl.submit('0000'), UnlockResult.wrong);
    expect(c.read(appLockProvider).failures, 5);
    expect(ctrl.throttleRemaining, const Duration(seconds: 30));
    // Even the right PIN is refused while throttled.
    expect(await ctrl.submit('4711'), UnlockResult.throttled);
    expect(c.read(appLockProvider).locked, isTrue);

    now = now.add(const Duration(seconds: 30));
    expect(await ctrl.submit('4711'), UnlockResult.success);
    expect(c.read(appLockProvider).locked, isFalse);
    expect(c.read(appLockProvider).failures, 0);
  });

  test('failure counter persists across restarts', () async {
    final db = newTestDb();
    final store = MemorySecretStore();
    storePin(store, '1234');
    final c1 = testContainer(
      db,
      overrides: securityOverrides(store: store, clock: () => now),
    );
    await c1
        .read(settingsProvider.notifier)
        .set(SecuritySettings.appLock, true);
    final ctrl1 = c1.read(appLockProvider.notifier);
    await ctrl1.loaded;
    for (var i = 0; i < 5; i++) {
      await ctrl1.submit('9999');
    }
    expect(ctrl1.throttleRemaining, const Duration(seconds: 30));
    now = now.add(const Duration(seconds: 30));
    expect(await ctrl1.submit('9999'), UnlockResult.wrong);
    expect(ctrl1.throttleRemaining, const Duration(seconds: 60));
    c1.dispose();

    final c2 = testContainer(
      db,
      overrides: [
        ...securityOverrides(store: store, clock: () => now),
        initialSettingsProvider.overrideWithValue(await loadSettings(db)),
      ],
    );
    addTearDown(() async {
      c2.dispose();
      await db.close();
    });
    final ctrl2 = c2.read(appLockProvider.notifier);
    // Lock on start (default) applies immediately, before loading.
    expect(c2.read(appLockProvider).locked, isTrue);
    await ctrl2.loaded;
    expect(c2.read(appLockProvider).failures, 6);
    expect(await ctrl2.submit('1234'), UnlockResult.throttled);
    now = now.add(const Duration(minutes: 1));
    expect(await ctrl2.submit('1234'), UnlockResult.success);
  });

  test('locks after the background timeout', () async {
    final db = newTestDb();
    final c = testContainer(db, overrides: securityOverrides(clock: () => now));
    addTearDown(() async {
      c.dispose();
      await db.close();
    });
    final ctrl = c.read(appLockProvider.notifier);
    await ctrl.loaded;
    await ctrl.enable(kind: SecretKind.password, secret: 'correct horse');
    await c
        .read(settingsProvider.notifier)
        .set(SecuritySettings.lockTimeout, 60);

    ctrl.onHidden();
    now = now.add(const Duration(seconds: 59));
    ctrl.onShown();
    expect(c.read(appLockProvider).locked, isFalse);

    ctrl.onHidden();
    now = now.add(const Duration(seconds: 60));
    ctrl.onShown();
    expect(c.read(appLockProvider).locked, isTrue);
    expect(await ctrl.submit('correct horse'), UnlockResult.success);

    await c
        .read(settingsProvider.notifier)
        .set(SecuritySettings.lockTimeout, 0);
    ctrl.onHidden();
    expect(c.read(appLockProvider).locked, isTrue);
  });

  test('biometric unlock, change and disable', () async {
    final db = newTestDb();
    final store = MemorySecretStore();
    final bio = FakeBiometrics();
    final c = testContainer(
      db,
      overrides: securityOverrides(store: store, biometrics: bio),
    );
    addTearDown(() async {
      c.dispose();
      await db.close();
    });
    final ctrl = c.read(appLockProvider.notifier);
    await ctrl.loaded;
    await ctrl.enable(kind: SecretKind.pin, secret: '2580', biometrics: true);
    expect(
      c.read(settingsProvider).get(SecuritySettings.lockMethod),
      LockMethod.biometric,
    );
    ctrl.lock();
    bio.result = false;
    expect(await ctrl.unlockWithBiometrics('r'), isFalse);
    expect(c.read(appLockProvider).locked, isTrue);
    bio.result = true;
    expect(await ctrl.unlockWithBiometrics('r'), isTrue);
    expect(c.read(appLockProvider).locked, isFalse);

    await ctrl.changeSecret(kind: SecretKind.password, secret: 'new secret');
    expect(c.read(appLockProvider).kind, SecretKind.password);
    expect(await ctrl.submit('2580', unlock: false), UnlockResult.wrong);
    expect(
      await ctrl.submit('new secret', unlock: false),
      UnlockResult.success,
    );

    await ctrl.disable();
    expect(c.read(appLockProvider).enabled, isFalse);
    expect(c.read(settingsProvider).get(SecuritySettings.appLock), isFalse);
    expect(store.values, isEmpty);
    ctrl.lock();
    expect(c.read(appLockProvider).locked, isFalse);
  });

  test('lock setting without credential turns itself off', () async {
    final db = newTestDb();
    final c1 = testContainer(db);
    await c1
        .read(settingsProvider.notifier)
        .set(SecuritySettings.appLock, true);
    c1.dispose();
    final c = testContainer(
      db,
      overrides: [
        ...securityOverrides(),
        initialSettingsProvider.overrideWithValue(await loadSettings(db)),
      ],
    );
    addTearDown(() async {
      c.dispose();
      await db.close();
    });
    final ctrl = c.read(appLockProvider.notifier);
    await ctrl.loaded;
    expect(c.read(appLockProvider).locked, isFalse);
    expect(c.read(settingsProvider).get(SecuritySettings.appLock), isFalse);
  });
}
