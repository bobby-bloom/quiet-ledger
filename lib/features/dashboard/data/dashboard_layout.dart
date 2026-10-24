import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_providers.dart';

/// Widgets available on the dashboard (PLAN.md §2.2).
enum DashboardWidgetType {
  netWorth,
  monthSummary,
  budgets,
  upcomingBills,
  forecast,
  accounts,
  goals,
  topCategories,
  recentTransactions,
}

/// Width of a widget on wide screens (columns it spans).
enum WidgetSize { normal, wide }

/// One placed widget with its options.
@immutable
class DashboardItem {
  const DashboardItem(
    this.type, {
    this.size = WidgetSize.normal,
    this.options = const {},
  });

  factory DashboardItem.fromJson(Map<String, Object?> j) => DashboardItem(
    DashboardWidgetType.values.byName(j['type']! as String),
    size: WidgetSize.values.byName(j['size'] as String? ?? 'normal'),
    options: ((j['options'] as Map?) ?? const {}).cast(),
  );

  final DashboardWidgetType type;
  final WidgetSize size;

  /// Per-widget options, e.g. `{'accountId': '...'}` for the forecast or
  /// `{'limit': 5}` for lists.
  final Map<String, Object?> options;

  int get span => size == WidgetSize.wide ? 2 : 1;

  DashboardItem copyWith({WidgetSize? size, Map<String, Object?>? options}) =>
      DashboardItem(
        type,
        size: size ?? this.size,
        options: options ?? this.options,
      );

  Map<String, Object?> toJson() => {
    'type': type.name,
    'size': size.name,
    if (options.isNotEmpty) 'options': options,
  };
}

/// Layouts are stored separately for phone ('compact') and wider screens
/// ('expanded'), as desktop users usually want more widgets.
enum DashboardBreakpoint { compact, expanded }

const defaultLayouts = <DashboardBreakpoint, List<DashboardItem>>{
  DashboardBreakpoint.compact: [
    DashboardItem(DashboardWidgetType.netWorth),
    DashboardItem(DashboardWidgetType.monthSummary),
    DashboardItem(DashboardWidgetType.budgets),
    DashboardItem(DashboardWidgetType.upcomingBills),
    DashboardItem(DashboardWidgetType.forecast),
    DashboardItem(DashboardWidgetType.recentTransactions),
  ],
  DashboardBreakpoint.expanded: [
    DashboardItem(DashboardWidgetType.netWorth, size: WidgetSize.wide),
    DashboardItem(DashboardWidgetType.monthSummary),
    DashboardItem(DashboardWidgetType.budgets),
    DashboardItem(DashboardWidgetType.upcomingBills),
    DashboardItem(DashboardWidgetType.forecast),
    DashboardItem(
      DashboardWidgetType.recentTransactions,
      size: WidgetSize.wide,
    ),
    DashboardItem(DashboardWidgetType.goals),
    DashboardItem(DashboardWidgetType.topCategories),
    DashboardItem(DashboardWidgetType.accounts),
  ],
};

class DashboardLayoutRepository {
  DashboardLayoutRepository(this._ref);

  final Ref _ref;

  AppDatabase get _db => _ref.read(databaseProvider);

  Stream<List<DashboardItem>> watch(DashboardBreakpoint bp) {
    return (_db.select(_db.dashboardLayouts)
          ..where((l) => l.breakpoint.equals(bp.name) & l.deletedAt.isNull()))
        .watch()
        .map((rows) {
          if (rows.isEmpty) return defaultLayouts[bp]!;
          try {
            final list = jsonDecode(rows.first.widgets) as List;
            return [
              for (final e in list)
                if (_known(e)) DashboardItem.fromJson((e as Map).cast()),
            ];
          } on FormatException {
            return defaultLayouts[bp]!;
          }
        });
  }

  static bool _known(Object? e) =>
      e is Map && DashboardWidgetType.values.any((t) => t.name == e['type']);

  Future<void> save(DashboardBreakpoint bp, List<DashboardItem> items) async {
    final writer = _ref.read(syncWriterProvider);
    final json = jsonEncode([for (final i in items) i.toJson()]);
    await writer.transaction(() async {
      final existing =
          await (_db.select(_db.dashboardLayouts)..where(
                (l) => l.breakpoint.equals(bp.name) & l.deletedAt.isNull(),
              ))
              .getSingleOrNull();
      if (existing == null) {
        await writer.insert(
          _db.dashboardLayouts,
          DashboardLayoutsCompanion(
            breakpoint: Value(bp.name),
            widgets: Value(json),
          ),
        );
      } else {
        await writer.update(
          _db.dashboardLayouts,
          existing.id,
          DashboardLayoutsCompanion(widgets: Value(json)),
        );
      }
    });
  }

  Future<void> reset(DashboardBreakpoint bp) async {
    final existing =
        await (_db.select(_db.dashboardLayouts)..where(
              (l) => l.breakpoint.equals(bp.name) & l.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (existing != null) {
      await _ref
          .read(syncWriterProvider)
          .delete(_db.dashboardLayouts, existing.id);
    }
  }
}

final dashboardLayoutRepositoryProvider = Provider(
  DashboardLayoutRepository.new,
);

final dashboardLayoutProvider =
    StreamProvider.family<List<DashboardItem>, DashboardBreakpoint>(
      (ref, bp) => ref.watch(dashboardLayoutRepositoryProvider).watch(bp),
    );
