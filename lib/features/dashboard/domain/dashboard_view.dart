import 'package:flutter/foundation.dart';
import 'package:personal_finance/features/dashboard/domain/board_layout.dart';

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

/// The two arrangements the dashboard keeps, independent of each other:
/// the phone's one ordered list ([compact], < 600) and the rows of every
/// wider window ([expanded], folded to the columns that fit). Both sync.
enum DashboardView { compact, expanded }

/// One widget's selection in a view: whether it shows and its options
/// (forecast account, row limit). A removed widget keeps both.
@immutable
class WidgetEntry {
  const WidgetEntry({this.visible = true, this.options = const {}});

  final bool visible;
  final Map<String, Object?> options;

  WidgetEntry copyWith({bool? visible, Map<String, Object?>? options}) =>
      WidgetEntry(
        visible: visible ?? this.visible,
        options: options ?? this.options,
      );

  @override
  bool operator ==(Object other) =>
      other is WidgetEntry &&
      other.visible == visible &&
      mapEquals(other.options, options);

  @override
  int get hashCode => Object.hash(
    visible,
    Object.hashAllUnordered(
      options.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );
}

/// What a view has saved: Auto or Custom, the selection ([items], keyed by
/// type name) and the custom arrangement — [rows] on expanded, [order] on
/// compact. [rows] and [order] are null until saved and outlive a switch
/// back to Auto.
///
/// [items] holds an entry for every type the app knew at the last save, so
/// a type without one is new (docs/DASHBOARD.md, "New widgets").
@immutable
class DashboardViewState {
  const DashboardViewState({
    this.mode = LayoutMode.auto,
    this.items = const {},
    this.rows,
    this.order,
  });

  /// A view nothing was saved for.
  static const empty = DashboardViewState();

  final LayoutMode mode;
  final Map<String, WidgetEntry> items;
  final List<BoardRow>? rows;
  final List<String>? order;

  DashboardViewState copyWith({
    LayoutMode? mode,
    Map<String, WidgetEntry>? items,
    List<BoardRow>? rows,
    List<String>? order,
  }) => DashboardViewState(
    mode: mode ?? this.mode,
    items: items ?? this.items,
    rows: rows ?? this.rows,
    order: order ?? this.order,
  );

  /// Options of [type] (empty when none are set).
  Map<String, Object?> optionsOf(DashboardWidgetType type) =>
      items[type.name]?.options ?? const {};

  /// Whether [type] shows in [view]: as selected, or — for a type without an
  /// entry — when it is a default of [view] and the view is on Auto (or
  /// nothing was saved yet). On Custom a new type waits in Add widget.
  bool shows(DashboardView view, DashboardWidgetType type) {
    final entry = items[type.name];
    if (entry != null) return entry.visible;
    final isDefault = defaultTypes(view).contains(type);
    return isDefault && (items.isEmpty || mode == LayoutMode.auto);
  }

  /// Whether [type] shipped after the last save and does not show: Add
  /// widget marks it "New".
  bool isNew(DashboardView view, DashboardWidgetType type) =>
      items.isNotEmpty && !items.containsKey(type.name) && !shows(view, type);

  /// The types that show in [view], in enum order.
  List<DashboardWidgetType> shown(DashboardView view) => [
    for (final t in DashboardWidgetType.values)
      if (shows(view, t)) t,
  ];

  /// This state with an entry for every known type, as it shows now in
  /// [view]: what a save writes, so "removed" and "new" stay apart.
  DashboardViewState normalized(DashboardView view) => copyWith(
    items: {
      for (final t in DashboardWidgetType.values)
        t.name: (items[t.name] ?? const WidgetEntry()).copyWith(
          visible: shows(view, t),
        ),
    },
  );

  /// [type] shown or hidden in [view], its options kept.
  DashboardViewState withVisible(
    DashboardView view,
    DashboardWidgetType type, {
    required bool visible,
  }) {
    final base = normalized(view).items;
    return copyWith(
      items: {
        ...base,
        type.name: base[type.name]!.copyWith(visible: visible),
      },
    );
  }

  /// [type]'s options replaced in [view].
  DashboardViewState withOptions(
    DashboardView view,
    DashboardWidgetType type,
    Map<String, Object?> options,
  ) {
    final base = normalized(view).items;
    return copyWith(
      items: {
        ...base,
        type.name: base[type.name]!.copyWith(options: options),
      },
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DashboardViewState &&
      other.mode == mode &&
      mapEquals(other.items, items) &&
      listEquals(other.rows, rows) &&
      listEquals(other.order, order);

  @override
  int get hashCode => Object.hash(
    mode,
    Object.hashAllUnordered(
      items.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    rows == null ? null : Object.hashAll(rows!),
    order == null ? null : Object.hashAll(order!),
  );

  @override
  String toString() =>
      'DashboardViewState($mode, ${items.length} items, $rows, $order)';
}

const _phoneDefaults = [
  DashboardWidgetType.netWorth,
  DashboardWidgetType.monthSummary,
  DashboardWidgetType.budgets,
  DashboardWidgetType.upcomingBills,
  DashboardWidgetType.forecast,
  DashboardWidgetType.recentTransactions,
];

/// The widgets a view shows until the person changes it: six on phones,
/// all on wider screens.
List<DashboardWidgetType> defaultTypes(DashboardView view) => switch (view) {
  DashboardView.compact => _phoneDefaults,
  DashboardView.expanded => DashboardWidgetType.values,
};

/// The phone's default order: the defaults, then the others (hidden until
/// added, so an added one goes to the end).
List<String> defaultPhoneOrder() => [
  for (final t in _phoneDefaults) t.name,
  for (final t in DashboardWidgetType.values)
    if (!_phoneDefaults.contains(t)) t.name,
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
