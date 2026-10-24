import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/amount_text.dart';
import 'package:personal_finance/app/ui/breakpoints.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/forecast/presentation/forecast_common.dart';
import 'package:personal_finance/features/forecast/presentation/forecast_providers.dart';
import 'package:personal_finance/features/scenarios/data/scenario_repository.dart';
import 'package:personal_finance/features/scenarios/domain/apply_scenario.dart';
import 'package:personal_finance/features/scenarios/domain/scenario.dart';
import 'package:personal_finance/features/scenarios/presentation/adjustment_form.dart';
import 'package:personal_finance/features/scenarios/presentation/scenario_labels.dart';
import 'package:personal_finance/features/scenarios/presentation/scenario_providers.dart';

/// Creates (`/forecast/scenarios/new`) or edits
/// (`/forecast/scenarios/:id`) a scenario, with a live preview of its
/// effect on the forecast.
class ScenarioEditorScreen extends ConsumerStatefulWidget {
  const ScenarioEditorScreen({required this.scenarioId, super.key});

  /// `new` creates a scenario.
  final String scenarioId;

  bool get isNew => scenarioId == 'new';

  @override
  ConsumerState<ScenarioEditorScreen> createState() =>
      _ScenarioEditorScreenState();
}

class _ScenarioEditorScreenState extends ConsumerState<ScenarioEditorScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  bool _loaded = false;
  bool _missing = false;
  bool _saving = false;
  int? _color;
  bool _enabled = false;
  List<ScenarioAdjustment> _adjustments = [];

  @override
  void initState() {
    super.initState();
    if (widget.isNew) {
      _loaded = true;
    } else {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final s = await ref
        .read(scenarioRepositoryProvider)
        .byId(widget.scenarioId);
    if (!mounted) return;
    setState(() {
      _loaded = true;
      if (s == null) {
        _missing = true;
        return;
      }
      _name.text = s.name;
      _color = s.color;
      _enabled = s.enabled;
      _adjustments = [...s.adjustments];
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final l = context.l10n;
    final kind = await showModalBottomSheet<AdjustmentKind>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: Space.md),
        children: [
          for (final k in AdjustmentKind.values)
            ListTile(
              leading: Icon(kindIcon(k)),
              title: Text(kindLabel(l, k)),
              onTap: () => Navigator.pop(ctx, k),
            ),
        ],
      ),
    );
    if (kind == null || !mounted) return;
    final a = await showAdjustmentForm(context, kind: kind);
    if (a == null) return;
    setState(() => _adjustments = [..._adjustments, a]);
  }

  Future<void> _edit(int index) async {
    final current = _adjustments[index];
    final kind = kindOf(current);
    if (kind == null) return;
    final a = await showAdjustmentForm(context, kind: kind, initial: current);
    if (a == null) return;
    setState(() => _adjustments = [..._adjustments]..[index] = a);
  }

  void _remove(int index) {
    setState(() => _adjustments = [..._adjustments]..removeAt(index));
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final l = context.l10n;
    final repo = ref.read(scenarioRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final draft = ScenarioDef(
        id: widget.scenarioId,
        name: _name.text.trim(),
        color: _color,
        enabled: _enabled,
        adjustments: _adjustments,
      );
      if (widget.isNew) {
        final id = await repo.create(draft.copyWith(enabled: false));
        if (_enabled) {
          final ok = await repo.setEnabled(id, enabled: true);
          if (!ok) {
            messenger.showSnackBar(
              SnackBar(content: Text(l.scenariosMaxCompared)),
            );
          }
        }
      } else {
        await repo.save(draft.copyWith(enabled: false));
        final ok = await repo.setEnabled(draft.id, enabled: _enabled);
        if (!ok) {
          messenger.showSnackBar(
            SnackBar(content: Text(l.scenariosMaxCompared)),
          );
        }
      }
      messenger.showSnackBar(SnackBar(content: Text(l.scenariosSaved)));
      if (mounted) await Navigator.of(context).maybePop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final l = context.l10n;
    final ok = await confirmDialog(
      context,
      title: l.scenariosDeleteTitle,
      message: l.scenariosDeleteMessage(_name.text),
    );
    if (!ok || !mounted) return;
    await ref.read(scenarioRepositoryProvider).delete(widget.scenarioId);
    if (mounted) await Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final modules = ref.watch(
      settingsProvider.select(
        (s) => (
          s.moduleEnabled(AppModule.forecast),
          s.moduleEnabled(AppModule.scenarios),
        ),
      ),
    );
    if (!modules.$1 || !modules.$2) {
      return ModuleOffView(
        title: l.scenariosTitle,
        message: modules.$1 ? l.scenariosModuleOff : l.forecastModuleOff,
      );
    }
    if (!_loaded) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator.adaptive()),
      );
    }
    if (_missing) {
      return Scaffold(
        appBar: AppBar(title: Text(l.scenariosEdit)),
        body: EmptyState(icon: Icons.search_off, message: l.scenariosNotFound),
      );
    }
    final size = WindowSize.of(context);
    final gutter = size.isCompact ? Space.phoneGutter : Space.desktopGutter;
    final describer = adjustmentDescriber(context, ref);

    final details = <Widget>[
      TextFormField(
        controller: _name,
        autofocus: widget.isNew,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: l.scenariosName),
        validator: (v) =>
            (v ?? '').trim().isEmpty ? l.scenariosNameRequired : null,
      ),
      const SizedBox(height: Space.md),
      Text(l.scenariosColor, style: context.text.labelLarge),
      const SizedBox(height: Space.xs),
      _ColorChoice(value: _color, onChanged: (c) => setState(() => _color = c)),
      const SizedBox(height: Space.sm),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(l.scenariosCompare),
        subtitle: Text(l.scenariosCompareDesc),
        value: _enabled,
        onChanged: (v) => setState(() => _enabled = v),
      ),
    ];
    final changes = SectionCard(
      title: l.scenariosChanges,
      actionLabel: l.scenariosAddChange,
      onAction: _add,
      child: _adjustments.isEmpty
          ? Padding(
              padding: const EdgeInsets.only(bottom: Space.xs),
              child: Text(
                l.scenariosNoChanges,
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            )
          : Column(
              children: [
                for (final (i, a) in _adjustments.indexed)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: IconTile(icon: kindIcon(kindOf(a)), size: 36),
                    title: Text(describer.title(a)),
                    subtitle: Text(describer.subtitle(a)),
                    onTap: kindOf(a) == null ? null : () => _edit(i),
                    trailing: IconButton(
                      tooltip: l.commonDelete,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _remove(i),
                    ),
                  ),
              ],
            ),
    );
    final preview = _Preview(adjustments: _adjustments, name: _name.text);

    final body = size.isExpanded
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(gutter, Space.md, Space.sm, 32),
                  children: [
                    ...details,
                    const SizedBox(height: Space.md),
                    changes,
                  ],
                ),
              ),
              SizedBox(
                width: 380,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(Space.sm, Space.md, gutter, 32),
                  children: [preview],
                ),
              ),
            ],
          )
        : ListView(
            padding: EdgeInsets.fromLTRB(gutter, Space.md, gutter, 96),
            children: [
              ...details,
              const SizedBox(height: Space.md),
              changes,
              const SizedBox(height: Space.md),
              preview,
            ],
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? l.scenariosNew : l.scenariosEdit),
        actions: [
          if (!widget.isNew)
            IconButton(
              tooltip: l.commonDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(l.commonSave),
          ),
        ],
      ),
      body: Form(key: _form, child: body),
    );
  }
}

/// Automatic (comparison slot colour) or one of the chart palette colours.
class _ColorChoice extends StatelessWidget {
  const _ColorChoice({required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final palette = context.finance.chart;
    return Wrap(
      spacing: Space.xs,
      runSpacing: Space.xs,
      children: [
        ChoiceChip(
          label: Text(l.scenariosColorAuto),
          selected: value == null,
          onSelected: (_) => onChanged(null),
        ),
        for (final (i, c) in palette.indexed)
          Semantics(
            label: l.scenariosColorOption(i + 1),
            selected: value == c.toARGB32(),
            button: true,
            child: InkResponse(
              onTap: () => onChanged(c.toARGB32()),
              radius: 24,
              child: SizedBox.square(
                dimension: Space.minTouch,
                child: Center(
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: value == c.toARGB32()
                          ? Border.all(
                              color: context.colors.onSurface,
                              width: 3,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Effect of the draft scenario on the forecast board's horizon.
class _Preview extends ConsumerWidget {
  const _Preview({required this.adjustments, required this.name});

  final List<ScenarioAdjustment> adjustments;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final horizon = ref.watch(forecastHorizonProvider);
    return SectionCard(
      title: l.forecastTitle,
      subtitle: l.forecastHorizonLong(horizon),
      child: adjustments.isEmpty
          ? Padding(
              padding: const EdgeInsets.only(bottom: Space.xs),
              child: Text(
                l.scenariosNoChanges,
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            )
          : Builder(
              builder: (context) {
                final b = ref
                    .watch(scenarioPreviewProvider(AdjustmentsKey(adjustments)))
                    .value;
                if (b == null) {
                  return const Padding(
                    padding: EdgeInsets.all(Space.md),
                    child: Center(child: CircularProgressIndicator.adaptive()),
                  );
                }
                final c = compareScenario(b.baseline, b.scenarios['draft']!);
                final fmt = ref.watch(moneyFormatterProvider);
                final hidden = ref.watch(privacyModeProvider);
                final dates = ref.watch(dateFormatsProvider);
                String d(int v) =>
                    hidden ? '•••' : fmt.minor(v, explicitPlus: true);
                return Semantics(
                  liveRegion: true,
                  container: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _row(
                        context,
                        l.forecastLegendBaseline,
                        c.baselineLow.amountMinor,
                        dates.medium(c.baselineLow.date),
                      ),
                      _row(
                        context,
                        name.trim().isEmpty ? l.forecastEventOneOff : name,
                        c.scenarioLow.amountMinor,
                        dates.medium(c.scenarioLow.date),
                      ),
                      const SizedBox(height: Space.xs),
                      Text(
                        '${l.scenariosLowDelta(d(c.lowDeltaMinor))} · '
                        '${l.scenariosEndDelta(d(c.endDeltaMinor))}',
                        style: context.text.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (c.resolvesWarning || c.causesWarning)
                        Text(
                          c.resolvesWarning
                              ? l.scenariosResolvesWarning
                              : l.scenariosCausesWarning,
                          style: context.text.labelMedium?.copyWith(
                            color: c.causesWarning
                                ? context.finance.warning
                                : context.colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _row(BuildContext context, String label, int minor, String date) {
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.xxs),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${context.l10n.forecastLowestPoint} · $label',
                style: context.text.bodyMedium,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AmountText(
                  minor,
                  colored: false,
                  style: context.text.titleSmall,
                ),
                Text(
                  date,
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
