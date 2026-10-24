import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/ui/amount_text.dart';
import 'package:personal_finance/app/ui/app_icons.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/lookups.dart';
import 'package:personal_finance/core/money/money.dart';
import 'package:personal_finance/core/money/money_format.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/accounts/data/net_worth.dart';
import 'package:personal_finance/features/dashboard/data/dashboard_layout.dart';
import 'package:personal_finance/features/dashboard/presentation/dashboard_period.dart';
import 'package:personal_finance/features/dashboard/presentation/widgets/dash_card.dart';
import 'package:personal_finance/features/forecast/domain/forecast_models.dart';
import 'package:personal_finance/features/forecast/presentation/forecast_providers.dart';
import 'package:personal_finance/features/reports/data/report_queries.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

/// Hero amount with the cents in a lighter step (design: displaySmall).
class HeroAmount extends ConsumerWidget {
  const HeroAmount(this.minor, {super.key});

  final int minor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.watch(moneyFormatterProvider);
    final hidden = ref.watch(privacyModeProvider);
    if (hidden) {
      return AmountText(
        minor,
        colored: false,
        style: context.text.displaySmall,
      );
    }
    final (whole, frac) = fmt.formatHero(Money(minor));
    return Semantics(
      label: fmt.format(Money(minor)),
      child: ExcludeSemantics(
        child: Text.rich(
          TextSpan(
            text: whole,
            style: context.text.displaySmall,
            children: [
              TextSpan(
                text: frac,
                style: context.text.displaySmall?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Net worth: hero on phones (no card), card with a 12-month line on wide
/// screens.
class NetWorthWidget extends ConsumerWidget {
  const NetWorthWidget({
    required this.card,
    super.key,
    this.options = const [],
  });

  final bool card;
  final List<DashOption> options;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final summary = ref.watch(netWorthSummaryProvider).value;
    final series = ref.watch(netWorthSeriesProvider(13)).value ?? const [];
    final accounts = (ref.watch(accountsProvider).value ?? const <Account>[])
        .where((a) => !a.archived && a.includeInNetWorth)
        .length;
    final net = summary?.netMinor ?? 0;
    // Change since the end of last month / over 12 months.
    final lastMonthEnd = series.length >= 2
        ? series[series.length - 2].netWorthMinor
        : null;
    final yearAgo = series.length >= 13 ? series.first.netWorthMinor : null;
    final thisMonth = lastMonthEnd == null ? null : net - lastMonthEnd;
    final fin = context.finance;

    Widget change(int delta, String suffix) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          delta >= 0 ? Icons.north_east : Icons.south_east,
          size: 16,
          color: delta >= 0 ? context.colors.primary : fin.expense,
        ),
        const SizedBox(width: 4),
        AmountText(
          delta.abs(),
          colored: false,
          style: context.text.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: delta >= 0 ? context.colors.primary : fin.expense,
          ),
        ),
        Text(
          ' $suffix',
          style: context.text.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: delta >= 0 ? context.colors.primary : fin.expense,
          ),
        ),
      ],
    );

    final peek = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!card)
          Text(
            l.dashNetWorth,
            style: context.text.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: context.colors.onSurfaceVariant,
            ),
          ),
        HeroAmount(net),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (thisMonth != null) change(thisMonth, l.dashThisMonth),
            Text(
              l.dashAcrossAccounts(accounts),
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            if (card && yearAgo != null)
              Text(
                l.dashIn12Months(
                  ref
                      .watch(moneyFormatterProvider)
                      .format(Money(net - yearAgo), explicitPlus: true),
                ),
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ],
    );

    // The phone hero never folds.
    if (!card) {
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go('/accounts'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
          child: peek,
        ),
      );
    }
    return DashCard(
      type: DashboardWidgetType.netWorth,
      title: l.dashNetWorth,
      subtitle: l.dashLast12Months,
      options: options,
      onTap: () => context.push('/reports/net-worth'),
      peek: peek,
      child: series.length < 2
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Sparkline(
                  values: [for (final p in series.skip(1)) p.netWorthMinor],
                  height: 96,
                  fill: true,
                  semanticLabel: l.dashNetWorthChart,
                ),
                const SizedBox(height: 4),
                _MonthAxis(
                  months: [for (final p in series.skip(1)) p.range.start],
                ),
              ],
            ),
    );
  }
}

class _MonthAxis extends ConsumerWidget {
  const _MonthAxis({required this.months});

  final List<DateTime> months;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dates = ref.watch(dateFormatsProvider);
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final m in months)
            Text(
              dates.monthShort(m),
              style: context.text.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.colors.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// Income, expenses and savings rate for the dashboard period.
class MonthSummaryWidget extends ConsumerWidget {
  const MonthSummaryWidget({super.key, this.options = const []});

  final List<DashOption> options;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final range = ref.watch(dashboardPeriodProvider);
    final s = ref.watch(monthSummaryProvider(range)).value;
    final dates = ref.watch(dateFormatsProvider);
    final fin = context.finance;
    final income = s?.incomeMinor ?? 0;
    final expense = s?.expenseMinor ?? 0;
    final rate = s?.savingsRateBp;
    final ratio = income <= 0 ? (expense > 0 ? 1.0 : 0.0) : expense / income;
    final current = range.contains(DateTime.now());

    Widget col(String label, Widget value, {Color? dot, bool end = false}) =>
        Column(
          crossAxisAlignment: end
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dot != null) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: dot,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelMedium?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            value,
          ],
        );

    return DashCard(
      type: DashboardWidgetType.monthSummary,
      title: current
          ? l.dashSoFar(dates.monthYear(range.start))
          : dates.monthYear(range.start),
      options: options,
      onTap: () => context.push('/reports/income-expense'),
      peek: Row(
        children: [
          Expanded(
            child: col(
              l.typeIncome,
              AmountText(
                income,
                explicitPlus: false,
                style: context.text.titleMedium?.copyWith(color: fin.income),
              ),
              dot: fin.income,
            ),
          ),
          Expanded(
            child: col(
              l.dashExpenses,
              AmountText(
                expense,
                colored: false,
                style: context.text.titleMedium?.copyWith(color: fin.expense),
              ),
              dot: fin.expenseFill,
            ),
          ),
          Expanded(
            child: col(
              l.dashSavingsRate,
              Text(
                rate == null ? '—' : '${(rate / 100).toStringAsFixed(1)}%',
                style: context.text.titleMedium,
              ),
              end: true,
            ),
          ),
        ],
      ),
      child: ExcludeSemantics(
        child: Column(
          children: [
            ProgressBar(value: income > 0 ? 1 : 0, color: fin.income),
            const SizedBox(height: 4),
            ProgressBar(value: ratio, color: fin.expenseFill),
          ],
        ),
      ),
    );
  }
}

/// Top expense categories of the dashboard period.
class TopCategoriesWidget extends ConsumerWidget {
  const TopCategoriesWidget({
    super.key,
    this.options = const [],
    this.limit = 5,
  });

  final List<DashOption> options;
  final int limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final range = ref.watch(dashboardPeriodProvider);
    final rows = ref
        .watch(topCategoriesProvider((range: range, limit: limit)))
        .value;
    final total = (rows ?? const []).fold(0, (a, r) => a + r.amountMinor);
    final spent =
        ref.watch(monthSummaryProvider(range)).value?.expenseMinor ?? 0;
    final top = rows == null || rows.isEmpty ? null : rows.first;
    return DashCard(
      type: DashboardWidgetType.topCategories,
      title: l.dashTopCategories,
      actionLabel: l.navReports,
      onAction: () => context.push('/reports/spending'),
      options: options,
      peek: rows == null
          ? null
          : top == null
          ? Text(l.dashNoSpending, style: context.text.bodySmall)
          : PeekText(
              [
                '${top.name ?? l.dashUncategorised} ${PeekText.slot()}',
                if (spent > 0)
                  l.dashCardShareOfSpending(
                    '${(top.amountMinor * 100 / spent).round()}%',
                  ),
              ].join(' · '),
              amounts: [top.amountMinor],
            ),
      child: rows == null
          ? const SizedBox(height: 80)
          : rows.isEmpty
          ? const SizedBox.shrink()
          : Column(
              children: [
                for (final (i, r) in rows.indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            IconTile(
                              icon: AppIcons.of(r.icon),
                              color: r.color == null
                                  ? context.finance.chartAt(i)
                                  : Color(r.color!),
                              size: 28,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                r.name ?? l.dashUncategorised,
                                style: context.text.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            AmountText(
                              r.amountMinor,
                              colored: false,
                              style: context.text.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ProgressBar(
                          value: total == 0 ? 0 : r.amountMinor / total,
                          color: context.finance.chartAt(i),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Mini forecast: lowest point of one account (or the total).
class MiniForecastWidget extends ConsumerWidget {
  const MiniForecastWidget({
    super.key,
    this.accountId,
    this.options = const [],
    this.compact = false,
  });

  final String? accountId;
  final List<DashOption> options;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final accounts = ref.watch(accountMapProvider);
    final defaultId = ref.watch(
      settingsProvider.select((s) => s.get(EntrySettings.defaultAccountId)),
    );
    final id =
        accountId ?? (accounts.containsKey(defaultId) ? defaultId : null);
    final mini = ref.watch(miniForecastProvider(id));
    final fmt = ref.watch(moneyFormatterProvider);
    final dates = ref.watch(dateFormatsProvider);
    final name = id == null ? l.dashAllAccounts : accounts[id]?.name ?? '';

    final m = mini.value;
    Widget? peek;
    if (m != null) {
      // Amounts go in as slots so privacy mode masks them.
      final low = PeekText.slot();
      final date = dates.medium(m.lowest.date);
      final warn = m.warning != null;
      final String sentence;
      if (m.warning == WarningKind.belowZero) {
        sentence = l.forecastLowestBelowZero(low, date);
      } else if (m.warning == WarningKind.belowThreshold &&
          m.thresholdMinor != null) {
        sentence = l.forecastLowestBelowThreshold(low, date, PeekText.slot(1));
      } else {
        sentence = l.forecastLowestOk(low, date);
      }
      final color = warn
          ? context.finance.warning
          : context.colors.onSurfaceVariant;
      peek = Row(
        children: [
          if (warn) ...[
            Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: context.finance.warning,
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: PeekText(
              sentence,
              amounts: [m.lowest.amountMinor, m.thresholdMinor ?? 0],
              style: context.text.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      );
    }

    return DashCard(
      type: DashboardWidgetType.forecast,
      title: l.navForecast,
      subtitle: name,
      options: options,
      onTap: () => context.go('/forecast'),
      peek: peek,
      child: mini.when(
        loading: () => const SizedBox(height: 96),
        error: (e, _) =>
            Text(l.commonError('$e'), style: context.text.bodySmall),
        data: (m) => Sparkline(
          values: [for (final p in m.points) p.balanceMinor],
          threshold: m.thresholdMinor,
          markLowest: true,
          semanticLabel: _lowestSentence(l, fmt, dates, m),
        ),
      ),
    );
  }

  /// The lowest point in words, for the chart's semantics label.
  static String _lowestSentence(
    AppLocalizations l,
    MoneyFormatter fmt,
    DateFormats dates,
    MiniForecast m,
  ) {
    final low = fmt.format(Money(m.lowest.amountMinor));
    final date = dates.medium(m.lowest.date);
    if (m.warning == WarningKind.belowZero) {
      return l.forecastLowestBelowZero(low, date);
    }
    if (m.warning == WarningKind.belowThreshold && m.thresholdMinor != null) {
      return l.forecastLowestBelowThreshold(
        low,
        date,
        fmt.format(Money(m.thresholdMinor!)),
      );
    }
    return l.forecastLowestOk(low, date);
  }
}

/// Account list with balances.
class AccountsWidget extends ConsumerWidget {
  const AccountsWidget({super.key, this.options = const [], this.limit = 8});

  final List<DashOption> options;
  final int limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final accounts = (ref.watch(accountsProvider).value ?? const <Account>[])
        .where((a) => !a.archived)
        .toList();
    final balances = ref.watch(accountBalancesProvider).value ?? const {};
    int balance(Account a) => balances[a.id] ?? a.openingBalanceMinor;
    final total = accounts.fold(0, (sum, a) => sum + balance(a));
    return DashCard(
      type: DashboardWidgetType.accounts,
      title: l.navAccounts,
      actionLabel: l.dashViewAll,
      onAction: () => context.go('/accounts'),
      options: options,
      peek: accounts.isEmpty
          ? Text(l.commonEmpty, style: context.text.bodySmall)
          : PeekText(
              l.dashCardAccountsTotal(PeekText.slot(), accounts.length),
              amounts: [total],
            ),
      child: accounts.isEmpty
          ? const SizedBox.shrink()
          : Column(
              children: [
                for (final (i, a) in accounts.take(limit).indexed)
                  InkWell(
                    onTap: () => context.push('/accounts/${a.id}'),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        border: i == 0
                            ? null
                            : Border(
                                top: BorderSide(
                                  color: context.colors.surfaceContainerHigh,
                                ),
                              ),
                      ),
                      child: Row(
                        children: [
                          IconTile(
                            icon: AppIcons.of(
                              a.icon,
                              fallback: Icons.account_balance_outlined,
                            ),
                            color: a.color == null ? null : Color(a.color!),
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              a.name,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          AmountText(
                            balance(a),
                            colored: false,
                            style: context.text.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
