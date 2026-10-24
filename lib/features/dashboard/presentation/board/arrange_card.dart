import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/features/dashboard/domain/arrange.dart';
import 'package:personal_finance/features/dashboard/presentation/board/drop_slot.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

/// A widget in arrange mode: a 52 dp row with a grip, the widget's [icon]
/// and [title], and ⋮ for the [MoveCardMenu]. The whole row is the drag
/// handle, immediate for mouse and touch — the grip is only the cue; ⋮ is
/// the one thing on it that taps.
///
/// For a screen reader the card is one node named [positionLabel], with the
/// [moves] that apply as custom actions.
class ArrangeCard extends StatefulWidget {
  const ArrangeCard({
    required this.id,
    required this.icon,
    required this.title,
    required this.positionLabel,
    required this.moves,
    required this.onMove,
    required this.onRemove,
    required this.focusNode,
    super.key,
    this.canLift,
    this.onDragStarted,
    this.onDragMoved,
    this.onDragEnded,
  });

  /// The widget id, the drag's data.
  final String id;
  final IconData icon;
  final String title;

  /// Where the widget is, e.g. "Goals: row 2, column 1, position 1 of 2".
  final String positionLabel;

  /// The moves that apply where the widget is now.
  final Set<CardMove> moves;
  final ValueChanged<CardMove> onMove;

  /// Takes the widget off the dashboard (inside the arrange session).
  final VoidCallback onRemove;

  /// The ⋮ button's focus, owned by the board: focus follows a moved card.
  final FocusNode focusNode;

  /// Whether the card may be lifted now — one drag at a time. Asked as the
  /// card builds and again the moment a drag would start.
  final bool Function()? canLift;

  /// Called as a drag starts with where the pointer is now, global.
  final ValueChanged<Offset>? onDragStarted;

  /// Called with the dragging pointer's global position as it moves.
  final ValueChanged<Offset>? onDragMoved;

  /// Called when the drag ends with where the lifted copy was (its global
  /// top left), and whether the system took the pointer away.
  final void Function(Offset from, {required bool isCancelled})? onDragEnded;

  @override
  State<ArrangeCard> createState() => _ArrangeCardState();
}

class _ArrangeCardState extends State<ArrangeCard> {
  int? _lastPointer;
  Offset _lastPosition = Offset.zero;
  int? _dragPointer;
  var _isCancelled = false;

  /// Whether the lifted copy shows: from a drag's start until the card
  /// leaves the board mid-drag.
  final ValueNotifier<bool> _isLifted = ValueNotifier(false);

  @override
  void dispose() {
    // Takes the lifted copy along — after the frame, as the tree is locked
    // now; the copy listens until its pointer lets go.
    final isLifted = _isLifted;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => isLifted
        ..value = false
        ..dispose(),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final face = _ArrangeCardFace(
      icon: widget.icon,
      title: widget.title,
      trailing: MoveCardMenu(
        title: widget.title,
        moves: widget.moves,
        onMove: widget.onMove,
        onRemove: widget.onRemove,
        focusNode: widget.focusNode,
      ),
    );

    return Semantics(
      container: true,
      label: widget.positionLabel,
      customSemanticsActions: {
        for (final (move, _, label) in cardMoveItems(
          l,
          Directionality.of(context),
        ))
          if (widget.moves.contains(move))
            CustomSemanticsAction(label: label): () => widget.onMove(move),
        CustomSemanticsAction(label: l.dashLayoutRemoveFromDashboard):
            widget.onRemove,
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The feedback lives in the overlay, outside this theme scope.
          final theme = Theme.of(context);
          return Listener(
            onPointerDown: _heard,
            onPointerMove: _heard,
            onPointerCancel: (e) => _isCancelled |= e.pointer == _dragPointer,
            child: _GatedDraggable(
              canStart: _canLift,
              data: widget.id,
              maxSimultaneousDrags: _canLift() ? 1 : 0,
              onDragStarted: _started,
              onDragEnd: _ended,
              feedback: ValueListenableBuilder(
                valueListenable: _isLifted,
                builder: (context, isLifted, lifted) =>
                    isLifted ? lifted! : const SizedBox.shrink(),
                child: Theme(
                  data: theme,
                  child: SizedBox(
                    width: constraints.maxWidth,
                    child: _LiftedCard(
                      child: _ArrangeCardFace(
                        icon: widget.icon,
                        title: widget.title,
                        isLifted: true,
                      ),
                    ),
                  ),
                ),
              ),
              childWhenDragging: const SizedBox.shrink(),
              child: face,
            ),
          );
        },
      ),
    );
  }

  bool _canLift() => mounted && (widget.canLift?.call() ?? true);

  void _heard(PointerEvent event) {
    _lastPointer = event.pointer;
    _lastPosition = event.position;
    if (mounted && event is PointerMoveEvent && event.pointer == _dragPointer) {
      widget.onDragMoved?.call(event.position);
    }
  }

  void _started() {
    _dragPointer = _lastPointer;
    _isCancelled = false;
    _isLifted.value = true;
    widget.onDragStarted?.call(_lastPosition);
  }

  void _ended(DraggableDetails details) {
    final isCancelled = _isCancelled;
    _dragPointer = null;
    _isCancelled = false;
    widget.onDragEnded?.call(details.offset, isCancelled: isCancelled);
  }
}

/// A [Draggable] that asks [canStart] the moment a drag would start: a
/// refused drag never lifts.
class _GatedDraggable extends Draggable<String> {
  const _GatedDraggable({
    required this.canStart,
    required super.feedback,
    required super.child,
    super.data,
    super.maxSimultaneousDrags,
    super.onDragStarted,
    super.onDragEnd,
    super.childWhenDragging,
  });

  final bool Function() canStart;

  @override
  MultiDragGestureRecognizer createRecognizer(
    GestureMultiDragStartCallback onStart,
  ) => super.createRecognizer((p) => canStart() ? onStart(p) : null);
}

/// The ⋮ button of an [ArrangeCard] and its menu: Up, Down, One column
/// left, One column right and, set apart, Remove from dashboard, titled
/// `Move "{widget}"`. Moves that cannot apply are disabled.
class MoveCardMenu extends StatelessWidget {
  const MoveCardMenu({
    required this.title,
    required this.moves,
    required this.onMove,
    required this.onRemove,
    required this.focusNode,
    super.key,
  });

  final String title;
  final Set<CardMove> moves;
  final ValueChanged<CardMove> onMove;
  final VoidCallback onRemove;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return MenuAnchor(
      menuChildren: [
        // The button already says it; the title is for the eye.
        ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.sm,
              Space.xs,
              Space.sm,
              Space.xxs,
            ),
            child: Text(
              l.dashLayoutMove(title),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        for (final (move, icon, label) in cardMoveItems(
          l,
          Directionality.of(context),
        ))
          MenuItemButton(
            leadingIcon: Icon(icon),
            onPressed: moves.contains(move) ? () => onMove(move) : null,
            child: Text(label),
          ),
        const Divider(),
        MenuItemButton(
          leadingIcon: const Icon(Icons.remove_circle_outline),
          onPressed: onRemove,
          child: Text(l.dashLayoutRemoveFromDashboard),
        ),
      ],
      builder: (context, controller, _) => IconButton(
        focusNode: focusNode,
        tooltip: l.dashLayoutMove(title),
        icon: const Icon(Icons.more_vert),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

/// The Move menu's items in order with their icon and label. Left and right
/// are what the eye sees: in right-to-left text, left is [CardMove.end].
List<(CardMove, IconData, String)> cardMoveItems(
  AppLocalizations l,
  TextDirection direction,
) {
  final isRtl = direction == TextDirection.rtl;
  return [
    (CardMove.up, Icons.arrow_upward, l.dashLayoutMoveUp),
    (CardMove.down, Icons.arrow_downward, l.dashLayoutMoveDown),
    (
      isRtl ? CardMove.end : CardMove.start,
      Icons.arrow_back,
      l.dashLayoutMoveLeft,
    ),
    (
      isRtl ? CardMove.start : CardMove.end,
      Icons.arrow_forward,
      l.dashLayoutMoveRight,
    ),
  ];
}

/// What an [ArrangeCard] looks like: grip, icon, title, [trailing].
class _ArrangeCardFace extends StatelessWidget {
  const _ArrangeCardFace({
    required this.icon,
    required this.title,
    this.trailing,
    this.isLifted = false,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;
  final bool isLifted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: isLifted
          ? colors.surfaceContainerHigh
          : colors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: SizedBox(
        height: arrangeCardHeight,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: Space.xxs,
            end: Space.xxs,
          ),
          child: Row(
            spacing: Space.xs,
            children: [
              ExcludeSemantics(
                child: SizedBox(
                  width: 28,
                  child: Icon(
                    Icons.drag_indicator,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              ExcludeSemantics(
                child: Icon(icon, size: 20, color: colors.onSurfaceVariant),
              ),
              Expanded(
                child: ExcludeSemantics(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ),
              // Keeps the lifted copy as wide as the card it lifts.
              trailing ??
                  const SizedBox.square(dimension: kMinInteractiveDimension),
            ],
          ),
        ),
      ),
    );
  }
}

/// The lift of a dragged card: a raised shadow, a 1.02 scale and a slight
/// tilt, coming in on [Motion.quick]. Reduced motion lifts with the shadow.
class _LiftedCard extends StatelessWidget {
  const _LiftedCard({required this.child});

  final Widget child;

  static const _scale = 1.02;
  static const double _tilt = -1.2 * math.pi / 180;

  @override
  Widget build(BuildContext context) {
    final lifted = DecoratedBox(
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
      child: child,
    );
    if (Motion.isReduced(context)) return lifted;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.quick,
      curve: Motion.curve,
      builder: (context, t, child) => Transform.rotate(
        angle: _tilt * t,
        child: Transform.scale(scale: 1 + (_scale - 1) * t, child: child),
      ),
      child: lifted,
    );
  }
}
