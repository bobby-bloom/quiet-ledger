import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/dashboard/data/dashboard_layout.dart';

/// Which dashboard widgets are open on this device. Every widget starts
/// open; only the ones stored as `false` are folded.
@immutable
class CardExpansion {
  const CardExpansion([this.folded = const {}]);

  /// Decodes `DashboardSettings.cardExpansion`; '' or malformed JSON means
  /// all open, unknown widget names are ignored.
  factory CardExpansion.decode(String raw) {
    if (raw.isEmpty) return const CardExpansion();
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return const CardExpansion();
      final folded = <DashboardWidgetType>{};
      for (final t in DashboardWidgetType.values) {
        if (json[t.name] == false) folded.add(t);
      }
      return CardExpansion(folded);
    } on FormatException {
      return const CardExpansion();
    }
  }

  final Set<DashboardWidgetType> folded;

  bool isOpen(DashboardWidgetType t) => !folded.contains(t);

  /// Whether opening (or folding) all of [types] would change any of them;
  /// the board menu disables Expand all / Collapse all otherwise.
  bool wouldChange(Iterable<DashboardWidgetType> types, bool open) =>
      types.any((t) => isOpen(t) != open);

  CardExpansion withAll(Iterable<DashboardWidgetType> types, bool open) {
    final next = {...folded};
    for (final t in types) {
      open ? next.remove(t) : next.add(t);
    }
    return CardExpansion(next);
  }

  String encode() =>
      folded.isEmpty ? '' : jsonEncode({for (final t in folded) t.name: false});

  @override
  bool operator ==(Object other) =>
      other is CardExpansion && setEquals(other.folded, folded);

  @override
  int get hashCode => Object.hashAllUnordered(folded);
}

/// Open state of the dashboard widgets, stored in the device-local setting
/// `dashboard.cardExpansion` and shared by the phone and wide views.
final cardExpansionProvider =
    NotifierProvider<CardExpansionController, CardExpansion>(
      CardExpansionController.new,
    );

class CardExpansionController extends Notifier<CardExpansion> {
  @override
  CardExpansion build() => CardExpansion.decode(
    ref.watch(
      settingsProvider.select((s) => s.get(DashboardSettings.cardExpansion)),
    ),
  );

  bool isOpen(DashboardWidgetType t) => state.isOpen(t);

  bool wouldChange(Iterable<DashboardWidgetType> types, bool open) =>
      state.wouldChange(types, open);

  void setOpen(DashboardWidgetType t, bool open) => setAll([t], open);

  void setAll(Iterable<DashboardWidgetType> types, bool open) {
    final next = state.withAll(types, open);
    if (next == state) return;
    // Applied at once; the setting write follows (and rebuilds to the same).
    state = next;
    unawaited(
      ref
          .read(settingsProvider.notifier)
          .set(DashboardSettings.cardExpansion, next.encode()),
    );
  }
}
