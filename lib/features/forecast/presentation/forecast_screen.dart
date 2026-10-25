import 'dart:async';

import 'package:flutter/foundation.dart' show precisionErrorTolerance;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/amount_text.dart';
import 'package:personal_finance/app/ui/breakpoints.dart';
import 'package:personal_finance/app/ui/fold_card.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/lookups.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/forecast/domain/forecast_models.dart';
import 'package:personal_finance/features/forecast/domain/forecast_pipeline.dart';
import 'package:personal_finance/features/forecast/presentation/forecast_chart.dart';
import 'package:personal_finance/features/forecast/presentation/forecast_common.dart';
import 'package:personal_finance/features/forecast/presentation/forecast_format.dart';
import 'package:personal_finance/features/forecast/presentation/forecast_providers.dart';
import 'package:personal_finance/features/forecast/presentation/what_if_card.dart';
import 'package:personal_finance/features/scenarios/data/scenario_repository.dart';
import 'package:personal_finance/features/scenarios/domain/apply_scenario.dart';
import 'package:personal_finance/features/scenarios/domain/scenario.dart';

/// The forecast board (`/forecast`): horizon, account, balance curve with
/// threshold and lowest point, scenario overlays, period-end balances,
/// big events and the "Can I afford it?" check.
class ForecastScreen extends ConsumerWidget {
  const ForecastScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final enabled = ref.watch(
      settingsProvider.select((s) => s.moduleEnabled(AppModule.forecast)),
    );
    if (!enabled) {
      return ModuleOffView(
        title: l.forecastTitle,
        message: l.forecastModuleOff,
      );
    }
    final board = ref.watch(forecastBoardProvider);
    final accountMap = ref.watch(accountMapProvider);
    final selected = ref.watch(forecastAccountProvider);
    final result = board.value?.baseline;
    final accountIds = result?.accountIds ?? const <String>[];
    final accountId = selected != null && accountIds.contains(selected)
        ? selected
        : null;
    final accounts = [for (final id in accountIds) ?accountMap[id]];
    final size = WindowSize.of(context);

    return Scaffold(
      appBar: PageAppBar(
        title: l.forecastTitle,
        actions: [
          if (accounts.isNotEmpty)
            _AccountSelector(accounts: accounts, selectedId: accountId),
          IconButton(
            tooltip: l.forecastProjection,
            icon: const Icon(Icons.trending_up),
            onPressed: () => context.push('/forecast/projection'),
          ),
          if (size.isExpanded && accountIds.isNotEmpty)
            SidePanelButton(setting: ForecastSettings.sidePanelHidden),
        ],
      ),
      // Keep showing the previous result while a new one is computed.
      body: board.hasValue
          ? BusyBody(
              busy: board.isLoading,
              child: _Board(
                batch: board.value!,
                accountId: accountId,
                accounts: accounts,
              ),
            )
          : AsyncView(
              value: board,
              loading: ForecastLoading(message: l.forecastLoading),
              data: (b) =>
                  _Board(batch: b, accountId: accountId, accounts: accounts),
            ),
    );
  }
}

class _AccountSelector extends ConsumerWidget {
  const _AccountSelector({required this.accounts, required this.selectedId});

  final List<Account> accounts;
  final String? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final name = selectedId == null
        ? l.forecastTotal
        : accounts.firstWhere((a) => a.id == selectedId).name;
    void choose(String? id) =>
        ref.read(forecastAccountProvider.notifier).accountId = id;
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          leadingIcon: Icon(
            selectedId == null ? Icons.check : Icons.functions,
            size: 20,
          ),
          onPressed: () => choose(null),
          child: Text(l.forecastTotal),
        ),
        for (final a in accounts)
          MenuItemButton(
            leadingIcon: Icon(
              a.id == selectedId ? Icons.check : Icons.account_balance_outlined,
              size: 20,
            ),
            onPressed: () => choose(a.id),
            child: Text(a.name),
          ),
      ],
      builder: (context, controller, _) => Tooltip(
        message: l.forecastChooseAccount,
        child: TextButton.icon(
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
          iconAlignment: IconAlignment.end,
          icon: const Icon(Icons.expand_more),
          label: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          style: TextButton.styleFrom(
            foregroundColor: context.colors.onSurface,
            minimumSize: const Size(48, Space.minTouch),
          ),
        ),
      ),
    );
  }
}

class _Board extends ConsumerWidget {
  const _Board({
    required this.batch,
    required this.accountId,
    required this.accounts,
  });

  final CashflowBatch batch;
  final String? accountId;
  final List<Account> accounts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final result = batch.baseline;
    if (result.accountIds.isEmpty) {
      return EmptyState(
        icon: Icons.show_chart,
        message: l.forecastNoAccounts,
        actionLabel: l.forecastAddAccount,
        onAction: () => context.push('/accounts/new'),
      );
    }
    final scenariosOn = ref.watch(
      settingsProvider.select((s) => s.moduleEnabled(AppModule.scenarios)),
    );
    final compared = ref.watch(comparedScenariosProvider);
    final size = WindowSize.of(context);
    final gutter = size.isCompact ? Space.phoneGutter : Space.desktopGutter;
    final sideHidden = ref.watch(
      settingsProvider.select((s) => s.get(ForecastSettings.sidePanelHidden)),
    );

    final main = <Widget>[
      const _HorizonSelector(),
      const SizedBox(height: Space.md),
      _LowestHeader(result: result, accountId: accountId),
      const SizedBox(height: Space.xs),
      _ChartSection(
        batch: batch,
        accountId: accountId,
        accounts: accounts,
        compared: compared,
        height: size.isExpanded ? 300 : 200,
      ),
      const SizedBox(height: Space.md),
      _BalancesTable(batch: batch, accountId: accountId, compared: compared),
    ];
    final side = <Widget>[
      if (scenariosOn) ...[
        _ScenarioToggles(batch: batch, accountId: accountId),
        const SizedBox(height: Space.cardGap),
      ],
      WhatIfCard(accounts: accounts, initialAccountId: accountId),
      const SizedBox(height: Space.cardGap),
      _Warnings(result: result, accounts: accounts),
      const SizedBox(height: Space.cardGap),
      _BigEvents(result: result, accountId: accountId),
    ];

    // Wide layouts put [side] in a column of its own that the app bar can
    // collapse.
    if (size.isExpanded) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                gutter,
                Space.xs,
                sideHidden ? gutter : Space.cardGap / 2,
                Space.xl,
              ),
              children: main,
            ),
          ),
          if (!sideHidden)
            SizedBox(
              width: 380,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  Space.cardGap / 2,
                  Space.xs,
                  gutter,
                  Space.xl,
                ),
                children: side,
              ),
            ),
        ],
      );
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(gutter, Space.xs, gutter, 96),
      children: [
        ...main,
        const SizedBox(height: Space.cardGap),
        ...side,
      ],
    );
  }
}

/// Preset horizons plus a "Custom" segment that opens [_HorizonDialog].
/// Stretches to the full width and scrolls sideways when it does not fit.
class _HorizonSelector extends ConsumerWidget {
  const _HorizonSelector();

  static const _presets = [3, 6, 12, 36];

  /// Value of the custom segment.
  static const _custom = -1;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final horizon = ref.watch(forecastHorizonProvider);
    final custom = !_presets.contains(horizon);
    final notifier = ref.read(forecastHorizonProvider.notifier);

    Future<void> pickCustom() async {
      final months = await showDialog<int>(
        context: context,
        builder: (_) => _HorizonDialog(initial: horizon),
      );
      if (months != null) notifier.set(months);
    }

    return Semantics(
      label: l.forecastHorizon,
      container: true,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: SegmentedButton<int>(
              segments: [
                for (final m in _presets)
                  ButtonSegment(
                    value: m,
                    label: Text(l.forecastHorizonShort(m)),
                    tooltip: l.forecastHorizonLong(m),
                  ),
                ButtonSegment(
                  value: _custom,
                  label: Text(
                    custom
                        ? l.forecastHorizonShort(horizon)
                        : l.forecastHorizonCustom,
                  ),
                  tooltip: custom
                      ? l.forecastHorizonLong(horizon)
                      : l.forecastHorizonCustomTitle,
                ),
              ],
              selected: {if (custom) _custom else horizon},
              showSelectedIcon: false,
              // Narrow padding so all five fit on a typical phone.
              style: const ButtonStyle(
                padding: WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: Space.xs),
                ),
              ),
              // Tapping the selected segment empties the selection; for the
              // custom segment that reopens the dialog.
              emptySelectionAllowed: true,
              onSelectionChanged: (s) {
                final v = s.isEmpty ? (custom ? _custom : null) : s.first;
                if (v == _custom) {
                  unawaited(pickCustom());
                } else if (v != null) {
                  notifier.set(v);
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Picks a custom horizon with a slider and a number field kept in sync.
class _HorizonDialog extends StatefulWidget {
  const _HorizonDialog({required this.initial});

  final int initial;

  @override
  State<_HorizonDialog> createState() => _HorizonDialogState();
}

class _HorizonDialogState extends State<_HorizonDialog> {
  static const _max = ForecastSettings.maxHorizonMonths;

  late int? _months = widget.initial.clamp(1, _max);
  late final _field = TextEditingController(text: '$_months');

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _typed(String text) {
    final v = int.tryParse(text);
    setState(() => _months = v != null && v >= 1 && v <= _max ? v : null);
  }

  void _slid(double x) {
    final v = x.round();
    _field.value = TextEditingValue(
      text: '$v',
      selection: TextSelection.collapsed(offset: '$v'.length),
    );
    setState(() => _months = v);
  }

  void _submit() {
    if (_months != null) Navigator.of(context).pop(_months);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final months = _months;
    return AlertDialog(
      title: Text(l.forecastHorizonCustomTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _field,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: l.forecastHorizonMonthsLabel,
              errorText: months == null
                  ? l.forecastHorizonRangeError(1, _max)
                  : null,
            ),
            onChanged: _typed,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: Space.sm),
          Slider(
            value: (months ?? widget.initial).clamp(1, _max).toDouble(),
            min: 1,
            max: _max.toDouble(),
            divisions: _max - 1,
            label: l.forecastHorizonLong(months ?? widget.initial),
            semanticFormatterCallback: (x) => l.forecastHorizonLong(x.round()),
            onChanged: _slid,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          onPressed: months == null ? null : _submit,
          child: Text(l.commonDone),
        ),
      ],
    );
  }
}

class _LowestHeader extends ConsumerWidget {
  const _LowestHeader({required this.result, required this.accountId});

  final CashflowResult result;
  final String? accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final locale = ref.watch(formatLocaleProvider);
    final money = sentenceMoney(ref);
    final low = result.lowest(accountId)!;
    final threshold = result.threshold(accountId);
    final limit = threshold ?? 0;
    final days = result.daysBelow(accountId, limit);
    final warn = days > 0;
    final status = warn
        ? l.forecastDaysBelow(days, money(limit))
        : (threshold != null ? l.forecastStaysAbove(money(threshold)) : null);
    final warnColor = context.finance.warning;
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.forecastLowestPoint,
                  style: context.text.labelMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                AmountText(
                  low.amountMinor,
                  colored: false,
                  style: context.text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: low.amountMinor < 0 ? context.colors.error : null,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                DateFormat.yMMMEd(locale).format(low.date),
                style: context.text.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (status != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (warn) ...[
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 14,
                        color: warnColor,
                      ),
                      const SizedBox(width: Space.xxs),
                    ],
                    Text(
                      status,
                      style: context.text.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: warn
                            ? warnColor
                            : context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Sentence under the chart: "Lowest €211.19 on 28 Jan, below your €500
/// threshold".
String lowestSentence(
  BuildContext context,
  WidgetRef ref,
  LowPoint low,
  int? threshold,
) {
  final l = context.l10n;
  final money = sentenceMoney(ref);
  final date = DateFormat.MMMd(ref.watch(formatLocaleProvider))
      .format(low.date);
  if (low.amountMinor < 0) {
    return l.forecastLowestBelowZero(money(low.amountMinor), date);
  }
  if (threshold != null && low.amountMinor < threshold) {
    return l.forecastLowestBelowThreshold(
      money(low.amountMinor),
      date,
      money(threshold),
    );
  }
  return l.forecastLowestOk(money(low.amountMinor), date);
}

class _ChartSection extends ConsumerWidget {
  const _ChartSection({
    required this.batch,
    required this.accountId,
    required this.accounts,
    required this.compared,
    required this.height,
  });

  final CashflowBatch batch;
  final String? accountId;
  final List<Account> accounts;
  final List<ScenarioDef> compared;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final dates = ref.watch(dateFormatsProvider);
    final money = sentenceMoney(ref);
    final r = batch.baseline;
    final low = r.lowest(accountId)!;
    final threshold = r.threshold(accountId);
    final warn =
        low.amountMinor < 0 ||
        (threshold != null && low.amountMinor < threshold);
    final accountName = accountId == null
        ? l.forecastTotal
        : accounts.firstWhere((a) => a.id == accountId).name;
    final combined = combinedResult(ref, batch.scenarios);
    final lines = <ChartLine>[
      ChartLine(
        values: r.series(accountId),
        color: context.colors.primary,
        label: l.forecastLegendBaseline,
      ),
      for (final (i, s) in compared.indexed)
        if (batch.scenarios[s.id] != null)
          ChartLine(
            values: batch.scenarios[s.id]!.series(accountId),
            color: scenarioColor(context, i, argb: s.color),
            label: s.name,
            dashed: true,
          ),
      if (combined != null)
        ChartLine(
          values: combined.series(accountId),
          color: combinedScenarioColor(context),
          label: l.forecastLegendCombined,
          dotted: true,
        ),
    ];
    final semantic = StringBuffer(
      l.forecastChartSummary(
        accountName,
        dates.medium(r.start),
        dates.medium(r.end),
        money(low.amountMinor),
        dates.medium(low.date),
      ),
    );
    if (threshold != null) {
      semantic.write(' ${l.forecastChartThreshold(money(threshold))}');
    }
    for (final s in compared) {
      final sr = batch.scenarios[s.id];
      final sl = sr?.lowest(accountId);
      if (sl == null) continue;
      semantic.write(
        ' ${l.forecastChartScenario(s.name, money(sl.amountMinor), dates.medium(sl.date))}',
      );
    }
    final cl = combined?.lowest(accountId);
    if (cl != null) {
      semantic.write(
        ' ${l.forecastChartScenario(l.forecastLegendCombined, money(cl.amountMinor), dates.medium(cl.date))}',
      );
    }
    final method = ref.watch(
      settingsProvider.select((s) => s.get(ForecastSettings.variableMethod)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BalanceLineChart(
          lines: lines,
          dateOf: r.dateAt,
          semanticLabel: semantic.toString(),
          thresholdMinor: threshold,
          markIndex: dayIndex(r.start, low.date).clamp(0, r.dayCount - 1),
          markWarning: warn,
          height: height,
        ),
        const SizedBox(height: Space.xs),
        ExcludeSemantics(
          child: Wrap(
            spacing: Space.md,
            runSpacing: Space.xxs,
            children: [
              for (final line in lines)
                LegendEntry(
                  color: line.color,
                  label: line.label,
                  dashed: line.dashed,
                  dotted: line.dotted,
                ),
              if (threshold != null)
                LegendEntry(
                  color: context.finance.warning,
                  label: l.forecastLegendThreshold,
                  dashed: true,
                ),
            ],
          ),
        ),
        const SizedBox(height: Space.xs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              warn ? Icons.warning_amber_rounded : Icons.check_circle_outline,
              size: 18,
              color: warn ? context.finance.warning : context.colors.primary,
            ),
            const SizedBox(width: Space.xs),
            Expanded(
              child: Text(
                lowestSentence(context, ref, low, threshold),
                style: context.text.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: warn
                      ? context.finance.warning
                      : context.colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.xxs),
        Text(
          l.forecastVariableNote(variableMethodLabel(l, method)),
          style: context.text.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ScenarioToggles extends ConsumerWidget {
  const _ScenarioToggles({required this.batch, required this.accountId});

  final CashflowBatch batch;
  final String? accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final scenarios = ref.watch(scenariosProvider).value ?? const [];
    final compared = ref.watch(comparedScenariosProvider);
    final describer = adjustmentDescriber(context, ref);
    final money = sentenceMoney(ref);
    final combined = combinedResult(ref, batch.scenarios);
    return FoldCard(
      title: l.forecastScenarios,
      fold: forecastFold('scenarios'),
      actionLabel: l.forecastEditScenarios,
      onAction: () => context.push('/forecast/scenarios'),
      child: scenarios.isEmpty
          ? Padding(
              padding: const EdgeInsets.only(bottom: Space.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.forecastNoScenarios,
                    style: context.text.bodyMedium?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Space.xs),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/forecast/scenarios/new'),
                    icon: const Icon(Icons.add),
                    label: Text(l.forecastAddScenario),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                for (final s in scenarios)
                  _ScenarioRow(
                    scenario: s,
                    slot: compared.indexWhere((c) => c.id == s.id),
                    subtitle: describer.summary(s),
                    comparison: batch.scenarios[s.id] == null
                        ? null
                        : compareScenario(
                            batch.baseline,
                            batch.scenarios[s.id]!,
                            accountId: accountId,
                          ),
                    money: money,
                  ),
                if (compared.length >= 2)
                  _CombinedRow(
                    comparison: combined == null
                        ? null
                        : compareScenario(
                            batch.baseline,
                            combined,
                            accountId: accountId,
                          ),
                  ),
              ],
            ),
    );
  }
}

class _ScenarioRow extends ConsumerWidget {
  const _ScenarioRow({
    required this.scenario,
    required this.slot,
    required this.subtitle,
    required this.comparison,
    required this.money,
  });

  final ScenarioDef scenario;

  /// Comparison slot (0–4) or -1 when not compared.
  final int slot;
  final String subtitle;
  final ScenarioComparison? comparison;
  final String Function(int) money;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final color = slot >= 0
        ? scenarioColor(context, slot, argb: scenario.color)
        : context.colors.outlineVariant;
    return MergeSemantics(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        minTileHeight: 56,
        leading: _Dot(color),
        title: Text(scenario.name, style: context.text.titleSmall),
        subtitle: _ScenarioSubtitle(text: subtitle, comparison: comparison),
        trailing: Switch(
          value: scenario.enabled,
          onChanged: (on) async {
            final messenger = ScaffoldMessenger.of(context);
            final ok = await ref
                .read(scenarioRepositoryProvider)
                .setEnabled(scenario.id, enabled: on);
            if (!ok) {
              messenger.showSnackBar(
                SnackBar(content: Text(l.scenariosMaxCompared)),
              );
            }
          },
        ),
      ),
    );
  }
}

/// Toggles the line with all compared scenarios applied together.
class _CombinedRow extends ConsumerWidget {
  const _CombinedRow({required this.comparison});

  /// null while the combined line is off (or being computed).
  final ScenarioComparison? comparison;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final on = ref.watch(
      settingsProvider.select((s) => s.get(ForecastSettings.combineScenarios)),
    );
    return MergeSemantics(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        minTileHeight: 56,
        leading: _Dot(
          on ? combinedScenarioColor(context) : context.colors.outlineVariant,
        ),
        title: Text(l.forecastLegendCombined, style: context.text.titleSmall),
        subtitle: _ScenarioSubtitle(
          text: l.forecastCombinedDesc,
          comparison: on ? comparison : null,
        ),
        trailing: Switch(
          value: on,
          onChanged: (v) => ref
              .read(settingsProvider.notifier)
              .set(ForecastSettings.combineScenarios, v),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 12,
    height: 12,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// A scenario's description plus its effect on the lowest point and the
/// end balance.
class _ScenarioSubtitle extends ConsumerWidget {
  const _ScenarioSubtitle({required this.text, required this.comparison});

  final String text;
  final ScenarioComparison? comparison;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = comparison;
    String? effect;
    Color? effectColor;
    if (c != null) {
      if (c.resolvesWarning) {
        effect = l.scenariosResolvesWarning;
        effectColor = context.colors.primary;
      } else if (c.causesWarning) {
        effect = l.scenariosCausesWarning;
        effectColor = context.finance.warning;
      } else {
        final fmt = ref.watch(moneyFormatterProvider);
        final hidden = ref.watch(privacyModeProvider);
        String d(int v) => hidden ? '•••' : fmt.minor(v, explicitPlus: true);
        effect =
            '${l.scenariosLowDelta(d(c.lowDeltaMinor))} · ${l.scenariosEndDelta(d(c.endDeltaMinor))}';
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
        if (effect != null)
          Text(
            effect,
            style: context.text.labelMedium?.copyWith(
              color: effectColor ?? context.colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

class _BalancesTable extends ConsumerWidget {
  const _BalancesTable({
    required this.batch,
    required this.accountId,
    required this.compared,
  });

  final CashflowBatch batch;
  final String? accountId;
  final List<ScenarioDef> compared;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final locale = ref.watch(formatLocaleProvider);
    final r = batch.baseline;
    final samePeriods =
        r.periods.length == r.months.length &&
        [
          for (var i = 0; i < r.periods.length; i++)
            r.periods[i].range == r.months[i].range,
        ].every((x) => x);
    final showPeriods = ref.watch(forecastShowPeriodsProvider) && !samePeriods;
    final rows = showPeriods ? r.periods : r.months;
    final combined = combinedResult(ref, batch.scenarios);
    final columns = <(String, CashflowResult?)>[
      for (final s in compared) (s.name, batch.scenarios[s.id]),
      if (combined != null) (l.forecastLegendCombined, combined),
    ];
    final head = context.text.labelMedium?.copyWith(
      color: context.colors.onSurfaceVariant,
      fontWeight: FontWeight.w700,
    );
    final cell = context.text.bodyMedium;

    String label(PeriodSummary p) {
      final base = showPeriods
          ? '${DateFormat.MMMd(locale).format(p.range.start)} – ${DateFormat.MMMd(locale).format(p.range.last)}'
          : (p.range.start.year == r.start.year
                ? DateFormat.MMMM(locale).format(p.range.start)
                : DateFormat.yMMM(locale).format(p.range.start));
      if (p.range.last.isAfter(r.end)) {
        return '$base (${l.forecastPartial(DateFormat.MMMd(locale).format(r.end))})';
      }
      return base;
    }

    int? scenarioEnd(CashflowResult? sr, int i) {
      if (sr == null) return null;
      final list = showPeriods ? sr.periods : sr.months;
      return i < list.length ? list[i].endOf(accountId) : null;
    }

    Widget amount(int v, {bool warn = false}) => Align(
      alignment: Alignment.centerRight,
      child: AmountText(
        v,
        colored: false,
        style: cell?.copyWith(
          color: v < 0
              ? context.colors.error
              : warn
              ? context.finance.warning
              : null,
          fontWeight: warn ? FontWeight.w700 : null,
        ),
      ),
    );

    final threshold = r.threshold(accountId);
    return FoldCard(
      title: l.forecastBalances,
      fold: forecastFold('balances'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!samePeriods)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.xs),
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, label: Text(l.forecastMonths)),
                  ButtonSegment(
                    value: true,
                    label: Text(l.forecastBudgetPeriods),
                  ),
                ],
                selected: {showPeriods},
                onSelectionChanged: (v) =>
                    ref.read(forecastShowPeriodsProvider.notifier).periods =
                        v.first,
              ),
            ),
          // Columns take the width of their content and share what is left;
          // the table scrolls sideways when they do not fit.
          _HorizontalScroll(
            child: Table(
              columnWidths: {
                0: const IntrinsicColumnWidth(flex: 1.3),
                for (var i = 1; i < 3 + columns.length; i++)
                  i: const IntrinsicColumnWidth(flex: 1),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  children: [
                    _Cell(
                      Text(
                        showPeriods ? l.forecastColPeriod : l.forecastColMonth,
                        style: head,
                      ),
                      start: true,
                    ),
                    _Cell(
                      Text(
                        l.forecastColLowest,
                        style: head,
                        textAlign: TextAlign.end,
                      ),
                    ),
                    _Cell(
                      Text(
                        l.forecastColEnd,
                        style: head,
                        textAlign: TextAlign.end,
                      ),
                    ),
                    for (final (name, _) in columns)
                      _Cell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 160),
                          child: Text(
                            l.forecastColWith(name),
                            style: head,
                            textAlign: TextAlign.end,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                  ],
                ),
                for (final (i, p) in rows.indexed)
                  TableRow(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: context.colors.surfaceContainerHigh,
                        ),
                      ),
                    ),
                    children: [
                      _Cell(Text(label(p), style: cell), start: true),
                      _Cell(
                        amount(
                          p.lowOf(accountId)!.amountMinor,
                          warn:
                              threshold != null &&
                              p.lowOf(accountId)!.amountMinor < threshold,
                        ),
                      ),
                      _Cell(amount(p.endOf(accountId))),
                      for (final (_, sr) in columns)
                        _Cell(
                          scenarioEnd(sr, i) == null ||
                                  scenarioEnd(sr, i) == p.endOf(accountId)
                              ? Text('—', style: cell, textAlign: TextAlign.end)
                              : amount(scenarioEnd(sr, i)!),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fills the available width and scrolls [child] sideways when it is
/// wider, with a scrollbar that mice can drag.
class _HorizontalScroll extends StatefulWidget {
  const _HorizontalScroll({required this.child});

  final Widget child;

  @override
  State<_HorizontalScroll> createState() => _HorizontalScrollState();
}

class _HorizontalScrollState extends State<_HorizontalScroll> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    // The thumb stays visible (only when there is something to scroll) so
    // hidden columns are not missed.
    builder: (context, constraints) => Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        // Room for the scrollbar below the last row.
        padding: const EdgeInsets.only(bottom: Space.sm),
        child: ConstrainedBox(
          // A hair narrower: rounding in a flexed table would otherwise
          // leave a scroll extent of a few femtometres.
          constraints: BoxConstraints(
            minWidth: constraints.maxWidth - 2 * precisionErrorTolerance,
          ),
          child: widget.child,
        ),
      ),
    ),
  );
}

class _Cell extends StatelessWidget {
  const _Cell(this.child, {this.start = false});

  final Widget child;

  /// Left-aligned (labels); numbers align to the end.
  final bool start;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: Space.minTouch),
    child: Padding(
      // Numbers keep a gap to the column before them.
      padding: EdgeInsetsDirectional.only(
        start: start ? 0 : Space.md,
        top: 6,
        bottom: 6,
      ),
      child: Align(
        alignment: start ? Alignment.centerLeft : Alignment.centerRight,
        child: child,
      ),
    ),
  );
}

class _Warnings extends ConsumerWidget {
  const _Warnings({required this.result, required this.accounts});

  final CashflowResult result;
  final List<Account> accounts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final money = sentenceMoney(ref);
    final locale = ref.watch(formatLocaleProvider);
    final byId = {for (final a in accounts) a.id: a};
    final warnings = [
      for (final w in result.warnings)
        if (w.accountId != null && byId.containsKey(w.accountId)) w,
    ];
    return FoldCard(
      title: l.forecastWarnings,
      // Folded, the count still tells that something needs a look.
      subtitle: warnings.isEmpty ? null : '${warnings.length}',
      fold: forecastFold('warnings'),
      child: warnings.isEmpty
          ? Padding(
              padding: const EdgeInsets.only(bottom: Space.xs),
              child: Text(
                l.forecastNoWarnings,
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            )
          : Column(
              children: [
                for (final w in warnings)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      w.kind == WarningKind.belowZero
                          ? Icons.error_outline
                          : Icons.warning_amber_rounded,
                      color: w.kind == WarningKind.belowZero
                          ? context.colors.error
                          : context.finance.warning,
                    ),
                    title: Text(
                      w.kind == WarningKind.belowZero
                          ? l.forecastWarnBelowZero(
                              byId[w.accountId]!.name,
                              DateFormat.MMMd(locale).format(w.firstDate),
                            )
                          : l.forecastWarnBelowThreshold(
                              byId[w.accountId]!.name,
                              money(w.thresholdMinor ?? 0),
                              DateFormat.MMMd(locale).format(w.firstDate),
                            ),
                    ),
                    subtitle: Text(
                      lowestSentence(context, ref, w.lowest, w.thresholdMinor),
                    ),
                    onTap: () =>
                        ref.read(forecastAccountProvider.notifier).accountId =
                            w.accountId,
                  ),
              ],
            ),
    );
  }
}

class _BigEvents extends ConsumerStatefulWidget {
  const _BigEvents({required this.result, required this.accountId});

  final CashflowResult result;
  final String? accountId;

  @override
  ConsumerState<_BigEvents> createState() => _BigEventsState();
}

class _BigEventsState extends ConsumerState<_BigEvents> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final dates = ref.watch(dateFormatsProvider);
    final accountMap = ref.watch(accountMapProvider);
    final id = widget.accountId;
    final events = <ForecastEvent>[];
    for (final e in widget.result.bigEvents) {
      if (id == null) {
        // Transfers between two forecast accounts do not move the total.
        final internal =
            e.isTransfer &&
            widget.result.accountIds.contains(e.counterAccountId);
        if (!internal) events.add(e);
      } else if (e.accountId == id) {
        events.add(e);
      } else if (e.counterAccountId == id) {
        events.add(
          ForecastEvent(
            date: e.date,
            accountId: id,
            amountMinor: -e.amountMinor,
            label: e.label,
            kind: e.kind,
            counterAccountId: e.accountId,
            refId: e.refId,
          ),
        );
      }
    }
    final shown = _all ? events : events.take(6).toList();
    return FoldCard(
      title: l.forecastUpcoming,
      fold: forecastFold('upcoming'),
      actionLabel: events.length > 6
          ? (_all ? l.forecastShowLess : l.forecastShowAll)
          : null,
      onAction: () => setState(() => _all = !_all),
      actionWhenFolded: false,
      child: events.isEmpty
          ? Padding(
              padding: const EdgeInsets.only(bottom: Space.xs),
              child: Text(
                l.forecastNoEvents,
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            )
          : Column(
              children: [
                for (final e in shown)
                  MergeSemantics(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      minTileHeight: 52,
                      title: Text(
                        e.label.isEmpty ? eventKindLabel(l, e.kind) : e.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        [
                          dates.dayHeader(e.date),
                          if (e.isTransfer && e.amountMinor < 0)
                            l.forecastTransferTo(
                              _accountName(accountMap, e.counterAccountId),
                            )
                          else if (e.isTransfer)
                            l.forecastTransferFrom(
                              _accountName(accountMap, e.counterAccountId),
                            )
                          else
                            eventKindLabel(l, e.kind),
                          if (id == null) _accountName(accountMap, e.accountId),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: AmountText(
                        e.amountMinor,
                        type: e.isTransfer ? TxnType.transfer : null,
                        style: context.text.titleSmall,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  String _accountName(Map<String, Account> map, String? id) {
    if (id == null) return '';
    return map[id]?.name ?? context.l10n.forecastEventGoal;
  }
}
