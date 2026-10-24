import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:personal_finance/core/money/money.dart';
import 'package:personal_finance/core/money/money_format.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';

/// The effective UI language code ('en' or 'de').
final languageCodeProvider = Provider<String>((ref) {
  final lang = ref.watch(
    settingsProvider.select((s) => s.get(GeneralSettings.language)),
  );
  if (lang != AppLanguage.system) return lang.name;
  final system = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  return system == 'de' ? 'de' : 'en';
});

/// Locale used for number/date formatting.
final formatLocaleProvider = Provider<String>((ref) {
  final custom = ref.watch(
    settingsProvider.select((s) => s.get(GeneralSettings.formatLocale)),
  );
  if (custom.isNotEmpty) return custom;
  return ref.watch(languageCodeProvider) == 'de' ? 'de_DE' : 'en_US';
});

final moneyFormatterProvider = Provider<MoneyFormatter>((ref) {
  final s = ref.watch(settingsProvider);
  return MoneyFormatter(
    locale: ref.watch(formatLocaleProvider),
    showCents: s.get(AppearanceSettings.showCents),
    signStyle: s.get(AppearanceSettings.signStyle),
  );
});

/// Date formatting according to settings.
class DateFormats {
  DateFormats(this.locale, String customPattern)
    : _custom = customPattern.isEmpty
          ? null
          : DateFormat(customPattern, locale);

  final String locale;
  final DateFormat? _custom;

  /// Short numeric date, e.g. 23.10.2026.
  String short(DateTime d) => (_custom ?? DateFormat.yMd(locale)).format(d);

  /// e.g. 23 Oct 2026 / 23. Okt. 2026.
  String medium(DateTime d) => DateFormat.yMMMd(locale).format(d);

  /// e.g. Fri, 23 Oct.
  String dayHeader(DateTime d) => DateFormat.MMMEd(locale).format(d);

  /// e.g. October 2026.
  String monthYear(DateTime d) => DateFormat.yMMMM(locale).format(d);

  /// e.g. Oct.
  String monthShort(DateTime d) => DateFormat.MMM(locale).format(d);

  /// e.g. Wed.
  String weekdayShort(DateTime d) => DateFormat.E(locale).format(d);

  String time(DateTime d) => DateFormat.Hm(locale).format(d);
}

final dateFormatsProvider = Provider<DateFormats>((ref) {
  final pattern = ref.watch(
    settingsProvider.select((s) => s.get(GeneralSettings.dateFormat)),
  );
  return DateFormats(ref.watch(formatLocaleProvider), pattern);
});

/// First day of week as DateTime.weekday (1 = Monday ... 7 = Sunday).
final firstDayOfWeekProvider = Provider<int>((ref) {
  final v = ref.watch(
    settingsProvider.select((s) => s.get(GeneralSettings.firstDayOfWeek)),
  );
  return switch (v) {
    FirstDayOfWeek.monday => DateTime.monday,
    FirstDayOfWeek.sunday => DateTime.sunday,
    FirstDayOfWeek.saturday => DateTime.saturday,
    FirstDayOfWeek.locale =>
      ref.watch(formatLocaleProvider).startsWith('en_US')
          ? DateTime.sunday
          : DateTime.monday,
  };
});

/// Convenience for formatting minor units directly.
extension MoneyFormatterX on MoneyFormatter {
  String minor(int minor, {bool explicitPlus = false}) =>
      format(Money(minor), explicitPlus: explicitPlus);
}
