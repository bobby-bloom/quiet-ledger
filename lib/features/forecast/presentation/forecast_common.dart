import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/amount_text.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/ledger/lookups.dart';
import 'package:personal_finance/features/forecast/presentation/forecast_providers.dart';
import 'package:personal_finance/features/scenarios/data/scenario_repository.dart';
import 'package:personal_finance/features/scenarios/domain/scenario.dart';
import 'package:personal_finance/features/scenarios/presentation/scenario_labels.dart';

/// Formats money for sentences; masked in privacy mode.
String Function(int minor) sentenceMoney(WidgetRef ref) {
  final fmt = ref.watch(moneyFormatterProvider);
  final hidden = ref.watch(privacyModeProvider);
  return (minor) => hidden ? '•••' : fmt.minor(minor);
}

/// The combined-scenarios run of a batch's [scenarios], when it is shown.
T? combinedResult<T>(WidgetRef ref, Map<String, T> scenarios) =>
    ref.watch(showCombinedScenariosProvider)
    ? scenarios[combinedScenarioId]
    : null;

/// Shown instead of a feature screen when its module is switched off.
class ModuleOffView extends StatelessWidget {
  const ModuleOffView({required this.title, required this.message, super.key});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: EmptyState(
        icon: Icons.toggle_off_outlined,
        message: message,
        actionLabel: context.l10n.forecastOpenSettings,
        onAction: () => context.push('/more/settings'),
      ),
    );
  }
}

/// Centred spinner with a message while a forecast is first computed.
class ForecastLoading extends StatelessWidget {
  const ForecastLoading({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator.adaptive(),
          const SizedBox(height: Space.sm),
          Text(message),
        ],
      ),
    );
  }
}

/// Builds the describer for scenario summaries from the current lookups.
AdjustmentDescriber adjustmentDescriber(BuildContext context, WidgetRef ref) {
  final dates = ref.watch(dateFormatsProvider);
  return AdjustmentDescriber(
    l: context.l10n,
    money: ref.watch(moneyFormatterProvider),
    date: dates.medium,
    locale: ref.watch(formatLocaleProvider),
    accounts: ref.watch(accountMapProvider),
    categories: ref.watch(categoryMapProvider),
    rules: {
      for (final r
          in ref.watch(recurringRuleOptionsProvider).value ??
              const <RuleOption>[])
        r.id: r.name,
    },
  );
}
