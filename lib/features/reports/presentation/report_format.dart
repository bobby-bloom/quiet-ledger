import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/ui/amount_text.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/core/calendar/budget_period.dart';
import 'package:personal_finance/core/money/money_format.dart';
import 'package:personal_finance/features/reports/domain/report_models.dart';
import 'package:personal_finance/features/reports/domain/report_periods.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

/// Locale-aware formatting used across the report screens.
class ReportFormat {
  ReportFormat({
    required this.l10n,
    required this.money,
    required this.dates,
    required this.locale,
    this.hidden = false,
  });

  factory ReportFormat.of(BuildContext context, WidgetRef ref) => ReportFormat(
    l10n: context.l10n,
    money: ref.watch(moneyFormatterProvider),
    dates: ref.watch(dateFormatsProvider),
    locale: ref.watch(formatLocaleProvider),
    hidden: ref.watch(privacyModeProvider),
  );

  final AppLocalizations l10n;
  final MoneyFormatter money;
  final DateFormats dates;
  final String locale;

  /// Privacy mode: amounts render as a mask.
  final bool hidden;

  static const mask = '•••';

  String amount(int minor, {bool signed = false}) =>
      hidden ? mask : money.minor(minor, explicitPlus: signed);

  /// Whole-unit amount for axis labels and summaries, e.g. `€1.2K`.
  String compact(int minor) {
    if (hidden) return mask;
    final f = NumberFormat.compactSimpleCurrency(locale: locale, name: 'EUR');
    return f.format(minor / 100);
  }

  /// Basis points as a percentage with one decimal (`27.3%` / `27,3 %`).
  String percent(int bp, {bool signed = false}) {
    final f = NumberFormat.decimalPercentPattern(
      locale: locale,
      decimalDigits: 1,
    );
    final text = f.format(bp.abs() / 10000);
    if (bp < 0) return '${MoneyFormatter.minus}$text';
    if (signed && bp > 0) return '+$text';
    return text;
  }

  String categoryName(String? name) => name ?? l10n.reportsUncategorized;

  String _quarter(DateTime d) =>
      l10n.reportsQuarterLabel((d.month - 1) ~/ 3 + 1, '${d.year}');

  /// Human label of a report range: "October 2026", "2026", "Q1 2026" or
  /// "1 Oct 2026 – 23 Oct 2026".
  String range(DateRange r) {
    final months = wholeMonths(r);
    if (months == 1) return dates.monthYear(r.start);
    if (isSingleYear(r)) return '${r.start.year}';
    if (months == 3 && (r.start.month - 1) % 3 == 0) return _quarter(r.start);
    if (r.days == 1) return dates.medium(r.start);
    if (months != null && months > 1) {
      final f = DateFormat.yMMM(locale);
      return '${f.format(r.start)} – '
          '${f.format(DateTime(r.end.year, r.end.month - 1))}';
    }
    return '${dates.medium(r.start)} – ${dates.medium(r.last)}';
  }

  /// Label of one bucket of a time series. [short] is used on chart axes.
  String bucket(DateRange b, ReportInterval interval, {bool short = false}) {
    switch (interval) {
      case ReportInterval.month:
        if (wholeMonths(b) == 1) {
          return short ? dates.monthShort(b.start) : dates.monthYear(b.start);
        }
      case ReportInterval.quarter:
        if (wholeMonths(b) == 3) {
          return short
              ? l10n.reportsQuarterLabel(
                  (b.start.month - 1) ~/ 3 + 1,
                  DateFormat('yy', locale).format(b.start),
                )
              : _quarter(b.start);
        }
      case ReportInterval.year:
        if (wholeMonths(b) == 12) return '${b.start.year}';
      case ReportInterval.budgetPeriod:
        break;
    }
    if (short) return DateFormat.Md(locale).format(b.start);
    return range(b);
  }
}
