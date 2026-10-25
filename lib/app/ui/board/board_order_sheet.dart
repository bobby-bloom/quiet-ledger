import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/board/board_actions.dart';
import 'package:personal_finance/app/ui/board/board_labels.dart';
import 'package:personal_finance/app/ui/board/board_menu.dart';
import 'package:personal_finance/core/board/board_layout.dart';
import 'package:personal_finance/core/board/board_state.dart';
import 'package:personal_finance/core/board/board_storage.dart';

/// Opens the one-column order of the board [def] (docs/BOARD.md, Phone):
/// the Layout choice Auto · Custom, one row per card with a grip, ▲ ▼ and
/// Remove, the cards not on the board with Add, and Done. Every change
/// applies at once and the board behind follows; Auto is the way back. It
/// is also the non-drag way to reorder (▲ ▼). [extras] adds the screen's
/// own controls under the Layout choice, for the cards shown.
Future<void> showBoardOrderSheet(
  BuildContext context, {
  required BoardDefinition def,
  required BoardLabels labels,
  Widget Function(List<String> shown)? extras,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => BoardOrderSheet(def: def, labels: labels, extras: extras),
);

class BoardOrderSheet extends ConsumerStatefulWidget {
  const BoardOrderSheet({
    required this.def,
    required this.labels,
    super.key,
    this.extras,
  });

  final BoardDefinition def;
  final BoardLabels labels;
  final Widget Function(List<String> shown)? extras;

  @override
  ConsumerState<BoardOrderSheet> createState() => _BoardOrderSheetState();
}

class _BoardOrderSheetState extends ConsumerState<BoardOrderSheet> {
  static const _view = BoardView.compact;

  /// The arrows of each row: focus stays on the pressed one, or moves to
  /// the other one when the widget reaches an end.
  final _up = <String, FocusNode>{};
  final _down = <String, FocusNode>{};

  @override
  void dispose() {
    for (final node in [..._up.values, ..._down.values]) {
      node.dispose();
    }
    super.dispose();
  }

  /// The custom order a move on Auto replaced, until Undo or the sheet
  /// closes: the sheet covers the board's toasts, so it offers its own.
  List<String>? _replaced;

  Future<void> _change(BoardState Function(BoardState current) change) =>
      ref.read(boardRepositoryProvider).update(widget.def, _view, change);

  /// Moves [id] to [position] among the cards shown and saves the order —
  /// from Auto, the default order with the move becomes the custom one, and
  /// a custom order saved before can come back with Undo. Hidden cards keep
  /// their place.
  Future<void> _move(String id, int position) async {
    final l = context.l10n;
    final view = View.of(context);
    final direction = Directionality.of(context);
    List<String>? replaced;
    var count = 0;
    var to = -1;
    final (_, after) = await ref.read(boardRepositoryProvider).update(
      widget.def,
      _view,
      (s) {
        final shown = shownOrder(s);
        final from = shown.indexOf(id);
        to = position.clamp(0, shown.length - 1);
        count = shown.length;
        if (from < 0 || from == to) return s;
        if (s.mode == LayoutMode.auto && s.order != null) replaced = s.order;
        // Normalized first: a card that shows on Auto without an entry
        // stays shown on Custom.
        return s
            .normalized(_view)
            .copyWith(
              mode: LayoutMode.custom,
              order: moveInOrder(placedOrder(s), shown, id, to),
            );
      },
    );
    if (!mounted || to < 0) return;
    final saved = replaced;
    if (saved != null &&
        !const ListEquality<String>().equals(saved, after.order)) {
      setState(() => _replaced = saved);
    }
    unawaited(
      SemanticsService.sendAnnouncement(
        view,
        l.boardMovedTo(widget.labels.cardName(id), to + 1, count),
        direction,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final labels = widget.labels;
    final state =
        ref.watch(boardStateProvider((widget.def, _view))).value ??
        BoardState(widget.def);
    final shown = shownOrder(state);
    final hidden = [
      for (final id in widget.def.cards)
        if (!state.shows(_view, id)) id,
    ];
    final roomy = MediaQuery.textScalerOf(context).scale(1) < 1.5;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: CustomScrollView(
        shrinkWrap: true,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.xs),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: Space.xxs,
                children: [
                  Text(labels.orderTitle, style: context.text.titleLarge),
                  Text(
                    l.boardSheetSubtitle,
                    style: context.text.bodyMedium?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Space.sm),
                  _OrderLayoutChoice(
                    state: state,
                    labels: labels,
                    onMode: (mode) => unawaited(
                      _change(
                        (s) =>
                            (mode == LayoutMode.custom
                                    ? s.normalized(_view)
                                    : s)
                                .copyWith(mode: mode),
                      ),
                    ),
                  ),
                  if (_replaced case final replaced?)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l.boardOrderReplaced,
                            style: context.text.bodySmall,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() => _replaced = null);
                            unawaited(
                              _change(
                                // Back to Auto with the saved order, as
                                // before the move.
                                (s) => s.copyWith(
                                  mode: LayoutMode.auto,
                                  order: replaced,
                                ),
                              ),
                            );
                          },
                          child: Text(l.commonUndo),
                        ),
                      ],
                    ),
                  ?widget.extras?.call(shown),
                ],
              ),
            ),
          ),
          SliverReorderableList(
            itemCount: shown.length,
            onReorderItem: (from, to) => unawaited(_move(shown[from], to)),
            itemBuilder: (context, i) {
              final t = shown[i];
              final name = labels.cardName(t);
              final arrows = [
                IconButton(
                  focusNode: _up.putIfAbsent(t, FocusNode.new),
                  tooltip: l.boardMoveUpCard(name),
                  icon: const Icon(Icons.arrow_upward),
                  onPressed: i == 0
                      ? null
                      : () {
                          unawaited(_move(t, i - 1));
                          if (i - 1 == 0) _down[t]?.requestFocus();
                        },
                ),
                IconButton(
                  focusNode: _down.putIfAbsent(t, FocusNode.new),
                  tooltip: l.boardMoveDownCard(name),
                  icon: const Icon(Icons.arrow_downward),
                  onPressed: i == shown.length - 1
                      ? null
                      : () {
                          unawaited(_move(t, i + 1));
                          if (i + 1 == shown.length - 1) {
                            _up[t]?.requestFocus();
                          }
                        },
                ),
                IconButton(
                  tooltip: l.boardRemoveCard(name),
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => unawaited(
                    _change((s) => s.withVisible(_view, t, visible: false)),
                  ),
                ),
              ];
              return Material(
                key: ValueKey(t),
                type: MaterialType.transparency,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.xs),
                  child: Row(
                    crossAxisAlignment: roomy
                        ? CrossAxisAlignment.center
                        : CrossAxisAlignment.start,
                    children: [
                      ReorderableDragStartListener(
                        index: i,
                        child: const Padding(
                          padding: EdgeInsets.all(Space.sm),
                          child: Icon(Icons.drag_indicator),
                        ),
                      ),
                      Icon(
                        labels.cardIcon(t),
                        color: context.colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: roomy
                            ? Text(name, style: context.text.titleSmall)
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: Space.sm,
                                    ),
                                    child: Text(
                                      name,
                                      style: context.text.titleSmall,
                                    ),
                                  ),
                                  // At large text the buttons wrap under
                                  // the name.
                                  Wrap(children: arrows),
                                ],
                              ),
                      ),
                      if (roomy) ...arrows,
                    ],
                  ),
                ),
              );
            },
          ),
          if (hidden.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.lg,
                  Space.md,
                  Space.lg,
                  Space.xxs,
                ),
                child: Text(
                  labels.notOnBoard,
                  style: context.text.labelLarge?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          SliverList.list(
            children: [
              for (final t in hidden)
                ListTile(
                  leading: Icon(labels.cardIcon(t)),
                  title: Row(
                    spacing: Space.xs,
                    children: [
                      Flexible(child: Text(labels.cardTitle(t))),
                      if (state.isNew(_view, t)) const NewBadge(),
                    ],
                  ),
                  subtitle: Text(labels.cardDescription(t)),
                  trailing: TextButton.icon(
                    onPressed: () =>
                        unawaited(addCard(ref, widget.def, _view, t)),
                    icon: const Icon(Icons.add),
                    label: Text(l.commonAdd),
                  ),
                ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(Space.md),
            sliver: SliverToBoxAdapter(
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l.commonDone),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Auto · Custom for the one-column order (Custom only while one is
/// saved) and the line saying whose order shows.
class _OrderLayoutChoice extends StatelessWidget {
  const _OrderLayoutChoice({
    required this.state,
    required this.labels,
    required this.onMode,
  });

  final BoardState state;
  final BoardLabels labels;
  final ValueChanged<LayoutMode> onMode;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final mode = state.order == null ? LayoutMode.auto : state.mode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: Space.xxs,
      children: [
        ExcludeSemantics(
          child: Text(l.boardLabel, style: context.text.labelLarge),
        ),
        SegmentedButton<LayoutMode>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: LayoutMode.auto, label: Text(l.boardAuto)),
            if (state.order != null)
              ButtonSegment(
                value: LayoutMode.custom,
                label: Text(l.boardCustom),
              ),
          ],
          selected: {mode},
          onSelectionChanged: (picked) => onMode(picked.first),
        ),
        Text(
          mode == LayoutMode.custom
              ? labels.orderCustomHint
              : labels.orderAutoHint,
          style: context.text.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
