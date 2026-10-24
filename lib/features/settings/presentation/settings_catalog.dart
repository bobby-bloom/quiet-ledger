import 'package:flutter/material.dart';
import 'package:personal_finance/core/platform/capabilities.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/setting_def.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/settings/domain/search_text.dart';
import 'package:personal_finance/features/settings/presentation/setting_access.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

/// One page of the settings screen: a [SettingSection] or "About".
@immutable
class SettingsPage {
  const SettingsPage.section(SettingSection this.section);
  const SettingsPage.about() : section = null;

  final SettingSection? section;

  bool get isAbout => section == null;

  /// Path segment: `SettingSection.name` or `about`.
  String get id => section?.name ?? aboutId;

  static const aboutId = 'about';

  static SettingsPage? parse(String? id) {
    if (id == null) return null;
    if (id == aboutId) return const SettingsPage.about();
    final s = SettingSection.values.where((e) => e.name == id).firstOrNull;
    return s == null ? null : SettingsPage.section(s);
  }

  String label(AppLocalizations l) =>
      section == null ? l.settingsUiSecAbout : sectionLabel(l, section!);

  IconData get icon => switch (section) {
    null => Icons.info_outline,
    SettingSection.general => Icons.tune,
    SettingSection.appearance => Icons.palette_outlined,
    SettingSection.privacy => Icons.visibility_off_outlined,
    SettingSection.navigation => Icons.space_dashboard_outlined,
    SettingSection.dashboard => Icons.dashboard_customize_outlined,
    SettingSection.entry => Icons.edit_note,
    SettingSection.transactions => Icons.format_list_bulleted,
    SettingSection.categories => Icons.category_outlined,
    SettingSection.budgets => Icons.track_changes_outlined,
    SettingSection.recurring => Icons.event_repeat_outlined,
    SettingSection.forecast => Icons.show_chart,
    SettingSection.reports => Icons.bar_chart_outlined,
    SettingSection.security => Icons.lock_outline,
    SettingSection.importExport => Icons.import_export,
    SettingSection.data => Icons.storage_outlined,
    SettingSection.sync => Icons.sync,
  };

  @override
  bool operator ==(Object other) =>
      other is SettingsPage && other.section == section;

  @override
  int get hashCode => section.hashCode;
}

/// Pages in display order.
const settingsPages = <SettingsPage>[
  SettingsPage.section(SettingSection.general),
  SettingsPage.section(SettingSection.appearance),
  SettingsPage.section(SettingSection.privacy),
  SettingsPage.section(SettingSection.navigation),
  SettingsPage.section(SettingSection.dashboard),
  SettingsPage.section(SettingSection.entry),
  SettingsPage.section(SettingSection.transactions),
  SettingsPage.section(SettingSection.categories),
  SettingsPage.section(SettingSection.budgets),
  SettingsPage.section(SettingSection.recurring),
  SettingsPage.section(SettingSection.forecast),
  SettingsPage.section(SettingSection.reports),
  SettingsPage.section(SettingSection.security),
  SettingsPage.section(SettingSection.importExport),
  SettingsPage.section(SettingSection.data),
  SettingsPage.section(SettingSection.sync),
  SettingsPage.about(),
];

/// Pages rendered by a dedicated widget (not only generically).
const customPages = {
  SettingSection.privacy,
  SettingSection.navigation,
  SettingSection.security,
  SettingSection.data,
};

final _notificationDefs = <SettingDef<Object?>>{
  RecurringSettings.notificationTime,
  RecurringSettings.quietHoursStart,
  RecurringSettings.quietHoursEnd,
  RecurringSettings.notifyBills,
  RecurringSettings.notifyIncome,
  RecurringSettings.notifyLowBalance,
  RecurringSettings.notifyBudget,
};

/// Whether [def] is shown: not hidden, its module is on, the platform
/// supports it, and settings it depends on are set accordingly.
bool isSettingVisible(
  SettingDef<Object?> def,
  SettingsSnapshot s,
  PlatformCapabilities caps,
) {
  if (def.hidden) return false;
  final module = def.module;
  if (module != null) {
    final m = AppModule.values.where((e) => e.name == module).firstOrNull;
    if (m != null && !s.moduleEnabled(m)) return false;
  }
  if (_notificationDefs.contains(def) && !caps.notifications) return false;
  if (def == AppearanceSettings.dynamicColor) return caps.dynamicColor;
  if (def == AppearanceSettings.accentAppIcon) return caps.isMobile;
  if (def == AppearanceSettings.customAccent) {
    return s.get(AppearanceSettings.accentScheme) == AccentScheme.custom;
  }
  if (def == PrivacySettings.blockScreenshots) return caps.blockScreenshots;
  if (def == PrivacySettings.hideInAppSwitcher) return caps.hideInAppSwitcher;
  if (def == DataSettings.storageLocation) return caps.customStorageLocation;
  if (def == ImportExportSettings.autoExportFolder) return caps.chooseFolder;
  if (def == BudgetSettings.salaryRuleId) {
    return s.get(BudgetSettings.salaryBased);
  }
  if (def == BudgetSettings.holidayRegion) {
    return s.get(BudgetSettings.holidayCountry) == 'DE';
  }
  if (def == SecuritySettings.lockMethod ||
      def == SecuritySettings.lockTimeout ||
      def == SecuritySettings.lockOnStart) {
    return s.get(SecuritySettings.appLock);
  }
  return true;
}

/// Choice values offered on this platform (e.g. no biometrics on Linux).
List<String> visibleChoiceValues(
  SettingDef<Object?> def,
  ChoiceEditor e,
  PlatformCapabilities caps,
) {
  if (def == SecuritySettings.lockMethod && !caps.biometrics) {
    return e.values.where((v) => v != LockMethod.biometric.name).toList();
  }
  return e.values;
}

/// Visible settings of [section], in catalogue order.
List<SettingDef<Object?>> visibleSettings(
  SettingSection section,
  SettingsSnapshot s,
  PlatformCapabilities caps,
) => [
  for (final d in allSettings)
    if (d.section == section && isSettingVisible(d, s, caps)) d,
];

/// Whether a page appears in the list.
bool isPageVisible(
  SettingsPage p,
  SettingsSnapshot s,
  PlatformCapabilities caps,
) {
  final section = p.section;
  if (section == null) return true;
  if (customPages.contains(section)) return true;
  return visibleSettings(section, s, caps).isNotEmpty;
}

/// A searchable row: a setting (id = key) or an action on a page.
@immutable
class SettingsEntry {
  const SettingsEntry({
    required this.id,
    required this.page,
    required this.label,
    this.description,
    this.keywords = const [],
  });

  final String id;
  final SettingsPage page;
  final String label;
  final String? description;
  final List<String> keywords;
}

/// Ids of action rows (not settings) that the search can jump to.
abstract final class SettingsActions {
  static const privacyNow = 'action.privacyNow';
  static const lockNow = 'action.lockNow';
  static const changeSecret = 'action.changeSecret';
  static const biometrics = 'action.biometrics';
  static const statistics = 'action.statistics';
  static const rebuildSearch = 'action.rebuildSearch';
  static const rerunRules = 'action.rerunRules';
  static const purgeDeleted = 'action.purgeDeleted';
  static const resetApp = 'action.resetApp';
  static const version = 'action.version';
  static const licenses = 'action.licenses';
}

List<SettingsEntry> _actionEntries(
  AppLocalizations l,
  SettingsSnapshot s,
  PlatformCapabilities caps,
) {
  const privacy = SettingsPage.section(SettingSection.privacy);
  const security = SettingsPage.section(SettingSection.security);
  const data = SettingsPage.section(SettingSection.data);
  const about = SettingsPage.about();
  final lockOn = s.get(SecuritySettings.appLock);
  return [
    SettingsEntry(
      id: SettingsActions.privacyNow,
      page: privacy,
      label: l.settingsUiPrivacyNow,
      description: l.settingsUiPrivacyNowDesc,
      keywords: const ['privacy', 'privatsphäre', 'blur'],
    ),
    if (lockOn) ...[
      SettingsEntry(
        id: SettingsActions.lockNow,
        page: security,
        label: l.securityLockNow,
        keywords: const ['lock', 'sperren'],
      ),
      SettingsEntry(
        id: SettingsActions.changeSecret,
        page: security,
        label: l.securityChangePin,
        description: l.securityChangePassword,
        keywords: const ['pin', 'password', 'passwort', 'kennwort'],
      ),
      if (caps.biometrics)
        SettingsEntry(
          id: SettingsActions.biometrics,
          page: security,
          label: l.setOptBiometric,
          keywords: const [
            'fingerprint',
            'face id',
            'fingerabdruck',
            'windows hello',
          ],
        ),
    ],
    SettingsEntry(
      id: SettingsActions.statistics,
      page: data,
      label: l.settingsUiStats,
      keywords: const ['statistics', 'statistik', 'size', 'größe'],
    ),
    SettingsEntry(
      id: SettingsActions.rebuildSearch,
      page: data,
      label: l.settingsUiRebuildIndex,
      description: l.settingsUiRebuildIndexDesc,
      keywords: const ['search', 'suche', 'index', 'fts'],
    ),
    SettingsEntry(
      id: SettingsActions.purgeDeleted,
      page: data,
      label: l.settingsUiPurge,
      keywords: const ['tombstone', 'purge', 'bereinigen', 'gelöscht'],
    ),
    SettingsEntry(
      id: SettingsActions.rerunRules,
      page: data,
      label: l.settingsUiRerunRules,
      description: l.settingsUiRerunRulesDesc,
      keywords: const ['rules', 'regeln', 'categorise', 'kategorisieren'],
    ),
    SettingsEntry(
      id: SettingsActions.resetApp,
      page: data,
      label: l.settingsUiResetApp,
      description: l.settingsUiResetAppDesc,
      keywords: const ['delete', 'löschen', 'wipe', 'zurücksetzen'],
    ),
    SettingsEntry(
      id: SettingsActions.version,
      page: about,
      label: l.settingsUiAboutVersion,
      keywords: const ['about', 'über', 'info'],
    ),
    SettingsEntry(
      id: SettingsActions.licenses,
      page: about,
      label: l.settingsUiAboutLicenses,
      keywords: const ['license', 'licence', 'lizenz', 'open source'],
    ),
  ];
}

/// Every visible, searchable row in the current language.
List<SettingsEntry> settingsEntries(
  AppLocalizations l,
  SettingsSnapshot s,
  PlatformCapabilities caps,
) {
  final out = <SettingsEntry>[];
  for (final d in allSettings) {
    if (!isSettingVisible(d, s, caps)) continue;
    final e = d.editor;
    final options = switch (e) {
      ChoiceEditor() => [
        for (final v in visibleChoiceValues(d, e, caps)) e.labels(l, v),
      ],
      OrderedListEditor() => [for (final v in e.values) e.labels(l, v)],
      _ => const <String>[],
    };
    out.add(
      SettingsEntry(
        id: d.key,
        page: SettingsPage.section(d.section),
        label: d.label(l),
        description: d.description?.call(l),
        keywords: [...d.keywords, ...options],
      ),
    );
  }
  out.addAll(_actionEntries(l, s, caps));
  return out;
}

/// Searches labels, descriptions, keywords, option labels and section
/// names. Hidden settings, switched-off modules and unsupported platform
/// features are excluded.
List<SettingsEntry> searchSettings(
  String query,
  AppLocalizations l,
  SettingsSnapshot s,
  PlatformCapabilities caps,
) {
  final entries = settingsEntries(l, s, caps);
  return rankSearch(query, [
    for (final e in entries)
      SearchDoc(
        value: e,
        title: e.label,
        secondary: [e.page.label(l), ?e.description, ...e.keywords],
      ),
  ]);
}

/// One-line summary under each page in the list.
String pageSummary(
  SettingsPage p,
  AppLocalizations l,
  SettingsSnapshot s,
  PlatformCapabilities caps,
  String appVersion,
) {
  String choice(SettingDef<Object?> d) {
    final e = d.editor;
    final v = currentJson(s, d);
    if (e is ChoiceEditor && v is String) return e.labels(l, v);
    return '$v';
  }

  final section = p.section;
  if (section == null) return l.settingsUiAboutSummary(appVersion);
  return switch (section) {
    SettingSection.general =>
      '${choice(GeneralSettings.language)} · '
          '${choice(GeneralSettings.dateFormat)}',
    SettingSection.appearance => choice(AppearanceSettings.themeMode),
    SettingSection.privacy =>
      s.get(PrivacySettings.hideAmounts)
          ? l.settingsUiAmountsHidden
          : l.settingsUiAmountsVisible,
    SettingSection.navigation => l.settingsUiTabsCount(
      s.get(NavigationSettings.tabs).length,
    ),
    SettingSection.dashboard => choice(DashboardSettings.period),
    SettingSection.entry =>
      s.get(EntrySettings.calculatorKeypad)
          ? l.setCalculatorKeypad
          : choice(EntrySettings.defaultType),
    SettingSection.transactions =>
      '${l.setGrouping}: ${choice(TransactionSettings.grouping)}',
    SettingSection.categories => choice(CategorySettings.defaultSet),
    SettingSection.budgets =>
      s.moduleEnabled(AppModule.budgets)
          ? choice(BudgetSettings.periodType)
          : l.settingsUiModuleOff,
    SettingSection.recurring => l.settingsUiDaysBefore(
      s.get(RecurringSettings.reminderLeadDays),
    ),
    SettingSection.forecast =>
      s.moduleEnabled(AppModule.forecast)
          ? l.settingsUiMonthsCount(s.get(ForecastSettings.horizonMonths))
          : l.settingsUiModuleOff,
    SettingSection.reports => choice(ReportSettings.defaultPeriod),
    SettingSection.security =>
      s.get(SecuritySettings.appLock)
          ? choice(SecuritySettings.lockMethod)
          : l.setOptOff,
    SettingSection.importExport =>
      '${l.setAutoExport}: '
          '${choice(ImportExportSettings.autoExport)}',
    SettingSection.data => l.settingsUiDataSummary,
    SettingSection.sync => '',
  };
}
