import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FlutterView, lerpDouble;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/board/arrange_card.dart';
import 'package:personal_finance/app/ui/board/board_labels.dart';
import 'package:personal_finance/app/ui/board/drop_slot.dart';
import 'package:personal_finance/app/ui/board/row_band.dart';
import 'package:personal_finance/core/board/arrange.dart';
import 'package:personal_finance/core/board/board_layout.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

/// The least height a "New row" target takes while a card is dragged, a
/// fingertip and some: what a gap lacks of it comes from the top edge of
/// the band below it.
const double _newRowReach = 32;

/// A board in arrange mode (docs/BOARD.md, Arrange mode): the
/// working [rows] as [RowBand]s with their toolbars, every card present as
/// an [ArrangeCard], a [DropSlot] where a dragged one would land, "Drag a
/// card here" in empty columns, a "New row" slot in the gaps above,
/// between and below the rows, and "Add row" under the last.
///
/// Where a dragged card would land follows the pointer, also while the
/// board scrolls (a wheel) under it, and only where the board shows. There
/// is no auto-scroll: the arranged board is short, and the Move menu is the
/// way when it is not.
///
/// Every change — a drop, a Move, a row edit — goes to [onChanged] as new
/// rows; the session keeps them until Done or Cancel. Focus starts on the
/// first card and follows a moved card or row; each move is announced.
class ArrangeBoard extends StatefulWidget {
  const ArrangeBoard({
    required this.rows,
    required this.present,
    required this.fits,
    required this.labels,
    required this.onChanged,
    required this.onRemove,
    super.key,
    this.gap = boardGap,
  });

  /// The working arrangement: placed rows, hidden cards in their slots.
  final List<BoardRow> rows;

  /// The cards that show.
  final Set<String> present;

  /// How many columns fit; wider rows show squeezed.
  final int fits;

  final double gap;

  /// The board's words and its cards' names and icons.
  final BoardLabels labels;
  final ValueChanged<List<BoardRow>> onChanged;

  /// Takes a card off the board, inside the session.
  final ValueChanged<String> onRemove;

  @override
  State<ArrangeBoard> createState() => _ArrangeBoardState();
}

class _ArrangeBoardState extends State<ArrangeBoard> {
  static const double _bandPadding = RowBand.padding;

  /// One key per card: it keeps its menu and focus wherever it moves, and
  /// a drag measures the cards it passes.
  final _keys = <String, GlobalKey>{};

  /// The ⋮ button of each card, and of each row by its place.
  final _focusNodes = <String, FocusNode>{};
  final _rowFocusNodes = <FocusNode>[];

  /// The row whose split was just picked, until the frame that shows it:
  /// only its columns glide to their new widths.
  int? _resplit;

  /// The card being dragged and the pointer's last global position.
  String? _dragging;
  Offset? _pointer;

  FlutterView? _view;
  TextDirection _textDirection = TextDirection.ltr;
  var _isMotionReduced = false;
  ScrollableState? _scrollable;

  /// The slots the last build showed, open or closing.
  Set<ArrangeTarget> _shownSlots = const {};

  /// Where the board was on screen after the last frame of a drag, and
  /// whether its parent rebuilt it since: either change aims again.
  Offset? _boardOrigin;
  var _isLayoutChanged = false;
  var _isWatching = false;

  /// Where the dragged card would land now.
  ArrangeTarget? _target;

  /// Whether the slot is still the lifted card's own place, open from the
  /// start at full height, so nothing moves as it lifts.
  var _isLiftedInPlace = false;

  /// The slots the dragged card left, closing as the new one opens, so
  /// what lies under the pointer stays put. Only while a drag runs.
  final _closing = <ArrangeTarget>{};

  /// The card settling into its place after a drop, and where its lifted
  /// copy was let go — until its glide starts.
  String? _settling;
  Offset? _settleFrom;

  /// The row being dragged by its toolbar, and the gap it would land in
  /// (0 = above the first row). The board keeps its layout meanwhile: the
  /// row dims in place and a line marks the gap, so nothing moves under the
  /// pointer.
  int? _draggingRow;
  int? _rowTarget;
  final _bandKeys = <int, GlobalKey>{};

  /// The board's width, for the lifted row.
  double _width = 0;

  /// The words, read with the dependencies: a board that goes mid-drag
  /// still announces the drop from dispose.
  late AppLocalizations _l;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final first = [for (final row in widget.rows) ...row.cardIds]
          .where(widget.present.contains);
      if (mounted && first.isNotEmpty) _focusNodes[first.first]?.requestFocus();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scrollable = Scrollable.maybeOf(context, axis: Axis.vertical);
    _l = AppLocalizations.of(context);
    _view = View.maybeOf(context);
    _textDirection = Directionality.of(context);
    _isMotionReduced = Motion.isReduced(context);
  }

  @override
  void didUpdateWidget(ArrangeBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _isLayoutChanged = true;

    // The held card left the board: its drag will never end on its own,
    // so it ends here, dropped.
    final dragging = _dragging;
    if (dragging != null && !_isShown(dragging)) {
      _dragging = null;
      _target = null;
      _closing.clear();
      _pointer = null;
      _announce(_l.boardDropped(widget.labels.cardName(dragging)));
    }
    // The rows changed under a lifted row (an undo, a paused session
    // coming back): the drag ends where it is, nothing moved.
    final row = _draggingRow;
    if (row != null &&
        !const ListEquality<BoardRow>().equals(widget.rows, oldWidget.rows)) {
      _draggingRow = null;
      _rowTarget = null;
      _pointer = null;
      _announce(_l.boardRowDropped(row + 1));
    }
  }

  @override
  void dispose() {
    // The board went mid-drag (arrange mode paused or ended): the card
    // stays where it was.
    if (_dragging case final dragging?) {
      _announce(_l.boardDropped(widget.labels.cardName(dragging)));
    }
    if (_draggingRow case final row?) {
      _announce(_l.boardRowDropped(row + 1));
    }
    for (final node in [..._focusNodes.values, ..._rowFocusNodes]) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows;
    _shownSlots = {..._closing, ?_target};

    return LayoutBuilder(
      builder: (context, constraints) {
        _width = constraints.maxWidth;
        return _rowsAndGaps(rows);
      },
    );
  }

  Widget _rowsAndGaps(List<BoardRow> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, row) in rows.indexed) ...[
          _gap(NewRowTarget(index)),
          _band(index, row),
        ],
        _gap(NewRowTarget(rows.length)),
        // Dropped here, a card goes below the last row.
        _DropArea(
          targetAt: (_) => NewRowTarget(rows.length),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.tonalIcon(
              onPressed: () => widget.onChanged(addRow(rows, widget.fits)),
              icon: const Icon(Icons.add),
              label: Text(_l.boardAddRow),
            ),
          ),
        ),
      ],
    );
  }

  Widget _gap(NewRowTarget target) {
    final gap = _NewRowGap(
      target: target,
      current: _target,
      isClosing: _closing.contains(target),
      onClosed: () => _closed(target),
      isDragging: _dragging != null,
      height: widget.gap,
      label: _l.boardNewRow,
    );
    if (_draggingRow == null || _rowTarget != target.at || !_rowMoves) {
      return gap;
    }
    // Where the lifted row would land: a line in the gap, as tall as the
    // gap already is.
    return Stack(
      alignment: Alignment.center,
      children: [
        gap,
        IgnorePointer(
          child: Container(
            key: const ValueKey('row drop line'),
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(Radii.full),
            ),
          ),
        ),
      ],
    );
  }

  /// Whether the lifted row would move where it would land now.
  bool get _rowMoves {
    final from = _draggingRow;
    final to = _rowTarget;
    return from != null && to != null && to != from && to != from + 1;
  }

  /// [row] as a dashed band of its shown columns and one drop area: the
  /// pointer picks the column under it and the place between its cards —
  /// but for the band's top edge, which counts towards the "New row" gap.
  Widget _band(int index, BoardRow row) {
    final columns = shownColumns(row, widget.present, widget.fits);
    return Builder(
      builder: (band) => _DropArea(
        targetAt: (pointer) {
          final box = band.findRenderObject()! as RenderBox;
          if (box.globalToLocal(pointer).dy < _newRowEdge) {
            return NewRowTarget(index);
          }
          return _targetIn(band, index, pointer);
        },
        child: FocusTraversalGroup(
          child: AnimatedOpacity(
            key: _bandKeys.putIfAbsent(
              index,
              () => GlobalKey(debugLabel: 'row $index'),
            ),
            opacity: _draggingRow == index ? 0.4 : 1,
            duration: _isMotionReduced ? Duration.zero : Motion.quick,
            child: RowBand(
              index: index,
              count: widget.rows.length,
              row: row,
              fits: widget.fits,
              menuFocusNode: _rowFocusNode(index),
              dragHandle: (handle) => _rowHandle(index, row, handle),
              onSplit: (split) {
                _resplit = index;
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _resplit = null,
                );
                _editRows(changeSplit(widget.rows, index, split));
              },
              onMoveUp: index > 0
                  ? () =>
                        _editRows(moveRow(widget.rows, index), focus: index - 1)
                  : null,
              onMoveDown: index < widget.rows.length - 1
                  ? () => _editRows(
                      moveRow(widget.rows, index, down: true),
                      focus: index + 1,
                    )
                  : null,
              onRemove: widget.rows.length > 1
                  ? () => _editRows(
                      removeRow(widget.rows, index),
                      focus: index == 0 ? 0 : index - 1,
                    )
                  : null,
              child: FocusTraversalGroup(
                child: _BandColumns(
                  split: shownSplit(row, widget.fits),
                  rowSplit: row.split,
                  glides: _resplit == index,
                  gap: widget.gap,
                  children: [
                    for (final (column, ids) in columns.indexed)
                      _column(index, column, ids),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// How much of the top of a band counts towards the "New row" gap above
  /// it: what the gap lacks of [_newRowReach] — its padding and the top of
  /// its toolbar, never a column.
  double get _newRowEdge => (_newRowReach - widget.gap).clamp(
    0,
    RowBand.padding + RowBand.toolbarHeight,
  );

  FocusNode _rowFocusNode(int index) {
    while (_rowFocusNodes.length <= index) {
      _rowFocusNodes.add(FocusNode(debugLabel: 'row ${_rowFocusNodes.length}'));
    }
    return _rowFocusNodes[index];
  }

  /// Hands [rows] up after a row edit, then puts focus on the ⋮ of the row
  /// at [focus].
  void _editRows(List<BoardRow> rows, {int? focus}) {
    widget.onChanged(rows);
    if (focus == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && focus < _rowFocusNodes.length) {
        _rowFocusNodes[focus].requestFocus();
      }
    });
  }

  /// Where a card held at [pointer] lands in the band [band] of [row].
  ColumnTarget _targetIn(BuildContext band, int row, Offset pointer) {
    final box = band.findRenderObject()! as RenderBox;
    final widths = columnWidths(
      shownSplit(widget.rows[row], widget.fits),
      box.size.width - 2 * _bandPadding,
      gap: widget.gap,
    );
    var x = box.globalToLocal(pointer).dx - _bandPadding;
    if (Directionality.of(band) == TextDirection.rtl) {
      x = box.size.width - 2 * _bandPadding - x;
    }

    var column = 0;
    var start = 0.0;
    while (column < widths.length - 1 &&
        x >= start + widths[column] + widget.gap / 2) {
      start += widths[column] + widget.gap;
      column++;
    }

    final ids = shownColumns(
      widget.rows[row],
      widget.present,
      widget.fits,
    )[column];
    return ColumnTarget(
      row: row,
      column: column,
      index: _indexAt([...ids.where((id) => id != _dragging)], pointer),
    );
  }

  /// The cards [ids] of one shown column: the slot opens where the dragged
  /// one would land, slots it left close, and the dragged one leaves its
  /// place. A slot carries its gap to the next card.
  Widget _column(int row, int column, List<String> ids) {
    final others = [
      for (final id in ids)
        if (id != _dragging) id,
    ];
    int? indexOf(ArrangeTarget? target) =>
        target is ColumnTarget && target.row == row && target.column == column
        ? math.min(target.index, others.length)
        : null;
    final slots = <int, List<ArrangeTarget>>{};
    for (final target in [?_target, ..._closing]) {
      if (indexOf(target) case final index?) {
        (slots[index] ??= []).add(target);
      }
    }

    final children = <Widget>[];
    Widget slot(
      ArrangeTarget target,
      EdgeInsets padding, {
      bool inPlaceOfLabel = false,
    }) => _GrowIn(
      key: ValueKey(target),
      isOpen: target == _target,
      startsOpen: (inPlaceOfLabel || _isLiftedInPlace) && target == _target,
      onClosed: () => _closed(target),
      child: Padding(
        padding: padding,
        child: const DropSlot(kind: DropSlotKind.insertion),
      ),
    );
    for (final (index, id) in others.indexed) {
      for (final target in slots[index] ?? const <ArrangeTarget>[]) {
        children.add(
          slot(
            target,
            EdgeInsets.only(
              top: index == 0 ? 0 : widget.gap,
              bottom: index == 0 ? widget.gap : 0,
            ),
          ),
        );
      }
      children.add(
        Padding(
          padding: EdgeInsets.only(top: index == 0 ? 0 : widget.gap),
          child: _card(id),
        ),
      );
    }
    if (others.isEmpty) {
      // An empty column shows the slot in place of "Drag a card here", at
      // its full height at once: growing from nothing would shrink the row
      // under the pointer, which then leaves it, and the row flickers.
      final open = indexOf(_target);
      children.add(
        open != null
            ? slot(_target!, EdgeInsets.zero, inPlaceOfLabel: true)
            : DropSlot(
                kind: DropSlotKind.emptyColumn,
                label: widget.labels.emptyColumn,
              ),
      );
    } else {
      for (final target in slots[others.length] ?? const <ArrangeTarget>[]) {
        children.add(slot(target, EdgeInsets.only(top: widget.gap)));
      }
    }
    // Stays in the tree while lifted, so its drag goes on.
    if (_dragging != null && ids.contains(_dragging)) {
      children.add(_card(_dragging!));
    }

    // Each column reads and tabs as one group.
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: FocusTraversalGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }

  Widget _card(String id) {
    final rows = widget.rows;
    final position = positionOf(
      rows,
      id,
      present: widget.present,
      fits: widget.fits,
    )!;
    final card = ArrangeCard(
      key: _keys.putIfAbsent(id, () => GlobalKey(debugLabel: 'arrange $id')),
      id: id,
      icon: widget.labels.cardIcon(id),
      title: widget.labels.cardName(id),
      positionLabel: _positionLabel(id, position),
      moves: possibleMoves(
        rows,
        id,
        present: widget.present,
        fits: widget.fits,
      ),
      onMove: (move) => _move(id, move),
      onRemove: () => _remove(id),
      removeLabel: widget.labels.removeFromBoard,
      focusNode: _focusNodes.putIfAbsent(
        id,
        () => FocusNode(debugLabel: 'move $id'),
      ),
      canLift: _canLift,
      onDragStarted: (pointer) => _startDrag(id, pointer),
      onDragMoved: (pointer) => _dragMoved(id, pointer),
      onDragEnded: (from, {required isCancelled}) =>
          _endDrag(id, from, isCancelled: isCancelled),
    );
    if (id != _settling) return card;

    return _Settle(
      from: _settleFrom,
      onStarted: () => _settleFrom = null,
      onDone: () {
        if (mounted && _settling == id) setState(() => _settling = null);
      },
      child: card,
    );
  }

  /// How many of [others] lie above [pointer], by their middles.
  int _indexAt(List<String> others, Offset pointer) {
    var index = 0;
    for (final id in others) {
      final box = _keys[id]?.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final middle = box.localToGlobal(box.size.center(Offset.zero)).dy;
      if (pointer.dy > middle) index++;
    }
    return index;
  }

  /// One drag at a time — a card or a row —, asked also the moment a
  /// drag would start.
  bool _canLift() => mounted && _dragging == null && _draggingRow == null;

  /// [handle] (the toolbar's grip and label) as what drags the row at
  /// [index]: lifted, the row follows the pointer as its toolbar with the
  /// names of its cards.
  Widget _rowHandle(int index, BoardRow row, Widget handle) {
    final theme = Theme.of(context);
    final titles = [
      for (final ids in shownColumns(row, widget.present, widget.fits))
        for (final id in ids) widget.labels.cardName(id),
    ];
    return Draggable<int>(
      data: index,
      maxSimultaneousDrags: _canLift() ? 1 : 0,
      // A row spans the board: it only moves up and down.
      axis: Axis.vertical,
      // Lifted from where it lies: the copy lines up with the band's start,
      // the pointer where it took hold of the toolbar.
      dragAnchorStrategy: (draggable, context, position) {
        final band =
            _bandKeys[index]?.currentContext?.findRenderObject() as RenderBox?;
        if (band == null || !band.hasSize) {
          return childDragAnchorStrategy(draggable, context, position);
        }
        final local = band.globalToLocal(position);
        return Offset(local.dx, local.dy.clamp(0, arrangeCardHeight));
      },
      onDragStarted: () => _startRowDrag(index),
      onDragUpdate: (details) => _rowDragMoved(details.globalPosition),
      onDragEnd: (_) => _endRowDrag(index),
      feedback: Theme(
        data: theme,
        child: _LiftedRow(
          width: _width,
          label: _l.boardRow(index + 1),
          split: row.split,
          titles: titles,
          isMotionReduced: _isMotionReduced,
        ),
      ),
      child: handle,
    );
  }

  void _startRowDrag(int index) {
    final board = context.findRenderObject();
    _boardOrigin = board is RenderBox && board.attached
        ? board.localToGlobal(Offset.zero)
        : null;
    _isLayoutChanged = false;
    setState(() {
      _draggingRow = index;
      _rowTarget = null;
      _settling = null;
    });
    _announce(_l.boardRowPickedUp(index + 1));
    _watchLayout();
  }

  void _rowDragMoved(Offset pointer) {
    if (_draggingRow == null) return;
    _pointer = pointer;
    _retargetRow();
  }

  /// The gap a lifted row lands in: before the first band whose middle lies
  /// below the pointer — only where the board shows.
  void _retargetRow() {
    final pointer = _pointer;
    final board = context.findRenderObject();
    if (!mounted || _draggingRow == null || pointer == null) return;
    int? target;
    if (board is RenderBox && board.hasSize && _isShownAt(pointer, board)) {
      target = 0;
      for (var i = 0; i < widget.rows.length; i++) {
        final box =
            _bandKeys[i]?.currentContext?.findRenderObject() as RenderBox?;
        if (box == null || !box.hasSize) continue;
        final middle = box.localToGlobal(box.size.center(Offset.zero)).dy;
        if (pointer.dy > middle) target = i + 1;
      }
    }
    if (target != _rowTarget) setState(() => _rowTarget = target);
  }

  /// The lifted row at [from] is let go: it moves to the gap shown, or
  /// stays where it was.
  void _endRowDrag(int from) {
    if (!mounted || _draggingRow != from) return;
    final to = _rowTarget;
    final moves = _rowMoves;
    setState(() {
      _draggingRow = null;
      _rowTarget = null;
      _pointer = null;
    });
    if (!moves || to == null) {
      _announce(_l.boardRowDropped(from + 1));
      return;
    }
    final rows = moveRowTo(widget.rows, from, to);
    final at = to > from ? to - 1 : to;
    widget.onChanged(rows);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (at < _rowFocusNodes.length) _rowFocusNodes[at].requestFocus();
      _announce(_l.boardRowMovedTo(at + 1, rows.length));
    });
  }

  bool _isShown(String id) =>
      widget.present.contains(id) &&
      widget.rows.any((row) => row.cardIds.contains(id));

  /// [id] is lifted at [pointer]. The slot opens in its own place at full
  /// height, so nothing moves and a card let go without moving stays.
  void _startDrag(String id, Offset pointer) {
    assert(_dragging == null, 'one drag at a time');
    final board = context.findRenderObject();
    final place = positionOf(
      widget.rows,
      id,
      present: widget.present,
      fits: widget.fits,
    );
    _pointer = pointer;
    _boardOrigin = board is RenderBox && board.attached
        ? board.localToGlobal(Offset.zero)
        : null;
    _isLayoutChanged = false;
    setState(() {
      _dragging = id;
      _target = place == null
          ? null
          : ColumnTarget(
              row: place.row,
              column: place.column,
              index: place.index,
            );
      _isLiftedInPlace = true;
      _closing.clear();
      _settling = null;
    });
    _announce(_l.boardPickedUp(widget.labels.cardName(id)));
    _watchLayout();
  }

  void _dragMoved(String id, Offset pointer) {
    if (id != _dragging) return;
    _pointer = pointer;
    _retarget();
  }

  /// After each frame of a drag: when the board moved on screen (a wheel
  /// scroll) or its parent rebuilt it, aim again, since pointer moves alone
  /// never tell the board.
  void _watchLayout() {
    if (_isWatching) return;
    _isWatching = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isWatching = false;
      final board = mounted ? context.findRenderObject() : null;
      if ((_dragging == null && _draggingRow == null) ||
          board is! RenderBox ||
          !board.attached) {
        return;
      }
      final origin = board.localToGlobal(Offset.zero);
      if (origin != _boardOrigin || _isLayoutChanged) {
        _boardOrigin = origin;
        _isLayoutChanged = false;
        if (_draggingRow != null) {
          _retargetRow();
        } else {
          _retarget();
        }
      }
      _watchLayout();
    });
  }

  /// Points the slot at what lies under the pointer now: the [_DropArea] a
  /// hit test of the board finds there, but only where the board shows —
  /// inside its scroll view and under nothing else.
  void _retarget() {
    final pointer = _pointer;
    if (!mounted || _dragging == null || pointer == null) return;
    final board = context.findRenderObject();
    if (board is! RenderBox || !board.hasSize) return;

    ArrangeTarget? target;
    if (_isShownAt(pointer, board)) {
      final result = BoxHitTestResult();
      board.hitTest(result, position: board.globalToLocal(pointer));
      for (final entry in result.path) {
        if (entry.target case RenderMetaData(
          metaData: final _DropAreaData area,
        )) {
          target = area.targetAt(pointer);
          break;
        }
      }
    }

    final old = _target;
    if (old != target) {
      setState(() {
        if (old != null &&
            _shownSlots.contains(old) &&
            !_isMotionReduced &&
            _isSlotBuilt(old)) {
          _closing.add(old);
        }
        _closing.remove(target);
        _target = target;
        _isLiftedInPlace = false;
      });
    }
  }

  /// Whether a slot at [target] is built to close: a gap always, a place in
  /// a column only among other cards.
  bool _isSlotBuilt(ArrangeTarget target) => switch (target) {
    NewRowTarget() => true,
    ColumnTarget(:final row, :final column) =>
      row < widget.rows.length &&
          shownColumns(
                widget.rows[row],
                widget.present,
                widget.fits,
              ).elementAtOrNull(column)?.any((id) => id != _dragging) ==
              true,
  };

  /// Whether [target] still lies in the rows.
  bool _isInRows(ArrangeTarget target) => switch (target) {
    NewRowTarget(:final at) => at <= widget.rows.length,
    ColumnTarget(:final row, :final column) =>
      row < widget.rows.length &&
          column <
              shownColumns(
                widget.rows[row],
                widget.present,
                widget.fits,
              ).length,
  };

  void _closed(ArrangeTarget target) {
    if (mounted && _closing.contains(target)) {
      setState(() => _closing.remove(target));
    }
  }

  /// Whether a pointer at [pointer] reaches the [board] on screen: inside
  /// its scroll view, and nothing over it takes the pointer first.
  bool _isShownAt(Offset pointer, RenderBox board) {
    final view = _view;
    if (view == null) return false;
    final scrollView = _scrollable?.context.findRenderObject() ?? board;
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(result, pointer, view.viewId);
    return result.path.any((entry) => entry.target == scrollView);
  }

  /// The drag of [id] ended with its lifted copy at [from]: let go, it lands
  /// where the slot shows; with no slot, or cancelled, it stays.
  void _endDrag(String id, Offset from, {required bool isCancelled}) {
    if (!mounted) return;
    assert(id == _dragging, 'only the lifted widget ends a drag');
    final target = isCancelled ? null : _target;
    if (target != null && _isInRows(target)) {
      _drop(id, target, from);
      return;
    }
    setState(() {
      _dragging = null;
      _target = null;
      _closing.clear();
    });
    _announce(_l.boardDropped(widget.labels.cardName(id)));
  }

  void _drop(String id, ArrangeTarget target, Offset from) {
    final rows = dropCard(
      widget.rows,
      id,
      target,
      present: widget.present,
      fits: widget.fits,
    );
    setState(() {
      _dragging = null;
      _target = null;
      _closing.clear();
      _settling = _isMotionReduced ? null : id;
      _settleFrom = from;
    });
    if (identical(rows, widget.rows)) {
      _announce(_l.boardDropped(widget.labels.cardName(id)));
    } else {
      _commit(id, rows);
    }
  }

  void _move(String id, CardMove move) {
    final target = moveTarget(
      widget.rows,
      id,
      move,
      present: widget.present,
      fits: widget.fits,
    );
    if (target == null) return;
    setState(() => _settling = null);
    _commit(
      id,
      dropCard(
        widget.rows,
        id,
        target,
        present: widget.present,
        fits: widget.fits,
      ),
    );
  }

  /// Takes [id] off the board, says so, and puts focus on the card that
  /// followed it (or the one before, at the end).
  void _remove(String id) {
    final order = [
      for (final row in widget.rows)
        for (final ids in shownColumns(row, widget.present, widget.fits))
          ...ids,
    ];
    final at = order.indexOf(id);
    final next = at + 1 < order.length
        ? order[at + 1]
        : at > 0
        ? order[at - 1]
        : null;
    widget.onRemove(id);
    _announce(_l.boardRemoved(widget.labels.cardName(id)));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && next != null) _focusNodes[next]?.requestFocus();
    });
  }

  /// Hands [rows] up, then keeps focus on [id] and says where it went.
  void _commit(String id, List<BoardRow> rows) {
    widget.onChanged(rows);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNodes[id]?.requestFocus();
      final position = positionOf(
        widget.rows,
        id,
        present: widget.present,
        fits: widget.fits,
      );
      if (position != null) _announce(_positionLabel(id, position));
    });
  }

  String _positionLabel(String id, ArrangePosition p) => _l.boardMoved(
    widget.labels.cardName(id),
    p.row + 1,
    p.column + 1,
    p.index + 1,
    p.count,
  );

  void _announce(String message) {
    if (_view case final view?) {
      unawaited(
        SemanticsService.sendAnnouncement(view, message, _textDirection),
      );
    }
  }
}

/// The shown columns of a band side by side, as wide as [split] makes them.
/// When the row's own split ([rowSplit]) changes with [glides], the widths
/// glide there as one set of shares, so the row never overflows; anything
/// else and reduced motion set them at once.
class _BandColumns extends StatefulWidget {
  const _BandColumns({
    required this.split,
    required this.rowSplit,
    required this.glides,
    required this.gap,
    required this.children,
  });

  final RowSplit split;
  final RowSplit rowSplit;
  final bool glides;
  final double gap;
  final List<Widget> children;

  @override
  State<_BandColumns> createState() => _BandColumnsState();
}

class _BandColumnsState extends State<_BandColumns>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    value: 1,
    duration: Motion.standard,
  );

  /// The shares the glide starts from; null while not gliding.
  List<double>? _from;

  /// The shares last laid out.
  List<double> _shown = const [];

  @override
  void didUpdateWidget(_BandColumns oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rowSplit == oldWidget.rowSplit) return;
    if (widget.glides && !Motion.isReduced(context) && _shown.isNotEmpty) {
      _from = _shown;
      _animation.forward(from: 0);
    } else {
      _from = null;
      _animation.value = 1;
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final count = widget.children.length;
      final available = math.max<double>(
        0,
        constraints.maxWidth - widget.gap * (count - 1),
      );
      final target = _sharesOf(
        columnWidths(widget.split, constraints.maxWidth, gap: widget.gap),
      );
      return AnimatedBuilder(
        animation: _animation,
        builder: (context, _) {
          final shares = _shown = _sharesNow(target);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: widget.gap,
            children: [
              for (final (column, child) in widget.children.indexed)
                if (column == count - 1)
                  Expanded(child: child)
                else
                  SizedBox(width: shares[column] * available, child: child),
            ],
          );
        },
      );
    },
  );

  List<double> _sharesOf(List<double> widths) {
    final total = widths.fold<double>(0, (sum, w) => sum + w);
    if (total <= 0) return List.filled(widths.length, 1 / widths.length);
    return [for (final w in widths) w / total];
  }

  List<double> _sharesNow(List<double> target) {
    final from = _from;
    if (from == null || _animation.isCompleted) return target;
    final t = Motion.curve.transform(_animation.value);
    return _sharesOf([
      for (final (c, share) in target.indexed)
        lerpDouble(c < from.length ? from[c] : 0, share, t)!,
    ]);
  }
}

/// The gap before the row at [target]: plain space while nothing is
/// dragged, a dotted line while something is, and the "New row" slot while
/// the dragged card hovers it, closing again once it moves on.
class _NewRowGap extends StatelessWidget {
  const _NewRowGap({
    required this.target,
    required this.current,
    required this.isClosing,
    required this.onClosed,
    required this.isDragging,
    required this.height,
    required this.label,
  });

  final NewRowTarget target;
  final ArrangeTarget? current;
  final bool isClosing;
  final VoidCallback onClosed;
  final bool isDragging;
  final double height;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isOpen = current == target;
    if (!isDragging) {
      return _DropArea(
        targetAt: (_) => target,
        child: SizedBox(height: height),
      );
    }
    return _DropArea(
      targetAt: (_) => target,
      child: CustomPaint(
        painter: !isOpen && !isClosing
            ? _DottedLinePainter(
                color: Theme.of(context).colorScheme.primary
                    .withValues(alpha: 0.45),
              )
            : null,
        // The slot opens from the gap's own height: the band below never
        // jumps up under a pointer on its top edge.
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: height / 2),
          child: _GrowIn(
            isOpen: isOpen,
            onClosed: onClosed,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: height / 2),
              child: DropSlot(kind: DropSlotKind.newRow, label: label),
            ),
          ),
        ),
      ),
    );
  }
}

/// A part of the board a dragged card can be let go over: all of
/// [child]'s box, by a hit test, and where in it the card would land for
/// a global pointer position ([targetAt]).
class _DropArea extends StatelessWidget {
  const _DropArea({required this.targetAt, required this.child});

  final ArrangeTarget Function(Offset pointer) targetAt;
  final Widget child;

  @override
  Widget build(BuildContext context) => MetaData(
    metaData: _DropAreaData(targetAt),
    behavior: HitTestBehavior.translucent,
    child: child,
  );
}

class _DropAreaData {
  const _DropAreaData(this.targetAt);

  final ArrangeTarget Function(Offset pointer) targetAt;
}

/// [child] gliding from where it was let go, [from] (global), into its
/// place on [Motion.expressive], then [onDone]. Measured after its first
/// layout, so it stays invisible for that one frame.
class _Settle extends StatefulWidget {
  const _Settle({
    required this.from,
    required this.onStarted,
    required this.onDone,
    required this.child,
  });

  final Offset? from;
  final VoidCallback onStarted;
  final VoidCallback onDone;
  final Widget child;

  @override
  State<_Settle> createState() => _SettleState();
}

class _SettleState extends State<_Settle> with SingleTickerProviderStateMixin {
  late final _animation =
      AnimationController(vsync: this, duration: Motion.expressive)
        ..addStatusListener((status) {
          if (status.isCompleted) widget.onDone();
        });

  Offset? _offset;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final from = widget.from;
      final box = context.findRenderObject() as RenderBox?;
      if (from == null || box == null || !box.hasSize) {
        setState(() => _offset = Offset.zero);
        widget.onDone();
        return;
      }
      widget.onStarted();
      setState(() => _offset = from - box.localToGlobal(Offset.zero));
      _animation.forward();
    });
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _animation,
    builder: (context, child) {
      final offset = _offset;
      return Opacity(
        opacity: offset == null && widget.from != null ? 0 : 1,
        child: Transform.translate(
          offset:
              (offset ?? Offset.zero) *
              (1 - Motion.spring.transform(_animation.value)),
          child: child,
        ),
      );
    },
    child: widget.child,
  );
}

/// [child] opening from nothing to its height on [Motion.standard] while
/// [isOpen] — or showing at once with [startsOpen] — and closing back to
/// nothing, then [onClosed]. Reduced motion opens and closes at once.
class _GrowIn extends StatelessWidget {
  const _GrowIn({
    required this.isOpen,
    required this.child,
    super.key,
    this.startsOpen = false,
    this.onClosed,
  });

  final bool isOpen;
  final Widget child;
  final bool startsOpen;
  final VoidCallback? onClosed;

  @override
  Widget build(BuildContext context) {
    if (Motion.isReduced(context)) {
      return isOpen ? child : const SizedBox.shrink();
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: startsOpen ? 1 : 0, end: isOpen ? 1 : 0),
      duration: Motion.standard,
      curve: Motion.curve,
      onEnd: isOpen ? null : onClosed,
      builder: (context, t, child) => t == 0 && !isOpen
          ? const SizedBox.shrink()
          : ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: t,
                child: child,
              ),
            ),
      child: child,
    );
  }
}

/// A dashed hairline across the middle: a gap that takes a new row.
class _DottedLinePainter extends CustomPainter {
  _DottedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final middle = size.height / 2;
    final line = Path()
      ..moveTo(0, middle)
      ..lineTo(size.width, middle);
    canvas.drawPath(
      dashedPath(line, dash: 8, space: 6),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_DottedLinePainter old) => old.color != color;
}

/// A row being dragged: its toolbar — grip, "Row n", its split — and the
/// names of its cards, as wide as the board, lifted with a shadow.
class _LiftedRow extends StatelessWidget {
  const _LiftedRow({
    required this.width,
    required this.label,
    required this.split,
    required this.titles,
    required this.isMotionReduced,
  });

  final double width;
  final String label;
  final RowSplit split;
  final List<String> titles;
  final bool isMotionReduced;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // The same lift as a dragged card's.
    final lifted = Material(
      color: colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(Radii.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.md),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: SizedBox(
          width: width,
          height: arrangeCardHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.xs),
            child: Row(
              spacing: Space.xs,
              children: [
                Icon(Icons.drag_indicator, color: colors.onSurfaceVariant),
                Text(
                  label.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    letterSpacing: 0.8,
                  ),
                ),
                SplitDiagram(weights: split.weights),
                Expanded(
                  child: Text(
                    titles.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (isMotionReduced) return lifted;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 1.02),
      duration: Motion.quick,
      curve: Motion.curve,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: lifted,
    );
  }
}
