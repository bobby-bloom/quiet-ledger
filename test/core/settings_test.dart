import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/setting_def.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';

import '../helpers/test_app.dart';

void main() {
  test('defaults, set, scoped override and reset', () async {
    final db = newTestDb();
    final c = testContainer(db);
    addTearDown(() async {
      c.dispose();
      await db.close();
    });
    final ctrl = c.read(settingsProvider.notifier);
    expect(c.read(settingsProvider).get(BudgetSettings.warnThreshold), 80);

    await ctrl.set(BudgetSettings.warnThreshold, 90);
    await ctrl.set(BudgetSettings.warnThreshold, 70, scope: 'category:abc');
    final s = c.read(settingsProvider);
    expect(s.get(BudgetSettings.warnThreshold), 90);
    expect(s.get(BudgetSettings.warnThreshold, scope: 'category:abc'), 70);
    expect(s.get(BudgetSettings.warnThreshold, scope: 'category:other'), 90);

    expect(
      () => ctrl.set(BudgetSettings.warnThreshold, 500),
      throwsArgumentError,
    );

    await ctrl.reset(BudgetSettings.warnThreshold);
    expect(c.read(settingsProvider).get(BudgetSettings.warnThreshold), 80);
    // Setting again after a reset revives the soft-deleted row.
    await ctrl.set(BudgetSettings.warnThreshold, 85);
    final fresh = await loadSettings(db);
    expect(fresh.get(BudgetSettings.warnThreshold), 85);
  });

  test('enum settings decode unknown values to default', () {
    final s = SettingsSnapshot({
      SettingsSnapshot.rowId(AppearanceSettings.themeMode.key, 'global'):
          'neon',
    });
    expect(s.get(AppearanceSettings.themeMode), AppThemeMode.system);
  });

  test('set works through an untyped SettingDef<Object?>', () async {
    final db = newTestDb();
    final c = testContainer(db);
    addTearDown(() async {
      c.dispose();
      await db.close();
    });
    final SettingDef<Object?> def = AppearanceSettings.showCents;
    await c.read(settingsProvider.notifier).set(def, false);
    expect(c.read(settingsProvider).get(AppearanceSettings.showCents), isFalse);
    expect(def.encodeValue(true), true);
  });

  test('resetSection keeps hidden settings', () async {
    final db = newTestDb();
    final c = testContainer(db);
    addTearDown(() async {
      c.dispose();
      await db.close();
    });
    final ctrl = c.read(settingsProvider.notifier);
    await ctrl.set(GeneralSettings.onboardingDone, true);
    await ctrl.set(GeneralSettings.fiscalYearStartMonth, 4);
    await ctrl.resetSection(SettingSection.general);
    final s = c.read(settingsProvider);
    expect(s.get(GeneralSettings.onboardingDone), isTrue);
    expect(s.get(GeneralSettings.fiscalYearStartMonth), 1);
  });

  test('keys are unique', () {
    final keys = allSettings.map((d) => d.key).toList();
    expect(keys.toSet().length, keys.length);
  });
}
