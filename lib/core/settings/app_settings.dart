import 'package:personal_finance/core/money/money_format.dart';
import 'package:personal_finance/core/settings/backup_settings.dart';
import 'package:personal_finance/core/settings/setting_def.dart';
import 'package:personal_finance/core/settings/setting_enums.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

export 'package:personal_finance/core/settings/setting_enums.dart';

// The catalogue of all settings (PLAN.md §2.7). Features read them with
// `ref.watch(settingsProvider).get(BudgetSettings.periodType)` and write with
// `ref.read(settingsProvider.notifier).set(def, value)`.
//
// To add a setting: add a def to the right class below, add it to that
// class's `all` list and add its label to lib/l10n/parts/settings_*.arb.

// ------------------------------------------------------------- sections ----

abstract final class GeneralSettings {
  static final language = SettingDef.choice<AppLanguage>(
    key: 'general.language',
    section: SettingSection.general,
    values: AppLanguage.values,
    defaultValue: AppLanguage.system,
    label: (l) => l.setLanguage,
    valueLabel: (l, v) => switch (v) {
      AppLanguage.system => l.setOptSystem,
      AppLanguage.en => 'English',
      AppLanguage.de => 'Deutsch',
    },
    keywords: const ['locale', 'sprache'],
    bootstrap: true,
  );

  /// BCP-47 locale used for number and date formats; empty = from language.
  static final formatLocale = SettingDef.string(
    key: 'general.formatLocale',
    section: SettingSection.general,
    defaultValue: '',
    label: (l) => l.setFormatLocale,
    description: (l) => l.setFormatLocaleDesc,
    editor: ChoiceEditor(const [
      '',
      'de_DE',
      'de_AT',
      'de_CH',
      'en_US',
      'en_GB',
      'en_IE',
      'fr_FR',
    ], (l, v) => v.isEmpty ? l.setOptFromLanguage : v),
    keywords: const ['number', 'decimal', 'zahlenformat'],
    bootstrap: true,
  );

  /// Custom date pattern (intl `DateFormat`); empty = locale default.
  static final dateFormat = SettingDef.string(
    key: 'general.dateFormat',
    section: SettingSection.general,
    defaultValue: '',
    label: (l) => l.setDateFormat,
    editor: ChoiceEditor(const [
      '',
      'dd.MM.yyyy',
      'd.M.yy',
      'yyyy-MM-dd',
      'MM/dd/yyyy',
      'dd/MM/yyyy',
      'd MMM yyyy',
    ], (l, v) => v.isEmpty ? l.setOptLocaleDefault : v),
    keywords: const ['datum'],
  );

  static final firstDayOfWeek = SettingDef.choice<FirstDayOfWeek>(
    key: 'general.firstDayOfWeek',
    section: SettingSection.general,
    values: FirstDayOfWeek.values,
    defaultValue: FirstDayOfWeek.locale,
    label: (l) => l.setFirstDayOfWeek,
    valueLabel: (l, v) => switch (v) {
      FirstDayOfWeek.locale => l.setOptLocaleDefault,
      FirstDayOfWeek.monday => l.setOptMonday,
      FirstDayOfWeek.sunday => l.setOptSunday,
      FirstDayOfWeek.saturday => l.setOptSaturday,
    },
  );

  static final fiscalYearStartMonth = SettingDef.integer(
    key: 'general.fiscalYearStartMonth',
    section: SettingSection.general,
    defaultValue: 1,
    min: 1,
    max: 12,
    label: (l) => l.setFiscalYearStart,
    description: (l) => l.setFiscalYearStartDesc,
  );

  static final startScreen = SettingDef.choice<StartScreen>(
    key: 'general.startScreen',
    section: SettingSection.general,
    values: StartScreen.values,
    defaultValue: StartScreen.home,
    label: (l) => l.setStartScreen,
    valueLabel: (l, v) => switch (v) {
      StartScreen.home => l.navHome,
      StartScreen.transactions => l.navTransactions,
      StartScreen.plan => l.navPlan,
      StartScreen.forecast => l.navForecast,
    },
  );

  static final onboardingDone = SettingDef.boolean(
    key: 'general.onboardingDone',
    section: SettingSection.general,
    defaultValue: false,
    label: (l) => l.setOnboardingDone,
    hidden: true,
    bootstrap: true,
  );

  static final all = <SettingDef<Object?>>[
    language,
    formatLocale,
    dateFormat,
    firstDayOfWeek,
    fiscalYearStartMonth,
    startScreen,
    onboardingDone,
  ];
}

abstract final class AppearanceSettings {
  static final themeMode = SettingDef.choice<AppThemeMode>(
    key: 'appearance.themeMode',
    section: SettingSection.appearance,
    values: AppThemeMode.values,
    defaultValue: AppThemeMode.system,
    label: (l) => l.setThemeMode,
    valueLabel: (l, v) => switch (v) {
      AppThemeMode.system => l.setOptSystem,
      AppThemeMode.light => l.setOptLight,
      AppThemeMode.dark => l.setOptDark,
    },
    keywords: const ['dark mode', 'dunkel', 'hell'],
    bootstrap: true,
  );

  static final accentScheme = SettingDef.choice<AccentScheme>(
    key: 'appearance.accentScheme',
    section: SettingSection.appearance,
    values: AccentScheme.values,
    defaultValue: AccentScheme.spruce,
    label: (l) => l.setAccentScheme,
    valueLabel: (l, v) => switch (v) {
      AccentScheme.spruce => l.setOptSpruce,
      AccentScheme.blue => l.setOptBlue,
      AccentScheme.violet => l.setOptViolet,
      AccentScheme.amber => l.setOptAmber,
      AccentScheme.rose => l.setOptRose,
      AccentScheme.slate => l.setOptSlate,
      AccentScheme.custom => l.setOptCustom,
    },
    keywords: const ['color', 'farbe'],
    bootstrap: true,
  );

  /// ARGB, used when [accentScheme] is custom.
  static final customAccent = SettingDef.integer(
    key: 'appearance.customAccent',
    section: SettingSection.appearance,
    defaultValue: 0xFF1F5A53,
    min: 0,
    max: 0xFFFFFFFF,
    label: (l) => l.setCustomAccent,
    editor: const ColorEditor(),
    bootstrap: true,
  );

  static final dynamicColor = SettingDef.boolean(
    key: 'appearance.dynamicColor',
    section: SettingSection.appearance,
    defaultValue: false,
    label: (l) => l.setDynamicColor,
    description: (l) => l.setDynamicColorDesc,
    keywords: const ['material you'],
    bootstrap: true,
  );

  /// Android/iOS: the home-screen icon switches to the preset closest to
  /// the accent (iOS confirms each change with a system alert).
  static final accentAppIcon = SettingDef.boolean(
    key: 'appearance.accentAppIcon',
    section: SettingSection.appearance,
    defaultValue: true,
    label: (l) => l.setAccentAppIcon,
    description: (l) => l.setAccentAppIconDesc,
    keywords: const ['icon', 'launcher', 'symbol'],
    deviceLocal: true,
  );

  static final highContrast = SettingDef.boolean(
    key: 'appearance.highContrast',
    section: SettingSection.appearance,
    defaultValue: false,
    label: (l) => l.setHighContrast,
    keywords: const ['kontrast', 'accessibility'],
    bootstrap: true,
  );

  /// Percent, 100 = system text size.
  static final textScale = SettingDef.integer(
    key: 'appearance.textScale',
    section: SettingSection.appearance,
    defaultValue: 100,
    min: 80,
    max: 160,
    step: 10,
    unit: (l) => '%',
    label: (l) => l.setTextScale,
    keywords: const ['font size', 'schriftgröße'],
    bootstrap: true,
  );

  static final density = SettingDef.choice<Density>(
    key: 'appearance.density',
    section: SettingSection.appearance,
    values: Density.values,
    defaultValue: Density.comfortable,
    label: (l) => l.setDensity,
    valueLabel: (l, v) => switch (v) {
      Density.comfortable => l.setOptComfortable,
      Density.compact => l.setOptCompact,
    },
    bootstrap: true,
  );

  static final amountColorStyle = SettingDef.choice<AmountColorStyle>(
    key: 'appearance.amountColorStyle',
    section: SettingSection.appearance,
    values: AmountColorStyle.values,
    defaultValue: AmountColorStyle.colorCoded,
    label: (l) => l.setAmountColorStyle,
    valueLabel: (l, v) => switch (v) {
      AmountColorStyle.colorCoded => l.setOptColorCoded,
      AmountColorStyle.neutral => l.setOptNeutral,
      AmountColorStyle.signOnly => l.setOptSignOnly,
    },
  );

  static final showCents = SettingDef.boolean(
    key: 'appearance.showCents',
    section: SettingSection.appearance,
    defaultValue: true,
    label: (l) => l.setShowCents,
    keywords: const ['cent', 'decimals'],
  );

  static final signStyle = SettingDef.choice<SignStyle>(
    key: 'appearance.signStyle',
    section: SettingSection.appearance,
    values: SignStyle.values,
    defaultValue: SignStyle.leadingMinus,
    label: (l) => l.setSignStyle,
    valueLabel: (l, v) => switch (v) {
      SignStyle.leadingMinus => '−12,50',
      SignStyle.parentheses => '(12,50)',
      SignStyle.trailingMinus => '12,50 −',
    },
    keywords: const ['negative', 'minus', 'vorzeichen'],
  );

  static final all = <SettingDef<Object?>>[
    themeMode,
    accentScheme,
    customAccent,
    dynamicColor,
    accentAppIcon,
    highContrast,
    textScale,
    density,
    amountColorStyle,
    showCents,
    signStyle,
  ];
}

abstract final class PrivacySettings {
  static final hideAmounts = SettingDef.boolean(
    key: 'privacy.hideAmounts',
    section: SettingSection.privacy,
    defaultValue: false,
    label: (l) => l.setHideAmounts,
    description: (l) => l.setHideAmountsDesc,
    keywords: const ['blur', 'verbergen'],
  );

  static final privacyOnStart = SettingDef.boolean(
    key: 'privacy.privacyOnStart',
    section: SettingSection.privacy,
    defaultValue: false,
    label: (l) => l.setPrivacyOnStart,
  );

  static final hideInAppSwitcher = SettingDef.boolean(
    key: 'privacy.hideInAppSwitcher',
    section: SettingSection.privacy,
    defaultValue: false,
    label: (l) => l.setHideInAppSwitcher,
  );

  static final blockScreenshots = SettingDef.boolean(
    key: 'privacy.blockScreenshots',
    section: SettingSection.privacy,
    defaultValue: false,
    label: (l) => l.setBlockScreenshots,
    description: (l) => l.setBlockScreenshotsDesc,
  );

  static final all = <SettingDef<Object?>>[
    hideAmounts,
    privacyOnStart,
    hideInAppSwitcher,
    blockScreenshots,
  ];
}

abstract final class NavigationSettings {
  static final tabs = SettingDef.stringList(
    key: 'navigation.tabs',
    section: SettingSection.navigation,
    defaultValue: const ['home', 'transactions', 'plan', 'forecast', 'more'],
    label: (l) => l.setNavTabs,
    description: (l) => l.setNavTabsDesc,
    editor: OrderedListEditor(
      NavTab.values.map((e) => e.name).toList(),
      (l, v) => navTabLabel(l, NavTab.values.byName(v)),
    ),
    keywords: const ['bottom bar', 'menu', 'tabs'],
  );

  static SettingDef<bool> module(AppModule m) => _modules[m]!;

  static final Map<AppModule, SettingDef<bool>> _modules = {
    for (final m in AppModule.values)
      m: SettingDef.boolean(
        key: 'modules.${m.name}',
        section: SettingSection.navigation,
        defaultValue: true,
        label: (l) => l.setModuleEnabled(moduleLabel(l, m)),
        keywords: const ['module', 'modul', 'disable'],
      ),
  };

  /// Wide layouts: the sidebar shows icons only. Toggled from the sidebar.
  static final sidebarCollapsed = SettingDef.boolean(
    key: 'navigation.sidebarCollapsed',
    section: SettingSection.navigation,
    defaultValue: false,
    label: (l) => l.setSidebarCollapsed,
    hidden: true,
    deviceLocal: true,
  );

  static final all = <SettingDef<Object?>>[
    tabs,
    ..._modules.values,
    sidebarCollapsed,
  ];
}

String navTabLabel(AppLocalizations l, NavTab t) => switch (t) {
  NavTab.home => l.navHome,
  NavTab.transactions => l.navTransactions,
  NavTab.plan => l.navPlan,
  NavTab.forecast => l.navForecast,
  NavTab.accounts => l.navAccounts,
  NavTab.reports => l.navReports,
  NavTab.more => l.navMore,
};

String moduleLabel(AppLocalizations l, AppModule m) => switch (m) {
  AppModule.budgets => l.setModBudgets,
  AppModule.goals => l.navGoals,
  AppModule.forecast => l.navForecast,
  AppModule.scenarios => l.navScenarios,
  AppModule.tags => l.navTags,
  AppModule.customFields => l.setModCustomFields,
  AppModule.attachments => l.setModAttachments,
};

abstract final class DashboardSettings {
  static final period = SettingDef.choice<DashboardPeriod>(
    key: 'dashboard.period',
    section: SettingSection.dashboard,
    values: DashboardPeriod.values,
    defaultValue: DashboardPeriod.budgetPeriod,
    label: (l) => l.setDashboardPeriod,
    valueLabel: (l, v) => switch (v) {
      DashboardPeriod.budgetPeriod => l.setOptBudgetPeriod,
      DashboardPeriod.calendarMonth => l.setOptCalendarMonth,
    },
  );

  static final upcomingDays = SettingDef.integer(
    key: 'dashboard.upcomingDays',
    section: SettingSection.dashboard,
    defaultValue: 14,
    min: 1,
    max: 90,
    label: (l) => l.setUpcomingDays,
  );

  /// Which dashboard widgets are folded on this device: a JSON map
  /// `{widgetTypeName: open}`; '' or malformed means all open. Shared by
  /// the phone and wide views. Toggled from each card's chevron.
  static final cardExpansion = SettingDef.string(
    key: 'dashboard.cardExpansion',
    section: SettingSection.dashboard,
    defaultValue: '',
    label: (l) => l.dashCardExpansionSetting,
    hidden: true,
    deviceLocal: true,
  );

  static final all = <SettingDef<Object?>>[period, upcomingDays, cardExpansion];
}

abstract final class EntrySettings {
  static final fieldOrder = SettingDef.stringList(
    key: 'entry.fieldOrder',
    section: SettingSection.entry,
    defaultValue: const [
      'amount',
      'category',
      'account',
      'date',
      'payee',
      'note',
    ],
    label: (l) => l.setFieldOrder,
    editor: OrderedListEditor(
      QuickAddField.values.map((e) => e.name).toList(),
      (l, v) => quickAddFieldLabel(l, QuickAddField.values.byName(v)),
    ),
  );

  static final requiredFields = SettingDef.stringList(
    key: 'entry.requiredFields',
    section: SettingSection.entry,
    defaultValue: const ['amount', 'account'],
    label: (l) => l.setRequiredFields,
    editor: OrderedListEditor(
      QuickAddField.values.map((e) => e.name).toList(),
      (l, v) => quickAddFieldLabel(l, QuickAddField.values.byName(v)),
      reorderable: false,
    ),
  );

  static final defaultAccountId = SettingDef.optionalString(
    key: 'entry.defaultAccountId',
    section: SettingSection.entry,
    label: (l) => l.setDefaultAccount,
    editor: const CustomEditor('/accounts/pick'),
  );

  static final defaultType = SettingDef.choice<DefaultTxnType>(
    key: 'entry.defaultType',
    section: SettingSection.entry,
    values: DefaultTxnType.values,
    defaultValue: DefaultTxnType.expense,
    label: (l) => l.setDefaultType,
    valueLabel: (l, v) => switch (v) {
      DefaultTxnType.expense => l.typeExpense,
      DefaultTxnType.income => l.typeIncome,
      DefaultTxnType.lastUsed => l.setOptLastUsed,
    },
  );

  static final defaultDate = SettingDef.choice<DefaultTxnDate>(
    key: 'entry.defaultDate',
    section: SettingSection.entry,
    values: DefaultTxnDate.values,
    defaultValue: DefaultTxnDate.today,
    label: (l) => l.setDefaultDate,
    valueLabel: (l, v) => switch (v) {
      DefaultTxnDate.today => l.setOptToday,
      DefaultTxnDate.lastUsed => l.setOptLastUsed,
    },
  );

  static final calculatorKeypad = SettingDef.boolean(
    key: 'entry.calculatorKeypad',
    section: SettingSection.entry,
    defaultValue: true,
    label: (l) => l.setCalculatorKeypad,
    keywords: const ['rechner'],
  );

  static final recentCategories = SettingDef.integer(
    key: 'entry.recentCategories',
    section: SettingSection.entry,
    defaultValue: 6,
    min: 0,
    max: 20,
    label: (l) => l.setRecentCategories,
  );

  static final payeeSuggestions = SettingDef.boolean(
    key: 'entry.payeeSuggestions',
    section: SettingSection.entry,
    defaultValue: true,
    label: (l) => l.setPayeeSuggestions,
    description: (l) => l.setPayeeSuggestionsDesc,
  );

  static final confirmDelete = SettingDef.boolean(
    key: 'entry.confirmDelete',
    section: SettingSection.entry,
    defaultValue: true,
    label: (l) => l.setConfirmDelete,
  );

  static final all = <SettingDef<Object?>>[
    fieldOrder,
    requiredFields,
    defaultAccountId,
    defaultType,
    defaultDate,
    calculatorKeypad,
    recentCategories,
    payeeSuggestions,
    confirmDelete,
  ];
}

String quickAddFieldLabel(AppLocalizations l, QuickAddField f) => switch (f) {
  QuickAddField.amount => l.fieldAmount,
  QuickAddField.category => l.fieldCategory,
  QuickAddField.account => l.fieldAccount,
  QuickAddField.date => l.fieldDate,
  QuickAddField.payee => l.fieldPayee,
  QuickAddField.note => l.fieldNote,
  QuickAddField.tags => l.navTags,
  QuickAddField.status => l.fieldStatus,
};

abstract final class TransactionSettings {
  static final grouping = SettingDef.choice<TxnGrouping>(
    key: 'transactions.grouping',
    section: SettingSection.transactions,
    values: TxnGrouping.values,
    defaultValue: TxnGrouping.day,
    label: (l) => l.setGrouping,
    valueLabel: (l, v) => switch (v) {
      TxnGrouping.day => l.setOptDay,
      TxnGrouping.week => l.setOptWeek,
      TxnGrouping.month => l.setOptMonth,
      TxnGrouping.none => l.commonNone,
    },
  );

  static final sort = SettingDef.choice<TxnSort>(
    key: 'transactions.sort',
    section: SettingSection.transactions,
    values: TxnSort.values,
    defaultValue: TxnSort.dateDesc,
    label: (l) => l.setSort,
    valueLabel: (l, v) => switch (v) {
      TxnSort.dateDesc => l.setOptNewestFirst,
      TxnSort.dateAsc => l.setOptOldestFirst,
      TxnSort.amountDesc => l.setOptLargestFirst,
      TxnSort.amountAsc => l.setOptSmallestFirst,
      TxnSort.payee => l.fieldPayee,
    },
  );

  static final runningBalance = SettingDef.boolean(
    key: 'transactions.runningBalance',
    section: SettingSection.transactions,
    defaultValue: false,
    label: (l) => l.setRunningBalance,
    description: (l) => l.setRunningBalanceDesc,
  );

  static final visibleColumns = SettingDef.stringList(
    key: 'transactions.visibleColumns',
    section: SettingSection.transactions,
    defaultValue: const ['date', 'payee', 'category', 'account', 'amount'],
    label: (l) => l.setVisibleColumns,
    editor: OrderedListEditor(
      TxnColumn.values.map((e) => e.name).toList(),
      (l, v) => txnColumnLabel(l, TxnColumn.values.byName(v)),
    ),
  );

  static final defaultFilterId = SettingDef.optionalString(
    key: 'transactions.defaultFilterId',
    section: SettingSection.transactions,
    label: (l) => l.setDefaultFilter,
    editor: const CustomEditor('/transactions/filters'),
  );

  static final all = <SettingDef<Object?>>[
    grouping,
    sort,
    runningBalance,
    visibleColumns,
    defaultFilterId,
  ];
}

String txnColumnLabel(AppLocalizations l, TxnColumn c) => switch (c) {
  TxnColumn.date => l.fieldDate,
  TxnColumn.payee => l.fieldPayee,
  TxnColumn.category => l.fieldCategory,
  TxnColumn.account => l.fieldAccount,
  TxnColumn.tags => l.navTags,
  TxnColumn.note => l.fieldNote,
  TxnColumn.status => l.fieldStatus,
  TxnColumn.amount => l.fieldAmount,
  TxnColumn.balance => l.fieldBalance,
};

abstract final class CategorySettings {
  static final defaultSet = SettingDef.choice<DefaultCategorySet>(
    key: 'categories.defaultSet',
    section: SettingSection.categories,
    values: DefaultCategorySet.values,
    defaultValue: DefaultCategorySet.de,
    label: (l) => l.setDefaultCategorySet,
    valueLabel: (l, v) => switch (v) {
      DefaultCategorySet.en => 'English',
      DefaultCategorySet.de => 'Deutsch',
    },
  );

  static final manage = SettingDef.string(
    key: 'categories.manage',
    section: SettingSection.categories,
    defaultValue: '',
    label: (l) => l.setManageCategories,
    editor: const CustomEditor('/more/categories'),
  );

  static final manageTags = SettingDef.string(
    key: 'categories.manageTags',
    section: SettingSection.categories,
    defaultValue: '',
    label: (l) => l.setManageTags,
    editor: const CustomEditor('/more/tags'),
    module: AppModule.tags.name,
  );

  static final manageCustomFields = SettingDef.string(
    key: 'categories.manageCustomFields',
    section: SettingSection.categories,
    defaultValue: '',
    label: (l) => l.setManageCustomFields,
    editor: const CustomEditor('/more/custom-fields'),
    module: AppModule.customFields.name,
  );

  static final all = <SettingDef<Object?>>[
    defaultSet,
    manage,
    manageTags,
    manageCustomFields,
  ];
}

abstract final class BudgetSettings {
  static final periodType = SettingDef.choice<BudgetPeriodType>(
    key: 'budgets.periodType',
    section: SettingSection.budgets,
    values: BudgetPeriodType.values,
    defaultValue: BudgetPeriodType.monthly,
    label: (l) => l.setPeriodType,
    valueLabel: (l, v) => switch (v) {
      BudgetPeriodType.monthly => l.setOptMonthly,
      BudgetPeriodType.weekly => l.setOptWeekly,
      BudgetPeriodType.biWeekly => l.setOptBiWeekly,
      BudgetPeriodType.quarterly => l.setOptQuarterly,
      BudgetPeriodType.yearly => l.setOptYearly,
    },
    module: AppModule.budgets.name,
  );

  /// 1–28, or 0 for "last day of the month".
  static final startDay = SettingDef.integer(
    key: 'budgets.startDay',
    section: SettingSection.budgets,
    defaultValue: 1,
    min: 0,
    max: 28,
    label: (l) => l.setStartDay,
    description: (l) => l.setStartDayDesc,
    module: AppModule.budgets.name,
  );

  static final salaryBased = SettingDef.boolean(
    key: 'budgets.salaryBased',
    section: SettingSection.budgets,
    defaultValue: false,
    label: (l) => l.setSalaryBased,
    description: (l) => l.setSalaryBasedDesc,
    keywords: const ['gehalt', 'payday'],
    module: AppModule.budgets.name,
  );

  static final salaryRuleId = SettingDef.optionalString(
    key: 'budgets.salaryRuleId',
    section: SettingSection.budgets,
    label: (l) => l.setSalaryRule,
    editor: const CustomEditor('/plan/recurring/pick'),
    module: AppModule.budgets.name,
  );

  static final weekendShift = SettingDef.choice<WeekendShift>(
    key: 'budgets.weekendShift',
    section: SettingSection.budgets,
    values: WeekendShift.values,
    defaultValue: WeekendShift.previous,
    label: (l) => l.setWeekendShift,
    valueLabel: weekendShiftLabel,
    keywords: const ['holiday', 'feiertag', 'business day'],
    module: AppModule.budgets.name,
  );

  static final holidayCountry = SettingDef.string(
    key: 'budgets.holidayCountry',
    section: SettingSection.budgets,
    defaultValue: 'DE',
    label: (l) => l.setHolidayCountry,
    editor: ChoiceEditor(const [
      'DE',
      'AT',
      'CH',
      'none',
    ], (l, v) => v == 'none' ? l.commonNone : v),
    module: AppModule.budgets.name,
  );

  /// Federal state / canton code, e.g. `BY`; empty = nationwide only.
  static final holidayRegion = SettingDef.string(
    key: 'budgets.holidayRegion',
    section: SettingSection.budgets,
    defaultValue: '',
    label: (l) => l.setHolidayRegion,
    editor: ChoiceEditor(const [
      '',
      'BW',
      'BY',
      'BE',
      'BB',
      'HB',
      'HH',
      'HE',
      'MV',
      'NI',
      'NW',
      'RP',
      'SL',
      'SN',
      'ST',
      'SH',
      'TH',
    ], (l, v) => v.isEmpty ? l.setOptNationwide : v),
    module: AppModule.budgets.name,
  );

  static final mode = SettingDef.choice<BudgetMode>(
    key: 'budgets.mode',
    section: SettingSection.budgets,
    values: BudgetMode.values,
    defaultValue: BudgetMode.tracking,
    label: (l) => l.setBudgetMode,
    valueLabel: (l, v) => switch (v) {
      BudgetMode.tracking => l.setOptTracking,
      BudgetMode.envelope => l.setOptEnvelope,
    },
    keywords: const ['zero-based', 'envelope', 'umschlag'],
    module: AppModule.budgets.name,
  );

  static final defaultRollover = SettingDef.choice<RolloverMode>(
    key: 'budgets.defaultRollover',
    section: SettingSection.budgets,
    values: RolloverMode.values,
    defaultValue: RolloverMode.none,
    label: (l) => l.setDefaultRollover,
    valueLabel: rolloverLabel,
    module: AppModule.budgets.name,
  );

  static final warnThreshold = SettingDef.integer(
    key: 'budgets.warnThreshold',
    section: SettingSection.budgets,
    defaultValue: 80,
    min: 1,
    max: 100,
    unit: (l) => '%',
    label: (l) => l.setWarnThreshold,
    scopes: const {SettingScope.global, SettingScope.category},
    module: AppModule.budgets.name,
  );

  /// Show planned entries and unposted recurring occurrences in budgets
  /// (marked as outstanding, never counted as spent).
  static final showOutstanding = SettingDef.boolean(
    key: 'budgets.showOutstanding',
    section: SettingSection.budgets,
    defaultValue: true,
    label: (l) => l.setShowOutstanding,
    description: (l) => l.setShowOutstandingDesc,
    keywords: const ['planned', 'geplant', 'upcoming', 'offen'],
    module: AppModule.budgets.name,
  );

  static final all = <SettingDef<Object?>>[
    periodType,
    startDay,
    salaryBased,
    salaryRuleId,
    weekendShift,
    holidayCountry,
    holidayRegion,
    mode,
    defaultRollover,
    warnThreshold,
    showOutstanding,
  ];
}

String weekendShiftLabel(AppLocalizations l, WeekendShift v) => switch (v) {
  WeekendShift.none => l.setOptNoShift,
  WeekendShift.previous => l.setOptPreviousBusinessDay,
  WeekendShift.next => l.setOptNextBusinessDay,
};

String rolloverLabel(AppLocalizations l, RolloverMode v) => switch (v) {
  RolloverMode.none => l.setOptNoRollover,
  RolloverMode.leftover => l.setOptRolloverLeftover,
  RolloverMode.overspent => l.setOptRolloverOverspent,
  RolloverMode.both => l.setOptRolloverBoth,
};

abstract final class RecurringSettings {
  static final defaultPostingMode = SettingDef.string(
    key: 'recurring.defaultPostingMode',
    section: SettingSection.recurring,
    defaultValue: 'remindConfirm',
    label: (l) => l.setDefaultPostingMode,
    editor: ChoiceEditor(const [
      'autoPost',
      'remindConfirm',
    ], (l, v) => v == 'autoPost' ? l.setOptAutoPost : l.setOptRemindConfirm),
  );

  static final reminderLeadDays = SettingDef.integer(
    key: 'recurring.reminderLeadDays',
    section: SettingSection.recurring,
    defaultValue: 2,
    min: 0,
    max: 30,
    label: (l) => l.setReminderLeadDays,
  );

  static final notificationTime = SettingDef.integer(
    key: 'recurring.notificationTime',
    section: SettingSection.recurring,
    defaultValue: 9 * 60,
    min: 0,
    max: 24 * 60 - 1,
    label: (l) => l.setNotificationTime,
    editor: const TimeOfDayEditor(),
  );

  static final quietHoursStart = SettingDef.integer(
    key: 'recurring.quietHoursStart',
    section: SettingSection.recurring,
    defaultValue: 22 * 60,
    min: 0,
    max: 24 * 60 - 1,
    label: (l) => l.setQuietHoursStart,
    editor: const TimeOfDayEditor(),
  );

  static final quietHoursEnd = SettingDef.integer(
    key: 'recurring.quietHoursEnd',
    section: SettingSection.recurring,
    defaultValue: 7 * 60,
    min: 0,
    max: 24 * 60 - 1,
    label: (l) => l.setQuietHoursEnd,
    editor: const TimeOfDayEditor(),
  );

  static final notifyBills = SettingDef.boolean(
    key: 'recurring.notifyBills',
    section: SettingSection.recurring,
    defaultValue: true,
    label: (l) => l.setNotifyBills,
  );

  static final notifyIncome = SettingDef.boolean(
    key: 'recurring.notifyIncome',
    section: SettingSection.recurring,
    defaultValue: false,
    label: (l) => l.setNotifyIncome,
  );

  static final notifyLowBalance = SettingDef.boolean(
    key: 'recurring.notifyLowBalance',
    section: SettingSection.recurring,
    defaultValue: true,
    label: (l) => l.setNotifyLowBalance,
  );

  static final notifyBudget = SettingDef.boolean(
    key: 'recurring.notifyBudget',
    section: SettingSection.recurring,
    defaultValue: true,
    label: (l) => l.setNotifyBudget,
    module: AppModule.budgets.name,
  );

  static final all = <SettingDef<Object?>>[
    defaultPostingMode,
    reminderLeadDays,
    notificationTime,
    quietHoursStart,
    quietHoursEnd,
    notifyBills,
    notifyIncome,
    notifyLowBalance,
    notifyBudget,
  ];
}

abstract final class ForecastSettings {
  /// Longest cash-flow forecast horizon.
  static const maxHorizonMonths = 120;

  static final horizonMonths = SettingDef.integer(
    key: 'forecast.horizonMonths',
    section: SettingSection.forecast,
    defaultValue: 3,
    min: 1,
    max: maxHorizonMonths,
    label: (l) => l.setHorizonMonths,
    module: AppModule.forecast.name,
  );

  static final variableMethod = SettingDef.choice<VariableSpendingMethod>(
    key: 'forecast.variableMethod',
    section: SettingSection.forecast,
    values: VariableSpendingMethod.values,
    defaultValue: VariableSpendingMethod.median6,
    label: (l) => l.setVariableMethod,
    valueLabel: (l, v) => switch (v) {
      VariableSpendingMethod.budget => l.setOptFromBudget,
      VariableSpendingMethod.mean3 => l.setOptMean(3),
      VariableSpendingMethod.mean6 => l.setOptMean(6),
      VariableSpendingMethod.mean12 => l.setOptMean(12),
      VariableSpendingMethod.median3 => l.setOptMedian(3),
      VariableSpendingMethod.median6 => l.setOptMedian(6),
      VariableSpendingMethod.median12 => l.setOptMedian(12),
    },
    module: AppModule.forecast.name,
  );

  static final includePending = SettingDef.boolean(
    key: 'forecast.includePending',
    section: SettingSection.forecast,
    defaultValue: true,
    label: (l) => l.setIncludePending,
    module: AppModule.forecast.name,
  );

  static final includePlanned = SettingDef.boolean(
    key: 'forecast.includePlanned',
    section: SettingSection.forecast,
    defaultValue: true,
    label: (l) => l.setIncludePlanned,
    module: AppModule.forecast.name,
  );

  /// Default low-balance threshold in minor units; accounts can override.
  static final lowBalanceThreshold = SettingDef.optionalInt(
    key: 'forecast.lowBalanceThreshold',
    section: SettingSection.forecast,
    defaultValue: 0,
    label: (l) => l.setLowBalanceThreshold,
    editor: const MoneyEditor(),
    scopes: const {SettingScope.global, SettingScope.account},
  );

  static final inflationBp = SettingDef.integer(
    key: 'forecast.inflationBp',
    section: SettingSection.forecast,
    defaultValue: 200,
    min: -500,
    max: 2000,
    label: (l) => l.setInflation,
    editor: const PercentBpEditor(min: -500, max: 2000),
    module: AppModule.forecast.name,
  );

  static final defaultReturnBp = SettingDef.integer(
    key: 'forecast.defaultReturnBp',
    section: SettingSection.forecast,
    defaultValue: 0,
    min: -2000,
    max: 3000,
    label: (l) => l.setDefaultReturn,
    description: (l) => l.setDefaultReturnDesc,
    editor: const PercentBpEditor(min: -2000, max: 3000),
    module: AppModule.forecast.name,
  );

  static final projectionYears = SettingDef.integer(
    key: 'forecast.projectionYears',
    section: SettingSection.forecast,
    defaultValue: 20,
    min: 1,
    max: 40,
    label: (l) => l.setProjectionYears,
    module: AppModule.forecast.name,
  );

  static final realValues = SettingDef.boolean(
    key: 'forecast.realValues',
    section: SettingSection.forecast,
    defaultValue: false,
    label: (l) => l.setRealValues,
    description: (l) => l.setRealValuesDesc,
    module: AppModule.forecast.name,
  );

  /// Adds a chart line with all compared scenarios applied together.
  static final combineScenarios = SettingDef.boolean(
    key: 'forecast.combineScenarios',
    section: SettingSection.forecast,
    defaultValue: false,
    label: (l) => l.setCombineScenarios,
    description: (l) => l.setCombineScenariosDesc,
    module: AppModule.scenarios.name,
  );

  /// Wide layouts: the board's side panel (scenarios, "Can I afford it?",
  /// warnings, big events) is collapsed. Toggled from the board.
  static final sidePanelHidden = SettingDef.boolean(
    key: 'forecast.sidePanelHidden',
    section: SettingSection.forecast,
    defaultValue: false,
    label: (l) => l.setForecastSidePanelHidden,
    hidden: true,
    deviceLocal: true,
    module: AppModule.forecast.name,
  );

  static final all = <SettingDef<Object?>>[
    horizonMonths,
    variableMethod,
    includePending,
    includePlanned,
    lowBalanceThreshold,
    inflationBp,
    defaultReturnBp,
    projectionYears,
    realValues,
    combineScenarios,
    sidePanelHidden,
  ];
}

abstract final class ReportSettings {
  static final defaultPeriod = SettingDef.choice<ReportPeriod>(
    key: 'reports.defaultPeriod',
    section: SettingSection.reports,
    values: ReportPeriod.values,
    defaultValue: ReportPeriod.thisMonth,
    label: (l) => l.setReportPeriod,
    valueLabel: reportPeriodLabel,
  );

  static final excludedCategories = SettingDef.stringList(
    key: 'reports.excludedCategories',
    section: SettingSection.reports,
    defaultValue: const [],
    label: (l) => l.setExcludedCategories,
    editor: const CustomEditor('/more/categories/pick-multi'),
  );

  static final excludedAccounts = SettingDef.stringList(
    key: 'reports.excludedAccounts',
    section: SettingSection.reports,
    defaultValue: const [],
    label: (l) => l.setExcludedAccounts,
    editor: const CustomEditor('/accounts/pick-multi'),
  );

  static final excludedTags = SettingDef.stringList(
    key: 'reports.excludedTags',
    section: SettingSection.reports,
    defaultValue: const [],
    label: (l) => l.setExcludedTags,
    editor: const CustomEditor('/more/tags/pick-multi'),
    module: AppModule.tags.name,
  );

  static final all = <SettingDef<Object?>>[
    defaultPeriod,
    excludedCategories,
    excludedAccounts,
    excludedTags,
  ];
}

String reportPeriodLabel(AppLocalizations l, ReportPeriod v) => switch (v) {
  ReportPeriod.thisMonth => l.setOptThisMonth,
  ReportPeriod.lastMonth => l.setOptLastMonth,
  ReportPeriod.last3Months => l.setOptLastNMonths(3),
  ReportPeriod.last12Months => l.setOptLastNMonths(12),
  ReportPeriod.yearToDate => l.setOptYearToDate,
  ReportPeriod.thisYear => l.setOptThisYear,
  ReportPeriod.lastYear => l.setOptLastYear,
};

abstract final class SecuritySettings {
  static final appLock = SettingDef.boolean(
    key: 'security.appLock',
    section: SettingSection.security,
    defaultValue: false,
    label: (l) => l.setAppLock,
    keywords: const ['pin', 'biometric', 'sperre'],
    bootstrap: true,
  );

  static final lockMethod = SettingDef.choice<LockMethod>(
    key: 'security.lockMethod',
    section: SettingSection.security,
    values: LockMethod.values,
    defaultValue: LockMethod.pin,
    label: (l) => l.setLockMethod,
    valueLabel: (l, v) => switch (v) {
      LockMethod.biometric => l.setOptBiometric,
      LockMethod.pin => 'PIN',
      LockMethod.password => l.setOptPassword,
    },
    bootstrap: true,
  );

  /// Seconds in background before locking; 0 = immediately.
  static final lockTimeout = SettingDef.integer(
    key: 'security.lockTimeout',
    section: SettingSection.security,
    defaultValue: 60,
    min: 0,
    max: 3600,
    step: 30,
    unit: (l) => 's',
    label: (l) => l.setLockTimeout,
    bootstrap: true,
  );

  static final lockOnStart = SettingDef.boolean(
    key: 'security.lockOnStart',
    section: SettingSection.security,
    defaultValue: true,
    label: (l) => l.setLockOnStart,
    bootstrap: true,
  );

  static final all = <SettingDef<Object?>>[
    appLock,
    lockMethod,
    lockTimeout,
    lockOnStart,
  ];
}

abstract final class ImportExportSettings {
  static final csvDelimiter = SettingDef.choice<CsvDelimiter>(
    key: 'export.csvDelimiter',
    section: SettingSection.importExport,
    values: CsvDelimiter.values,
    defaultValue: CsvDelimiter.semicolon,
    label: (l) => l.setCsvDelimiter,
    valueLabel: (l, v) => switch (v) {
      CsvDelimiter.comma => ', (${l.setOptComma})',
      CsvDelimiter.semicolon => '; (${l.setOptSemicolon})',
      CsvDelimiter.tab => 'Tab',
      CsvDelimiter.pipe => '|',
    },
  );

  static final csvEncoding = SettingDef.choice<CsvEncoding>(
    key: 'export.csvEncoding',
    section: SettingSection.importExport,
    values: CsvEncoding.values,
    defaultValue: CsvEncoding.utf8Bom,
    label: (l) => l.setCsvEncoding,
    valueLabel: (l, v) => switch (v) {
      CsvEncoding.utf8 => 'UTF-8',
      CsvEncoding.utf8Bom => 'UTF-8 (BOM, Excel)',
      CsvEncoding.windows1252 => 'Windows-1252',
      CsvEncoding.iso8859_15 => 'ISO-8859-15',
    },
  );

  static final csvDateFormat = SettingDef.string(
    key: 'export.csvDateFormat',
    section: SettingSection.importExport,
    defaultValue: 'yyyy-MM-dd',
    label: (l) => l.setCsvDateFormat,
    editor: ChoiceEditor(const [
      'yyyy-MM-dd',
      'dd.MM.yyyy',
      'MM/dd/yyyy',
      'dd/MM/yyyy',
    ], (l, v) => v),
  );

  static final csvDecimalSeparator = SettingDef.choice<DecimalSeparator>(
    key: 'export.csvDecimalSeparator',
    section: SettingSection.importExport,
    values: DecimalSeparator.values,
    defaultValue: DecimalSeparator.locale,
    label: (l) => l.setCsvDecimalSeparator,
    valueLabel: (l, v) => switch (v) {
      DecimalSeparator.locale => l.setOptLocaleDefault,
      DecimalSeparator.comma => ', (${l.setOptComma})',
      DecimalSeparator.point => '. (${l.setOptPoint})',
    },
  );

  static final autoExport = SettingDef.choice<AutoExportSchedule>(
    key: 'export.autoExport',
    section: SettingSection.importExport,
    values: AutoExportSchedule.values,
    defaultValue: AutoExportSchedule.off,
    label: (l) => l.setAutoExport,
    valueLabel: (l, v) => switch (v) {
      AutoExportSchedule.off => l.setOptOff,
      AutoExportSchedule.daily => l.setOptDaily,
      AutoExportSchedule.weekly => l.setOptWeekly,
    },
    keywords: const ['backup', 'sicherung'],
    deviceLocal: true,
  );

  static final autoExportFolder = SettingDef.optionalString(
    key: 'export.autoExportFolder',
    section: SettingSection.importExport,
    label: (l) => l.setAutoExportFolder,
    editor: const CustomEditor('/more/export/folder'),
    deviceLocal: true,
  );

  static final autoExportKeep = SettingDef.integer(
    key: 'export.autoExportKeep',
    section: SettingSection.importExport,
    defaultValue: 10,
    min: 1,
    max: 100,
    label: (l) => l.setAutoExportKeep,
    deviceLocal: true,
  );

  static final lastAutoExport = SettingDef.optionalString(
    key: 'export.lastAutoExport',
    section: SettingSection.importExport,
    label: (l) => l.setAutoExport,
    hidden: true,
    deviceLocal: true,
  );

  static final profiles = SettingDef.string(
    key: 'import.profiles',
    section: SettingSection.importExport,
    defaultValue: '',
    label: (l) => l.setImportProfiles,
    editor: const CustomEditor('/more/import/history?tab=profiles'),
  );

  static final all = <SettingDef<Object?>>[
    csvDelimiter,
    csvEncoding,
    csvDateFormat,
    csvDecimalSeparator,
    autoExport,
    autoExportFolder,
    autoExportKeep,
    lastAutoExport,
    profiles,
  ];
}

abstract final class DataSettings {
  /// Desktop only: directory holding the database file; empty = default.
  static final storageLocation = SettingDef.string(
    key: 'data.storageLocation',
    section: SettingSection.data,
    defaultValue: '',
    label: (l) => l.setStorageLocation,
    editor: const CustomEditor('/more/settings/data'),
    bootstrap: true,
    deviceLocal: true,
  );

  static final tombstoneDays = SettingDef.integer(
    key: 'data.tombstoneDays',
    section: SettingSection.data,
    defaultValue: 90,
    min: 7,
    max: 3650,
    label: (l) => l.setTombstoneDays,
    description: (l) => l.setTombstoneDaysDesc,
  );

  /// ISO timestamp of the last tombstone purge (startup task, weekly).
  static final lastTombstonePurge = SettingDef.optionalString(
    key: 'data.lastTombstonePurge',
    section: SettingSection.data,
    label: (l) => l.exportPurgeLast,
    hidden: true,
    deviceLocal: true,
  );

  static final all = <SettingDef<Object?>>[
    storageLocation,
    tombstoneDays,
    lastTombstonePurge,
  ];
}

abstract final class SyncSettings {
  static final deviceName = SettingDef.string(
    key: 'sync.deviceName',
    section: SettingSection.sync,
    defaultValue: '',
    label: (l) => l.setDeviceName,
    hidden: true,
  );

  static final all = <SettingDef<Object?>>[deviceName];
}

/// Every setting, in display order.
final allSettings = <SettingDef<Object?>>[
  ...GeneralSettings.all,
  ...AppearanceSettings.all,
  ...PrivacySettings.all,
  ...NavigationSettings.all,
  ...DashboardSettings.all,
  ...EntrySettings.all,
  ...TransactionSettings.all,
  ...CategorySettings.all,
  ...BudgetSettings.all,
  ...RecurringSettings.all,
  ...ForecastSettings.all,
  ...ReportSettings.all,
  ...SecuritySettings.all,
  ...ImportExportSettings.all,
  ...DataSettings.all,
  ...SyncSettings.all,
  ...BackupSettings.all,
];

/// Keys of the [SettingDef.deviceLocal] settings: never synced, kept by a
/// restore.
final Set<String> deviceLocalSettingKeys = {
  for (final d in allSettings)
    if (d.deviceLocal) d.key,
};

/// Whether the `settings` row [rowId] (`<scope>|<key>`) holds a
/// device-local setting.
bool isDeviceLocalSettingRow(String rowId) =>
    deviceLocalSettingKeys.contains(rowId.substring(rowId.indexOf('|') + 1));

final Map<String, SettingDef<Object?>> settingsByKey = {
  for (final d in allSettings) d.key: d,
};

String sectionLabel(AppLocalizations l, SettingSection s) => switch (s) {
  SettingSection.general => l.setSecGeneral,
  SettingSection.appearance => l.setSecAppearance,
  SettingSection.privacy => l.setSecPrivacy,
  SettingSection.navigation => l.setSecNavigation,
  SettingSection.dashboard => l.setSecDashboard,
  SettingSection.entry => l.setSecEntry,
  SettingSection.transactions => l.navTransactions,
  SettingSection.categories => l.setSecCategories,
  SettingSection.budgets => l.setSecBudgets,
  SettingSection.recurring => l.setSecRecurring,
  SettingSection.forecast => l.setSecForecast,
  SettingSection.reports => l.navReports,
  SettingSection.security => l.setSecSecurity,
  SettingSection.importExport => l.setSecImportExport,
  SettingSection.data => l.setSecData,
  SettingSection.sync => 'Sync',
};
