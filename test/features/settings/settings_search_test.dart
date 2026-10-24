import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/platform/capabilities.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/settings/domain/search_text.dart';
import 'package:personal_finance/features/settings/presentation/settings_catalog.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

PlatformCapabilities caps({
  bool mobile = false,
  bool android = false,
  bool web = false,
  bool biometrics = true,
}) => PlatformCapabilities(
  isWeb: web,
  isDesktop: !mobile && !web,
  isMobile: mobile,
  biometrics: biometrics,
  notifications: !web,
  chooseFolder: !web,
  dbEncryption: true,
  dynamicColor: android || (!mobile && !web),
  blockScreenshots: android,
  hideInAppSwitcher: mobile,
  customStorageLocation: !mobile && !web,
);

SettingsSnapshot snap(Map<String, Object?> values) => SettingsSnapshot({
  for (final e in values.entries)
    SettingsSnapshot.rowId(e.key, 'global'): e.value,
});

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final de = lookupAppLocalizations(const Locale('de'));
  const empty = SettingsSnapshot.empty();

  List<String> ids(
    String q,
    AppLocalizations l, {
    SettingsSnapshot? s,
    PlatformCapabilities? c,
  }) => searchSettings(q, l, s ?? empty, c ?? caps()).map((e) => e.id).toList();

  test('the accent app icon setting is only offered on phones', () {
    expect(
      ids('app icon', en, c: caps(mobile: true)),
      contains(AppearanceSettings.accentAppIcon.key),
    );
    expect(
      ids('app icon', en),
      isNot(contains(AppearanceSettings.accentAppIcon.key)),
    );
  });

  test('folding handles umlauts and ß', () {
    expect(foldSearchText('Schriftgröße'), 'schriftgrosse');
    expect(foldSearchText('  Über   die  App '), 'uber die app');
  });

  test('English labels, best match first', () {
    final r = ids('theme', en);
    expect(r.first, AppearanceSettings.themeMode.key);
    expect(
      ids('warning threshold', en),
      contains(BudgetSettings.warnThreshold.key),
    );
  });

  test('German labels in German', () {
    expect(ids('Sprache', de).first, GeneralSettings.language.key);
    expect(ids('Wochenende', de), contains(BudgetSettings.weekendShift.key));
    // Umlaut-insensitive.
    expect(ids('schwelle', de), contains(BudgetSettings.warnThreshold.key));
  });

  test('keywords (EN and DE) and option labels match', () {
    expect(ids('dunkel', en), contains(AppearanceSettings.themeMode.key));
    expect(ids('gehalt', en), contains(BudgetSettings.salaryBased.key));
    expect(
      ids('schriftgrosse', de),
      contains(AppearanceSettings.textScale.key),
    );
    expect(ids('quarterly', en), contains(BudgetSettings.periodType.key));
  });

  test('section names are searchable', () {
    final r = searchSettings('budgets', en, empty, caps());
    expect(r.where((e) => e.page.section?.name == 'budgets'), isNotEmpty);
  });

  test('hidden settings are never found', () {
    expect(ids('onboarding', en), isEmpty);
    expect(
      ids('device name', en),
      isNot(contains(SyncSettings.deviceName.key)),
    );
  });

  test('switched-off modules are excluded', () {
    expect(ids('period', en), contains(BudgetSettings.periodType.key));
    final off = snap({NavigationSettings.module(AppModule.budgets).key: false});
    expect(
      ids('period', en, s: off),
      isNot(contains(BudgetSettings.periodType.key)),
    );
    expect(ids('rollover', en, s: off), isEmpty);
    // The module switch itself stays findable.
    expect(
      ids('budgets', en, s: off),
      contains(NavigationSettings.module(AppModule.budgets).key),
    );
  });

  test('platform-unsupported settings are excluded', () {
    final linux = caps(biometrics: false);
    expect(ids('screenshots', en, c: linux), isEmpty);
    expect(ids('screenshots', en, c: caps(mobile: true, android: true)), [
      PrivacySettings.blockScreenshots.key,
    ]);
    expect(ids('storage location', en, c: caps(web: true)), isEmpty);
    expect(ids('storage location', en, c: linux), [
      DataSettings.storageLocation.key,
    ]);
    expect(ids('notification time', en, c: caps(web: true)), isEmpty);
    expect(ids('material you', en, c: caps(web: true)), isEmpty);
  });

  test('actions are searchable', () {
    expect(ids('rebuild search', en), contains(SettingsActions.rebuildSearch));
    expect(ids('zurücksetzen', de), contains(SettingsActions.resetApp));
    expect(ids('lizenz', de), contains(SettingsActions.licenses));
  });

  test('every page and visible label resolves in EN and DE', () {
    for (final l in [en, de]) {
      for (final p in settingsPages) {
        expect(p.label(l), isNotEmpty);
        expect(pageSummary(p, l, empty, caps(), '1.0.0'), isA<String>());
      }
      for (final d in allSettings) {
        expect(d.label(l), isNotEmpty, reason: d.key);
      }
    }
  });

  test('every setting label has a German translation', () {
    final same = <String>[];
    for (final d in allSettings) {
      final a = d.label(en);
      final b = d.label(de);
      if (a == b && !{'PIN', 'Sync'}.contains(a)) same.add('${d.key}: $a');
    }
    // A few labels are identical in both languages by design.
    expect(same.length, lessThan(5), reason: same.join('\n'));
  });
}
