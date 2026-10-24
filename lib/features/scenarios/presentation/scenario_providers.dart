import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/features/forecast/domain/forecast_pipeline.dart';
import 'package:personal_finance/features/forecast/presentation/forecast_providers.dart';
import 'package:personal_finance/features/scenarios/domain/scenario.dart';

/// A list of adjustments usable as a provider family key.
@immutable
class AdjustmentsKey {
  const AdjustmentsKey(this.items);

  final List<ScenarioAdjustment> items;

  @override
  bool operator ==(Object other) =>
      other is AdjustmentsKey &&
      const ListEquality<ScenarioAdjustment>().equals(other.items, items);

  @override
  int get hashCode => Object.hashAll(items);
}

/// Baseline and a draft scenario (id `draft`) over the board's horizon,
/// for the editor's live preview.
final scenarioPreviewProvider = FutureProvider.autoDispose
    .family<CashflowBatch, AdjustmentsKey>((ref, key) async {
      final input = await ref.watch(forecastInputProvider.future);
      return await ref
          .watch(forecastRunnerProvider)
          .cashflow(
            CashflowRequest(
              input: input,
              horizonMonths: ref.watch(forecastHorizonProvider),
              scenarios: [ScenarioRun('draft', key.items)],
            ),
          );
    });
