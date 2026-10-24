import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FlutterView, lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/features/dashboard/domain/arrange.dart';
import 'package:personal_finance/features/dashboard/domain/board_layout.dart';
import 'package:personal_finance/features/dashboard/presentation/board/arrange_card.dart';
import 'package:personal_finance/features/dashboard/presentation/board/drop_slot.dart';
import 'package:personal_finance/features/dashboard/presentation/board/row_band.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

/// The least height a "New row" target takes while a widget is dragged, a
/// fingertip and some: what a gap lacks of it comes from the top edge of
/// the band below it.
const double _newRowReach = 32;

/// The dashboard in arrange mode (docs/DASHBOARD.md, Arrange mode): the
/// working [rows] as [RowBand]s with their toolbars, every widget present as
/// an [ArrangeCard], a [DropSlot] where a dragged one would land, "Drag a
/// widget here" in empty columns, a "New row" slot in the gaps above,
/// between and below the rows, and "Add row" under the last.
///
/// Where a dragged widget would land follows the pointer, also while the
/// board scrolls (a wheel) under it, and only where the board shows. There
/// is no auto-scroll: the arranged board is short, and the Move menu is the
/// way when it is not.
///
/// Every change — a drop, a Move, a row edit — goes to [onChanged] as new
/// rows; the session keeps them until Done or Cancel. Focus starts on the
/// first widget and follows a moved widget or row; each move is announced.
class ArrangeBoard extends StatefulWidget {
  const ArrangeBoard({
    required this.rows,
    required this.present,
    required this.fits,
    required this.title,
    required this.icon,
    required this.onChanged,
    required this.onRemove,
    super.key,
    this.gap = boardGap,
  });

  /// The working arrangement: placed rows, hidden widgets in their slots.
  final List<BoardRow> rows;

  /// The widgets that show.
  final Set<String> present;

  /// How many columns fit; wider rows show squeezed.
  final int fits;

  final double gap;
  final String Function(String id) title;
  final IconData Function(String id) icon;
  final ValueChanged<List<BoardRow>> onChanged;

  /// Takes a widget off the dashboard, inside the session.
  final ValueChanged<String> onRemove;

  @override
  State<ArrangeBoard> createState() => _ArrangeBoardState();
}

class _ArrangeBoardState extends State<ArrangeBoard> {
  static const double _bandPadding = RowBand.padding;

  /// One key per widget: it keeps its menu and focus wherever it moves, and
  /// a drag measures the widgets it passes.
  final _keys = <String, GlobalKey>{};

  /// The ⋮ button of each widget, and of each row by its place.
  final _focusNodes = <String, FocusNode>{};
  final _rowFocusNodes = <FocusNode>[];

  /// The row whose split was just picked, until the frame that shows it:
  /// only its columns glide to their new widths.
  int? _resplit;

  /// The widget being dragged and the pointer's last global position.
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

  /// Where the dragged widget would land now.
  ArrangeTarget? _target;

  /// Whether the slot is still the lifted widget's own place, open from the
  /// start at full height, so nothing moves as it lifts.
  var _isLiftedInPlace = false;

  /// The slots the dragged widget left, closing as the new one opens, so
  /// what lies under the pointer stays put. Only while a drag runs.
  final _closing = <ArrangeTarget>{};

  /// The widget settling into its place after a drop, and where its lifted
  /// copy was let go — until its glide starts.
  String? _settling;
  Offset? _settleFrom;

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

    // The held widget left the board: its drag will never end on its own,
    // so it ends here, dropped.
    final dragging = _dragging;
    if (dragging != null && !_isShown(dragging)) {
      _dragging = null;
      _target = null;
      _closing.clear();
      _pointer = null;
      _announce(_l.dashLayoutDropped(widget.title(dragging)));
    }
  }

  @override
  void dispose() {
    // The board went mid-drag (arrange mode paused or ended): the widget
    // stays where it was.
    if (_dragging case final dragging?) {
      _announce(_l.dashLayoutDropped(widget.title(dragging)));
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, row) in rows.indexed) ...[
          _gap(NewRowTarget(index)),
          _band(index, row),
        ],
        _gap(NewRowTarget(rows.length)),
        // Dropped here, a widget goes below the last row.
        _DropArea(
          targetAt: (_) => NewRowTarget(rows.length),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.tonalIcon(
              onPressed: () => widget.onChanged(addRow(rows, widget.fits)),
              icon: const Icon(Icons.add),
              label: Text(_l.dashLayoutAddRow),
            ),
          ),
        ),
      ],
    );
  }

  Widget _gap(NewRowTarget target) => _NewRowGap(
    target: target,
    current: _target,
    isClosing: _closing.contains(target),
    onClosed: () => _closed(target),
    isDragging: _dragging != null,
    height: widget.gap,
    label: _l.dashLayoutNewRow,
  );

  /// [row] as a dashed band of its shown columns and one drop area: the
  /// pointer picks the column under it and the place between its widgets —
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
          child: RowBand(
            index: index,
            count: widget.rows.length,
            row: row,
            fits: widget.fits,
            menuFocusNode: _rowFocusNode(index),
            onSplit: (split) {
              _resplit = index;
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _resplit = null,
              );
              _editRows(changeSplit(widget.rows, index, split));
            },
            onMoveUp: index > 0
                ? () => _editRows(moveRow(widget.rows, index), focus: index - 1)
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

  /// Where a widget held at [pointer] lands in the band [band] of [row].
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

  /// The widgets [ids] of one shown column: the slot opens where the dragged
  /// one would land, slots it left close, and the dragged one leaves its
  /// place. A slot carries its gap to the next widget.
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
    Widget slot(ArrangeTarget target, EdgeInsets padding) => _GrowIn(
      key: ValueKey(target),
      isOpen: target == _target,
      startsOpen: _isLiftedInPlace && target == _target,
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
      // An empty column shows the slot in place of "Drag a widget here".
      final open = indexOf(_target);
      children.add(
        open != null
            ? slot(_target!, EdgeInsets.zero)
            : DropSlot(
                kind: DropSlotKind.emptyColumn,
                label: _l.dashLayoutEmptyColumn,
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
      icon: widget.icon(id),
      title: widget.title(id),
      positionLabel: _positionLabel(id, position),
      moves: possibleMoves(
        rows,
        id,
        present: widget.present,
        fits: widget.fits,
      ),
      onMove: (move) => _move(id, move),
      onRemove: () => _remove(id),
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

  /// One drag at a time, asked also the moment a drag would start.
  bool _canLift() => mounted && _dragging == null;

  bool _isShown(String id) =>
      widget.present.contains(id) &&
      widget.rows.any((row) => row.cardIds.contains(id));

  /// [id] is lifted at [pointer]. The slot opens in its own place at full
  /// height, so nothing moves and a widget let go without moving stays.
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
    _announce(_l.dashLayoutPickedUp(widget.title(id)));
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
      if (_dragging == null || board is! RenderBox || !board.attached) return;
      final origin = board.localToGlobal(Offset.zero);
      if (origin != _boardOrigin || _isLayoutChanged) {
        _boardOrigin = origin;
        _isLayoutChanged = false;
        _retarget();
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
  /// a column only among other widgets.
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
    _announce(_l.dashLayoutDropped(widget.title(id)));
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
      _announce(_l.dashLayoutDropped(widget.title(id)));
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

  /// Takes [id] off the board, says so, and puts focus on the widget that
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
    _announce(_l.dashLayoutRemoved(widget.title(id)));
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

  String _positionLabel(String id, ArrangePosition p) => _l.dashLayoutMoved(
    widget.title(id),
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
/// the dragged widget hovers it, closing again once it moves on.
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

/// A part of the board a dragged widget can be let go over: all of
/// [child]'s box, by a hit test, and where in it the widget would land for
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
