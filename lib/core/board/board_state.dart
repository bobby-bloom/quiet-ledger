import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:personal_finance/core/board/board_layout.dart';

/// The two arrangements a board keeps, independent of each other: the
/// phone's one ordered list ([compact], < 600) and the rows of every wider
/// window ([expanded], folded to the columns that fit). Both sync.
enum BoardView { compact, expanded }

/// What a screen's board is made of (docs/BOARD.md): the cards it knows and
/// how it starts. Pure data, a `const` per board, so states and providers
/// can be keyed by it.
@immutable
class BoardDefinition {
  const BoardDefinition({
    required this.id,
    required this.cards,
    required this.compactDefaults,
    required this.defaultRows,
    this.keyPrefix,
    this.legacyKey,
    this.migrateLegacy,
  });

  /// The board's name in storage keys, e.g. `accounts`.
  final String id;

  /// Every card id the board knows, in their canonical order (the order of
  /// lists such as Add, and of new cards without a default slot).
  final List<String> cards;

  /// The cards a phone shows until the person changes it, in order; wider
  /// windows show every card by default.
  final List<String> compactDefaults;

  /// The default rows where `fits` equal columns fit. With fewer than two
  /// columns the board reads its two-column rows row by row.
  final List<BoardRow> Function(int fits) defaultRows;

  /// What storage keys start with; `<id>.` unless given (the dashboard,
  /// whose keys predate other boards, uses none).
  final String? keyPrefix;

  /// The key of a view's older stored layout, and how to read it while no
  /// current one exists; both null when the board has no older format.
  final String Function(BoardView view)? legacyKey;
  final BoardState Function(BoardView view, String json)? migrateLegacy;

  /// The cards [view] shows until the person changes it.
  List<String> defaults(BoardView view) => switch (view) {
    BoardView.compact => compactDefaults,
    BoardView.expanded => cards,
  };

  /// The phone's default order: its defaults, then the other cards (hidden
  /// until added, so an added one goes to the end).
  List<String> get defaultOrder => [
    ...compactDefaults,
    for (final id in cards)
      if (!compactDefaults.contains(id)) id,
  ];

  /// The `dashboard_layouts` row a view is stored in.
  String storageKey(BoardView view) => '${keyPrefix ?? '$id.'}${view.name}.v2';

  /// Where a stored value this build cannot read in full is kept before a
  /// save replaces it.
  String unreadableKey(BoardView view) => '${storageKey(view)}.unreadable';

  @override
  String toString() => 'BoardDefinition($id)';
}

/// One card's selection in a view: whether it shows and its options. A
/// removed card keeps both.
@immutable
class BoardEntry {
  const BoardEntry({this.visible = true, this.options = const {}});

  final bool visible;
  final Map<String, Object?> options;

  BoardEntry copyWith({bool? visible, Map<String, Object?>? options}) =>
      BoardEntry(
        visible: visible ?? this.visible,
        options: options ?? this.options,
      );

  @override
  bool operator ==(Object other) =>
      other is BoardEntry &&
      other.visible == visible &&
      const MapEquality<Object?, Object?>().equals(other.options, options);

  @override
  int get hashCode => Object.hash(
    visible,
    Object.hashAllUnordered(
      options.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );
}

/// What a view of the board [def] has saved: Auto or Custom, the selection
/// ([items], keyed by card id) and the custom arrangement — [rows] on
/// expanded, [order] on compact. [rows] and [order] are null until saved
/// and outlive a switch back to Auto. `BoardState(def)` is nothing saved.
///
/// [items] holds an entry for every card the board knew at the last save,
/// so a card without one is new (docs/BOARD.md, "New cards").
@immutable
class BoardState {
  const BoardState(
    this.def, {
    this.mode = LayoutMode.auto,
    this.items = const {},
    this.rows,
    this.order,
  });

  final BoardDefinition def;
  final LayoutMode mode;
  final Map<String, BoardEntry> items;
  final List<BoardRow>? rows;
  final List<String>? order;

  BoardState copyWith({
    LayoutMode? mode,
    Map<String, BoardEntry>? items,
    List<BoardRow>? rows,
    List<String>? order,
  }) => BoardState(
    def,
    mode: mode ?? this.mode,
    items: items ?? this.items,
    rows: rows ?? this.rows,
    order: order ?? this.order,
  );

  /// Options of [id] (empty when none are set).
  Map<String, Object?> optionsOf(String id) => items[id]?.options ?? const {};

  /// Whether [id] shows in [view]: as selected, or — for a card without an
  /// entry — when it is a default of [view] and the view is on Auto (or
  /// nothing was saved yet). On Custom a new card waits in Add.
  bool shows(BoardView view, String id) {
    final entry = items[id];
    if (entry != null) return entry.visible && def.cards.contains(id);
    final isDefault = def.defaults(view).contains(id);
    return isDefault && (items.isEmpty || mode == LayoutMode.auto);
  }

  /// Whether [id] shipped after the last save and does not show: Add marks
  /// it "New".
  bool isNew(BoardView view, String id) =>
      items.isNotEmpty && !items.containsKey(id) && !shows(view, id);

  /// The cards that show in [view], in the board's order. Ids this build
  /// does not know never show; they keep their entries and slots.
  List<String> shown(BoardView view) => [
    for (final id in def.cards)
      if (shows(view, id)) id,
  ];

  /// This state with an entry for every known card, as it shows now in
  /// [view]: what a save writes, so "removed" and "new" stay apart.
  ///
  /// Entries of cards this build does not know (a newer build's) stay as
  /// they are, so syncing with an older build loses nothing.
  BoardState normalized(BoardView view) => copyWith(
    items: {
      ...items,
      for (final id in def.cards)
        id: (items[id] ?? const BoardEntry()).copyWith(
          visible: shows(view, id),
        ),
    },
  );

  /// This state with the mode and the arrangement of [before] (rows or
  /// order, null included): what an Undo of a layout change writes, leaving
  /// selection and options as they are now.
  BoardState withArrangementOf(BoardState before) => BoardState(
    def,
    mode: before.mode,
    items: items,
    rows: before.rows,
    order: before.order,
  );

  /// This state with every known card shown or hidden as in [before], the
  /// options as they are now.
  BoardState withVisibilityOf(BoardView view, BoardState before) {
    final base = normalized(view).items;
    return copyWith(
      items: {
        ...base,
        for (final id in def.cards)
          id: base[id]!.copyWith(visible: before.shows(view, id)),
      },
    );
  }

  /// [id] shown or hidden in [view], its options kept.
  BoardState withVisible(BoardView view, String id, {required bool visible}) {
    final base = normalized(view).items;
    return copyWith(
      items: {
        ...base,
        id: (base[id] ?? const BoardEntry()).copyWith(visible: visible),
      },
    );
  }

  /// [id]'s options replaced in [view].
  BoardState withOptions(
    BoardView view,
    String id,
    Map<String, Object?> options,
  ) {
    final base = normalized(view).items;
    return copyWith(
      items: {
        ...base,
        id: (base[id] ?? const BoardEntry()).copyWith(options: options),
      },
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BoardState &&
      identical(other.def, def) &&
      other.mode == mode &&
      const MapEquality<Object?, Object?>().equals(other.items, items) &&
      const ListEquality<Object?>().equals(other.rows, rows) &&
      const ListEquality<Object?>().equals(other.order, order);

  @override
  int get hashCode => Object.hash(
    def.id,
    mode,
    Object.hashAllUnordered(
      items.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    rows == null ? null : Object.hashAll(rows!),
    order == null ? null : Object.hashAll(order!),
  );

  @override
  String toString() =>
      'BoardState(${def.id}, $mode, ${items.length} items, $rows, $order)';
}
