import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:personal_finance/core/board/board_storage.dart';
import 'package:personal_finance/features/dashboard/domain/dashboard_view.dart';

export 'package:personal_finance/features/dashboard/domain/dashboard_view.dart'
    show
        BoardEntry,
        BoardState,
        BoardView,
        DashboardView,
        DashboardViewState,
        DashboardWidgetType,
        WidgetEntry,
        dashboardBoard,
        emptyDashboard;

/// One widget as it is built: its type and its options, e.g.
/// `{'accountId': '...'}` for the forecast or `{'limit': 5}` for lists.
@immutable
class DashboardItem {
  const DashboardItem(this.type, {this.options = const {}});

  final DashboardWidgetType type;
  final Map<String, Object?> options;

  DashboardItem copyWith({Map<String, Object?>? options}) =>
      DashboardItem(type, options: options ?? this.options);
}

/// The dashboard's saved views: the board repository for [dashboardBoard].
class DashboardLayoutRepository {
  DashboardLayoutRepository(this._ref);

  final Ref _ref;

  BoardRepository get _board => _ref.read(boardRepositoryProvider);

  Stream<BoardState> watch(BoardView view) =>
      _board.watch(dashboardBoard, view);

  Future<BoardState> read(BoardView view) => _board.read(dashboardBoard, view);

  Future<void> save(BoardView view, BoardState state) =>
      _board.save(dashboardBoard, view, state);

  Future<(BoardState, BoardState)> update(
    BoardView view,
    BoardState Function(BoardState current) change,
  ) => _board.update(dashboardBoard, view, change);
}

final dashboardLayoutRepositoryProvider = Provider(
  DashboardLayoutRepository.new,
);

/// The saved state of a dashboard view, kept up to date.
ProviderListenable<AsyncValue<BoardState>> dashboardViewProvider(
  BoardView view,
) => boardStateProvider((dashboardBoard, view));

/// The `dashboard_layouts` row of a dashboard view.
String storageKey(BoardView view) => dashboardBoard.storageKey(view);

/// Where a dashboard view's unreadable value is kept.
String unreadableKey(BoardView view) => dashboardBoard.unreadableKey(view);
