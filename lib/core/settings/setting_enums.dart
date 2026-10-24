// Value enums of the settings catalogue. Kept free of Flutter imports so
// pure-Dart domain code (forecast engine, budgets, import) can use them.
// Re-exported by app_settings.dart.

enum AppLanguage { system, en, de }

enum FirstDayOfWeek { locale, monday, sunday, saturday }

enum StartScreen { home, transactions, plan, forecast }

enum AppThemeMode { system, light, dark }

enum AccentScheme { spruce, blue, violet, amber, rose, slate, custom }

enum Density { comfortable, compact }

enum AmountColorStyle { colorCoded, neutral, signOnly }

enum TxnGrouping { day, week, month, none }

enum TxnSort { dateDesc, dateAsc, amountDesc, amountAsc, payee }

enum DefaultTxnDate { today, lastUsed }

enum DefaultTxnType { expense, income, lastUsed }

enum BudgetPeriodType { monthly, weekly, biWeekly, quarterly, yearly }

enum WeekendShift { none, previous, next }

enum BudgetMode { tracking, envelope }

enum RolloverMode { none, leftover, overspent, both }

enum VariableSpendingMethod {
  budget,
  mean3,
  mean6,
  mean12,
  median3,
  median6,
  median12,
}

enum ReportPeriod {
  thisMonth,
  lastMonth,
  last3Months,
  last12Months,
  yearToDate,
  thisYear,
  lastYear,
}

enum LockMethod { biometric, pin, password }

enum AutoExportSchedule { off, daily, weekly }

enum CsvDelimiter { comma, semicolon, tab, pipe }

enum CsvEncoding { utf8, utf8Bom, windows1252, iso8859_15 }

enum DecimalSeparator { locale, comma, point }

enum DefaultCategorySet { en, de }

enum DashboardPeriod { budgetPeriod, calendarMonth }

/// Switchable modules (Settings › Navigation & modules).
enum AppModule {
  budgets,
  goals,
  forecast,
  scenarios,
  tags,
  customFields,
  attachments,
}

/// Destinations that can be placed in the bottom bar / rail.
enum NavTab { home, transactions, plan, forecast, accounts, reports, more }

/// Quick-add fields in their configurable order.
enum QuickAddField {
  amount,
  category,
  account,
  date,
  payee,
  note,
  tags,
  status,
}

/// Columns of the transaction list on wide screens.
enum TxnColumn {
  date,
  payee,
  category,
  account,
  tags,
  note,
  status,
  amount,
  balance,
}
