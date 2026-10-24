import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/breakpoints.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/forecast/presentation/forecast_common.dart';
import 'package:personal_finance/features/forecast/presentation/forecast_format.dart';
import 'package:personal_finance/features/scenarios/data/scenario_repository.dart';
import 'package:personal_finance/features/scenarios/domain/scenario.dart';

enum _Action { edit, duplicate, delete }

/// List of scenarios (`/forecast/scenarios`): compare toggle, duplicate,
/// delete, add.
class ScenariosScreen extends ConsumerWidget {
  const ScenariosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final scenarios = ref.watch(scenariosProvider);
    final compact = WindowSize.of(context).isCompact;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.scenariosTitle),
        actions: [
          if (!compact)
            Padding(
              padding: const EdgeInsets.only(right: Space.md),
              child: FilledButton.icon(
                onPressed: () => context.push('/forecast/scenarios/new'),
                icon: const Icon(Icons.add),
                label: Text(l.scenariosNew),
              ),
            ),
        ],
      ),
      floatingActionButton: compact
          ? FloatingActionButton.extended(
              heroTag: 'scenarios-add',
              onPressed: () => context.push('/forecast/scenarios/new'),
              icon: const Icon(Icons.add),
              label: Text(l.scenariosNew),
            )
          : null,
      body: AsyncView(
        value: scenarios,
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.alt_route,
              message: l.scenariosEmpty,
              actionLabel: l.scenariosNew,
              onAction: () => context.push('/forecast/scenarios/new'),
            );
          }
          final compared = comparedScenarios(list);
          final describer = adjustmentDescriber(context, ref);
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Space.phoneGutter,
                  Space.xs,
                  Space.phoneGutter,
                  96,
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.sm),
                    child: Text(
                      l.scenariosCompareDesc,
                      style: context.text.bodyMedium?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (final (i, s) in list.indexed) ...[
                          if (i > 0) const Divider(height: 1),
                          _ScenarioTile(
                            scenario: s,
                            slot: compared.indexWhere((c) => c.id == s.id),
                            subtitle: describer.summary(s),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ScenarioTile extends ConsumerWidget {
  const _ScenarioTile({
    required this.scenario,
    required this.slot,
    required this.subtitle,
  });

  final ScenarioDef scenario;
  final int slot;
  final String subtitle;

  Future<void> _act(BuildContext context, WidgetRef ref, _Action a) async {
    final l = context.l10n;
    final repo = ref.read(scenarioRepositoryProvider);
    switch (a) {
      case _Action.edit:
        await context.push('/forecast/scenarios/${scenario.id}');
      case _Action.duplicate:
        final id = await repo.duplicate(
          scenario.id,
          name: l.scenariosCopyName(scenario.name),
        );
        if (id != null && context.mounted) {
          await context.push('/forecast/scenarios/$id');
        }
      case _Action.delete:
        final ok = await confirmDialog(
          context,
          title: l.scenariosDeleteTitle,
          message: l.scenariosDeleteMessage(scenario.name),
        );
        if (ok) await repo.delete(scenario.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final color = slot >= 0
        ? scenarioColor(context, slot, argb: scenario.color)
        : (scenario.color != null
              ? Color(scenario.color!)
              : context.colors.outlineVariant);
    return ListTile(
      minTileHeight: 64,
      onTap: () => _act(context, ref, _Action.edit),
      leading: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      title: Text(scenario.name, style: context.text.titleSmall),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: l.scenariosCompare,
            child: Switch(
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
          PopupMenuButton<_Action>(
            tooltip: MaterialLocalizations.of(context).showMenuTooltip,
            onSelected: (a) => _act(context, ref, a),
            itemBuilder: (_) => [
              PopupMenuItem(value: _Action.edit, child: Text(l.commonEdit)),
              PopupMenuItem(
                value: _Action.duplicate,
                child: Text(l.scenariosDuplicate),
              ),
              PopupMenuItem(
                value: _Action.delete,
                child: Text(
                  l.commonDelete,
                  style: TextStyle(color: context.colors.error),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
