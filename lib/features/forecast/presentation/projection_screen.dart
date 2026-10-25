import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/amount_text.dart';
import 'package:personal_finance/app/ui/breakpoints.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/ledger/lookups.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/setting_def.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/forecast/domain/forecast_pipeline.dart';
import 'package:personal_finance/features/forecast/domain/projection.dart';
import 'package:personal_finance/features/forecast/presentation/forecast_chart.dart';
import 'package:personal_finance/features/forecast/presentation/forecast_common.dart';
import 'package:personal_finance/features/forecast/presentation/forecast_format.dart';
import 'package:personal_finance/features/forecast/presentation/forecast_providers.dart';

/// Long-term net-worth projection (`/forecast/projection`) with milestones
/// and assumption controls.
class ProjectionScreen extends ConsumerWidget {
  const ProjectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final enabled = ref.watch(
      settingsProvider.select((s) => s.moduleEnabled(AppModule.forecast)),
    );
    if (!enabled) {
      return ModuleOffView(
        title: l.forecastProjection,
        message: l.forecastModuleOff,
      );
    }
    final input = ref.watch(forecastInputProvider).value;
    if (input != null && !input.accounts.any((a) => a.inNetWorth)) {
      return Scaffold(
        appBar: AppBar(title: Text(l.forecastProjection)),
        body: EmptyState(
          icon: Icons.trending_up,
          message: l.forecastProjNoAccounts,
        ),
      );
    }
    final batch = ref.watch(projectionProvider);
    final real = ref.watch(
      settingsProvider.select((s) => s.get(ForecastSettings.realValues)),
    );
    final size = WindowSize.of(context);
    final gutter = size.isCompact ? Space.phoneGutter : Space.desktopGutter;
    final sideHidden = ref.watch(
      settingsProvider.select(
        (s) => s.get(ForecastSettings.projectionSidePanelHidden),
      ),
    );
    // A changed assumption recomputes in the background; the previous
    // result stays visible but dimmed until the new one arrives.
    final busy = batch.isLoading && batch.hasValue;
    Widget content(ProjectionBatch nominal) {
      final b = nominal.withReal(real);
      final main = <Widget>[
        _Stale(
          busy: busy,
          child: _Headline(projection: b.baseline),
        ),
        const SizedBox(height: Space.sm),
        _Stale(
          busy: busy,
          spinner: true,
          child: _ProjectionChart(
            batch: b,
            height: size.isExpanded ? 320 : 220,
          ),
        ),
        const SizedBox(height: Space.md),
        _Stale(
          busy: busy,
          child: _Milestones(projection: b.baseline),
        ),
      ];
      const side = <Widget>[_Assumptions()];
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
                  32,
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
                    32,
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

    return Scaffold(
      appBar: AppBar(
        title: Text(l.forecastProjection),
        actions: [
          if (size.isExpanded)
            SidePanelButton(
              setting: ForecastSettings.projectionSidePanelHidden,
            ),
        ],
      ),
      body: batch.hasValue
          ? Stack(
              children: [
                content(batch.value!),
                // The chart may be scrolled out of view on phones.
                if (busy)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
              ],
            )
          : AsyncView(
              value: batch,
              loading: ForecastLoading(message: l.forecastProjLoading),
              data: content,
            ),
    );
  }
}

/// Dims [child] while the projection recomputes, optionally with a spinner
/// on top.
class _Stale extends StatelessWidget {
  const _Stale({required this.busy, required this.child, this.spinner = false});

  final bool busy;
  final bool spinner;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dimmed = AnimatedOpacity(
      opacity: busy ? 0.35 : 1,
      duration: const Duration(milliseconds: 150),
      child: child,
    );
    if (!spinner) return dimmed;
    return Stack(
      children: [
        dimmed,
        if (busy)
          Positioned.fill(
            child: Center(
              child: Semantics(
                liveRegion: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator.adaptive(),
                    const SizedBox(height: Space.sm),
                    Text(
                      context.l10n.forecastProjRecalculating,
                      style: context.text.labelLarge,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Headline extends ConsumerWidget {
  const _Headline({required this.projection});

  final NetWorthProjection projection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final dates = ref.watch(dateFormatsProvider);
    final money = sentenceMoney(ref);
    final real = projection.real;
    final last = projection.last;
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.forecastProjNetWorthOn(dates.medium(last.date)),
                  style: context.text.labelMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
              StatusBadge(real ? l.forecastProjReal : l.forecastProjNominal),
            ],
          ),
          AmountText(
            last.value(real: real),
            colored: false,
            style: context.text.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          Text(
            l.forecastProjToday(
              money(projection.points.first.value(real: real)),
            ),
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectionChart extends ConsumerWidget {
  const _ProjectionChart({required this.batch, required this.height});

  final ProjectionBatch batch;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final dates = ref.watch(dateFormatsProvider);
    final money = sentenceMoney(ref);
    final compared = ref.watch(comparedScenariosProvider);
    final p = batch.baseline;
    final lines = <ChartLine>[
      ChartLine(
        values: p.values,
        color: context.colors.primary,
        label: l.forecastLegendBaseline,
      ),
      for (final (i, s) in compared.indexed)
        if (batch.scenarios[s.id] != null)
          ChartLine(
            values: batch.scenarios[s.id]!.values,
            color: scenarioColor(context, i, argb: s.color),
            label: s.name,
            dashed: true,
          ),
      if (combinedResult(ref, batch.scenarios) case final c?)
        ChartLine(
          values: c.values,
          color: combinedScenarioColor(context),
          label: l.forecastLegendCombined,
          dotted: true,
        ),
    ];
    final marks = <int>{
      for (final m in p.milestones)
        p.points.indexWhere((pt) => pt.date == m.date),
    }..remove(-1);
    final semantic =
        '${l.forecastProjChartSummary(dates.medium(p.points.first.date), dates.medium(p.last.date), money(p.values.first), money(p.values.last))} '
        '${l.forecastProjChartMilestones(p.milestones.length)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BalanceLineChart(
          lines: lines,
          dateOf: (i) => p.points[i].date,
          semanticLabel: semantic,
          monthly: true,
          height: height,
          verticalMarks: marks.toList(),
        ),
        if (lines.length > 1) ...[
          const SizedBox(height: Space.xs),
          ExcludeSemantics(
            child: Wrap(
              spacing: Space.md,
              children: [
                for (final line in lines)
                  LegendEntry(
                    color: line.color,
                    label: line.label,
                    dashed: line.dashed,
                    dotted: line.dotted,
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: Space.sm),
        Row(
          children: [
            Expanded(
              child: _Stat(
                label: l.forecastProjAssets,
                minor: p.last.assetsMinor,
              ),
            ),
            Expanded(
              child: _Stat(
                label: l.forecastProjDebts,
                minor: p.last.liabilitiesMinor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.minor});

  final String label;
  final int minor;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.text.labelMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          AmountText(minor, colored: false, style: context.text.titleMedium),
        ],
      ),
    );
  }
}

class _Milestones extends ConsumerWidget {
  const _Milestones({required this.projection});

  final NetWorthProjection projection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final dates = ref.watch(dateFormatsProvider);
    final money = sentenceMoney(ref);
    final accounts = ref.watch(accountMapProvider);
    String title(Milestone m) => switch (m.kind) {
      MilestoneKind.netWorth => l.forecastMilestoneNetWorth(
        money(m.amountMinor ?? 0),
      ),
      MilestoneKind.debtFree => l.forecastMilestoneDebtFree,
      MilestoneKind.liabilityPaidOff => l.forecastMilestonePaidOff(
        accounts[m.refId]?.name ?? m.label ?? '',
      ),
      MilestoneKind.goalReached => l.forecastMilestoneGoal(m.label ?? ''),
    };
    IconData icon(MilestoneKind k) => switch (k) {
      MilestoneKind.netWorth => Icons.flag_outlined,
      MilestoneKind.debtFree => Icons.celebration_outlined,
      MilestoneKind.liabilityPaidOff => Icons.check_circle_outline,
      MilestoneKind.goalReached => Icons.savings_outlined,
    };
    return SectionCard(
      title: l.forecastProjMilestones,
      child: projection.milestones.isEmpty
          ? Padding(
              padding: const EdgeInsets.only(bottom: Space.xs),
              child: Text(
                l.forecastProjNoMilestones,
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            )
          : Column(
              children: [
                for (final m in projection.milestones)
                  MergeSemantics(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: IconTile(icon: icon(m.kind), size: 36),
                      title: Text(title(m)),
                      trailing: Text(
                        dates.monthYear(m.date),
                        style: context.text.labelLarge?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _Assumptions extends ConsumerWidget {
  const _Assumptions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final locale = ref.watch(formatLocaleProvider);
    final source = ref.watch(projectionSourceProvider);
    final savings = ref.watch(projectionProvider).value?.baseline;
    final money = sentenceMoney(ref);
    final years = s.get(ForecastSettings.projectionYears);

    Future<void> set<T>(SettingDef<T> def, T value) => notifier.set(def, value);

    return SectionCard(
      title: l.forecastProjAssumptions,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SliderRow(
            label: l.forecastProjYears,
            value: years,
            min: 1,
            max: 40,
            step: 1,
            format: l.forecastProjYearsValue,
            onChanged: (v) => set(ForecastSettings.projectionYears, v),
          ),
          const SizedBox(height: Space.sm),
          Text(l.forecastProjSource, style: context.text.labelLarge),
          const SizedBox(height: Space.xs),
          SegmentedButton<SavingsSource>(
            segments: [
              ButtonSegment(
                value: SavingsSource.history,
                label: Text(l.forecastProjSourceHistory),
              ),
              ButtonSegment(
                value: SavingsSource.plan,
                label: Text(l.forecastProjSourcePlan),
              ),
            ],
            selected: {source},
            onSelectionChanged: (v) =>
                ref.read(projectionSourceProvider.notifier).source = v.first,
          ),
          if (savings != null && savings.source == source) ...[
            const SizedBox(height: Space.xxs),
            Text(
              source == SavingsSource.history
                  ? l.forecastProjSourceHistoryDesc(
                      money(savings.monthlySavingsMinor),
                    )
                  : l.forecastProjSourcePlanDesc(
                      money(savings.monthlySavingsMinor),
                    ),
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: Space.xs),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.setRealValues),
            subtitle: Text(l.forecastProjRealDesc),
            value: s.get(ForecastSettings.realValues),
            onChanged: (v) => set(ForecastSettings.realValues, v),
          ),
          if (ref.watch(comparedScenariosProvider).length >= 2)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.setCombineScenarios),
              subtitle: Text(l.setCombineScenariosDesc),
              value: s.get(ForecastSettings.combineScenarios),
              onChanged: (v) => set(ForecastSettings.combineScenarios, v),
            ),
          _SliderRow(
            label: l.setInflation,
            value: s.get(ForecastSettings.inflationBp),
            min: -500,
            max: 2000,
            step: 10,
            format: (v) => l.forecastProjPerYear(formatBp(v, locale)),
            onChanged: (v) => set(ForecastSettings.inflationBp, v),
          ),
          _SliderRow(
            label: l.setDefaultReturn,
            value: s.get(ForecastSettings.defaultReturnBp),
            min: -2000,
            max: 3000,
            step: 25,
            format: (v) => l.forecastProjPerYear(formatBp(v, locale)),
            onChanged: (v) => set(ForecastSettings.defaultReturnBp, v),
          ),
          Text(
            l.setDefaultReturnDesc,
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Labelled integer slider that commits its value when the drag ends.
class _SliderRow extends StatefulWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.format,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final String Function(int) format;
  final ValueChanged<int> onChanged;

  @override
  State<_SliderRow> createState() => _SliderRowState();
}

class _SliderRowState extends State<_SliderRow> {
  int? _dragging;

  @override
  Widget build(BuildContext context) {
    final v = (_dragging ?? widget.value).clamp(widget.min, widget.max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(widget.label, style: context.text.labelLarge)),
            Text(
              widget.format(v),
              style: context.text.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        Slider(
          value: v.toDouble(),
          min: widget.min.toDouble(),
          max: widget.max.toDouble(),
          divisions: (widget.max - widget.min) ~/ widget.step,
          label: widget.format(v),
          semanticFormatterCallback: (x) => widget.format(x.round()),
          onChanged: (x) => setState(() => _dragging = x.round()),
          onChangeEnd: (x) {
            setState(() => _dragging = null);
            if (x.round() != widget.value) widget.onChanged(x.round());
          },
        ),
      ],
    );
  }
}
