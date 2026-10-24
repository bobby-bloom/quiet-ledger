import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';

/// One action revealed behind a swiped row.
class SwipeAction {
  const SwipeAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.background,
    this.foreground,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? background;
  final Color? foreground;
}

/// Touch swipe actions for list rows: swiping right reveals [start]
/// actions, swiping left reveals [end] actions. A long swipe runs the
/// outermost action directly (first of [start], last of [end]). The actions
/// are also exposed as semantic custom actions for screen readers.
class SwipeActions extends StatefulWidget {
  const SwipeActions({
    required this.child,
    super.key,
    this.start = const [],
    this.end = const [],
    this.enabled = true,
    this.actionWidth = 76,
  });

  final Widget child;
  final List<SwipeAction> start;
  final List<SwipeAction> end;
  final bool enabled;
  final double actionWidth;

  @override
  State<SwipeActions> createState() => _SwipeActionsState();
}

class _SwipeActionsState extends State<SwipeActions>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  )..addListener(() => setState(() => _dx = _anim?.value ?? _dx));
  Animation<double>? _anim;
  double _dx = 0;
  double _width = 0;

  double get _maxStart => widget.start.length * widget.actionWidth;
  double get _maxEnd => widget.end.length * widget.actionWidth;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    _anim = Tween<double>(
      begin: _dx,
      end: target,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl
      ..reset()
      ..forward();
  }

  void _close() => _animateTo(0);

  void _onUpdate(DragUpdateDetails d) {
    _ctrl.stop();
    final next = _dx + d.delta.dx;
    final hasStart = widget.start.isNotEmpty;
    final hasEnd = widget.end.isNotEmpty;
    setState(() {
      _dx = next.clamp(hasEnd ? -_width : 0.0, hasStart ? _width : 0.0);
    });
  }

  void _onEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    final full = _width * 0.6;
    if (_dx > full && widget.start.isNotEmpty) {
      _close();
      widget.start.first.onTap();
      return;
    }
    if (_dx < -full && widget.end.isNotEmpty) {
      _close();
      widget.end.last.onTap();
      return;
    }
    if (_dx > 0) {
      _animateTo(_dx > _maxStart / 2 || v > 600 ? _maxStart : 0);
    } else if (_dx < 0) {
      _animateTo(-_dx > _maxEnd / 2 || v < -600 ? -_maxEnd : 0);
    }
  }

  Widget _panel(List<SwipeAction> actions, {required bool start}) {
    final cs = context.colors;
    final revealed = start ? math.max(0, _dx) : math.max(0, -_dx);
    final each = actions.isEmpty ? 0.0 : revealed / actions.length;
    return Row(
      mainAxisAlignment: start
          ? MainAxisAlignment.start
          : MainAxisAlignment.end,
      children: [
        for (final a in actions)
          SizedBox(
            width: math.max(each, 0),
            child: Material(
              color: a.background ?? cs.secondaryContainer,
              child: InkWell(
                onTap: () {
                  _close();
                  a.onTap();
                },
                child: ClipRect(
                  child: OverflowBox(
                    maxWidth: widget.actionWidth,
                    minWidth: widget.actionWidth,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          a.icon,
                          color: a.foreground ?? cs.onSecondaryContainer,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          a.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.labelSmall?.copyWith(
                            color: a.foreground ?? cs.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final semantics = {
      for (final a in [...widget.start, ...widget.end])
        CustomSemanticsAction(label: a.label): a.onTap,
    };
    if (!widget.enabled) {
      return Semantics(customSemanticsActions: semantics, child: widget.child);
    }
    return Semantics(
      customSemanticsActions: semantics,
      child: LayoutBuilder(
        builder: (context, box) {
          _width = box.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragUpdate: _onUpdate,
            onHorizontalDragEnd: _onEnd,
            child: Stack(
              children: [
                if (_dx != 0)
                  Positioned.fill(
                    child: _dx > 0
                        ? _panel(widget.start, start: true)
                        : _panel(widget.end, start: false),
                  ),
                Transform.translate(
                  offset: Offset(_dx, 0),
                  child: _dx == 0
                      ? widget.child
                      : GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _close,
                          child: AbsorbPointer(child: widget.child),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
