import 'package:personal_finance/core/board/board_layout.dart';
import 'package:personal_finance/core/board/board_state.dart';
import 'package:personal_finance/features/dashboard/domain/dashboard_legacy.dart';

export 'package:personal_finance/core/board/board_state.dart'
    show BoardEntry, BoardState, BoardView;

/// Widgets available on the dashboard (PLAN.md §2.2). Their `name` is
/// the id stored in layouts.
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

/// The dashboard's two views: the phone's list and the wider rows.
typedef DashboardView = BoardView;

/// What a dashboard view has saved (a [BoardState] of [dashboardBoard]).
typedef DashboardViewState = BoardState;

/// One widget's selection in a view.
typedef WidgetEntry = BoardEntry;

/// Nothing saved for a dashboard view: Auto, the defaults.
const emptyDashboard = BoardState(dashboardBoard);

/// The dashboard as a board (docs/BOARD.md): its widgets by type name, six
/// on phones by default and all on wider screens. Its keys predate other
/// boards (`expanded.v2`, `compact.v2`) and the 0.1 rows (`expanded`,
/// `compact`) are read while no v2 row exists.
const dashboardBoard = BoardDefinition(
  id: 'dashboard',
  cards: _cards,
  compactDefaults: _phoneDefaults,
  defaultRows: defaultRows,
  keyPrefix: '',
  legacyKey: _legacyKey,
  migrateLegacy: migrateLegacyLayout,
);

const _cards = [
  'netWorth',
  'monthSummary',
  'budgets',
  'upcomingBills',
  'forecast',
  'accounts',
  'goals',
  'topCategories',
  'recentTransactions',
];

const _phoneDefaults = [
  'netWorth',
  'monthSummary',
  'budgets',
  'upcomingBills',
  'forecast',
  'recentTransactions',
];

String _legacyKey(BoardView view) => view.name;

/// The widget types that show in [view] of [state], in the board's order.
List<DashboardWidgetType> shownWidgets(BoardState state, BoardView view) => [
  for (final id in state.shown(view)) DashboardWidgetType.values.byName(id),
];

/// The default rows for a window where [fits] equal columns fit. Two
/// columns' rows also give the one-column reading order.
List<BoardRow> defaultRows(int fits) {
  final netWorth = DashboardWidgetType.netWorth.name;
  final monthSummary = DashboardWidgetType.monthSummary.name;
  final budgets = DashboardWidgetType.budgets.name;
  final upcomingBills = DashboardWidgetType.upcomingBills.name;
  final forecast = DashboardWidgetType.forecast.name;
  final accounts = DashboardWidgetType.accounts.name;
  final goals = DashboardWidgetType.goals.name;
  final topCategories = DashboardWidgetType.topCategories.name;
  final recentTransactions = DashboardWidgetType.recentTransactions.name;

  if (fits >= 3) {
    return [
      BoardRow(
        split: RowSplit.wideNarrow,
        columns: [
          [netWorth],
          [monthSummary, forecast],
        ],
      ),
      BoardRow(
        split: RowSplit.thirds,
        columns: [
          [budgets],
          [upcomingBills],
          [goals],
        ],
      ),
      BoardRow(
        split: RowSplit.wideNarrow,
        columns: [
          [recentTransactions],
          [topCategories, accounts],
        ],
      ),
    ];
  }
  return [
    BoardRow(
      split: RowSplit.one,
      columns: [
        [netWorth],
      ],
    ),
    BoardRow(
      split: RowSplit.halves,
      columns: [
        [monthSummary, budgets],
        [forecast, upcomingBills],
      ],
    ),
    BoardRow(
      split: RowSplit.one,
      columns: [
        [recentTransactions],
      ],
    ),
    BoardRow(
      split: RowSplit.halves,
      columns: [
        [goals, accounts],
        [topCategories],
      ],
    ),
  ];
}
