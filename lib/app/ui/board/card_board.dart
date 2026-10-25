import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/board/arrange_board.dart';
import 'package:personal_finance/app/ui/board/board_actions.dart';
import 'package:personal_finance/app/ui/board/board_labels.dart';
import 'package:personal_finance/app/ui/board/board_menu.dart';
import 'package:personal_finance/app/ui/breakpoints.dart';
import 'package:personal_finance/core/board/board_layout.dart';
import 'package:personal_finance/core/board/board_state.dart';
import 'package:personal_finance/core/board/board_storage.dart';

/// What a [CardBoard] shows now, for the screen around it: the [view] in
/// use, the [saved] state, the wide [layout] (null with the phone's list),
/// whether the board [isArranging], and the focus of the screen's layout
/// button, which gets it back when arrange mode ends.
@immutable
class BoardScene {
  const BoardScene({
    required this.view,
    required this.saved,
    required this.layout,
    required this.isArranging,
    required this.layoutButtonFocus,
  });

  final BoardView view;
  final BoardState saved;
  final BoardLayout? layout;
  final bool isArranging;
  final FocusNode layoutButtonFocus;
}

/// A screen's board of cards (docs/BOARD.md): the phone's ordered list below
/// 600 dp, else rows of columns folded to the [width] of the content — the
/// board's Auto layout or the person's own — and, while arranged, the board
/// in arrange mode. It keeps the arrange session: paused while two columns
/// do not fit, gone when the saved layout changes meanwhile, focus back on
/// the layout button when it ends.
///
/// [builder] lays the screen out around it: the header — [BoardScene] says
/// whether to show the screen's own (with a [BoardLayoutButton]) or the
/// arrange bar it is handed — and the board. [card] builds a card; [empty]
/// stands in when no card shows.
class CardBoard extends ConsumerStatefulWidget {
  const CardBoard({
    required this.def,
    required this.labels,
    required this.width,
    required this.card,
    required this.builder,
    super.key,
    this.empty,
    this.compactGap = 10,
  });

  final BoardDefinition def;
  final BoardLabels labels;

  /// The content width the board lays its columns out in.
  final double width;

  final Widget Function(BuildContext context, String id, BoardScene scene) card;

  final Widget Function(
    BuildContext context,
    BoardScene scene,
    Widget? arrangeBar,
    Widget board,
  )
  builder;

  final Widget Function(BuildContext context, BoardScene scene)? empty;

  /// The space between cards in the phone's list.
  final double compactGap;

  @override
  ConsumerState<CardBoard> createState() => _CardBoardState();
}

class _CardBoardState extends ConsumerState<CardBoard> {
  final _layoutButton = FocusNode(debugLabel: 'board layout');

  /// Whether an arrange session waits for a window wide enough (paused).
  var _isPaused = false;

  @override
  void dispose() {
    _layoutButton.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final def = widget.def;
    final view = WindowSize.of(context).isCompact
        ? BoardView.compact
        : BoardView.expanded;
    final saved =
        ref.watch(boardStateProvider((def, view))).value ?? BoardState(def);
    final session = ref.watch(arrangeSessionProvider(def));
    ref.listen(arrangeSessionProvider(def), (previous, next) {
      if (previous != null && next == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _layoutButton.requestFocus();
        });
      }
    });
    // A paused session whose saved layout changed meanwhile (a Layout pick,
    // an undo, another device) would resume on a stale base: it goes.
    ref.listen(boardStateProvider((def, BoardView.expanded)), (_, next) {
      final s = ref.read(arrangeSessionProvider(def));
      final value = next.value;
      if (s != null && _isPaused && value != null && value != s.before) {
        ref.read(arrangeSessionProvider(def).notifier).end();
      }
    });

    if (view == BoardView.compact) {
      _isPaused = session != null;
      final scene = BoardScene(
        view: view,
        saved: saved,
        layout: null,
        isArranging: false,
        layoutButtonFocus: _layoutButton,
      );
      final order = shownOrder(saved);
      final board = order.isEmpty
          ? widget.empty?.call(context, scene) ?? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: widget.compactGap,
              children: [
                for (final id in order)
                  KeyedSubtree(
                    key: ValueKey(id),
                    child: widget.card(context, id, scene),
                  ),
              ],
            );
      return widget.builder(context, scene, null, board);
    }

    final layout = wideLayout(saved, fittingColumns(widget.width));
    final arranging = session != null && layout.canArrange;
    _isPaused = session != null && !layout.canArrange;
    final scene = BoardScene(
      view: view,
      saved: saved,
      layout: layout,
      isArranging: arranging,
      layoutButtonFocus: _layoutButton,
    );
    if (arranging) {
      final notifier = ref.read(arrangeSessionProvider(def).notifier);
      return widget.builder(
        context,
        scene,
        BoardArrangeBar(
          def: def,
          labels: widget.labels,
          session: session,
          fits: layout.fits,
        ),
        ArrangeBoard(
          rows: session.rows,
          present: session.working.shown(BoardView.expanded).toSet(),
          fits: layout.fits,
          labels: widget.labels,
          onChanged: notifier.update,
          onRemove: notifier.remove,
        ),
      );
    }
    final board = layout.rows.isEmpty
        ? widget.empty?.call(context, scene) ?? const SizedBox.shrink()
        : BoardRowsView(
            layout: layout,
            width: widget.width,
            card: (id) => widget.card(context, id, scene),
          );
    return widget.builder(context, scene, null, board);
  }
}

/// A wide board as it shows: [layout]'s rows top to bottom, each split into
/// columns as wide as its weights make them in [width], cards stacked in
/// each column. A card keeps its state wherever it moves.
class BoardRowsView extends StatefulWidget {
  const BoardRowsView({
    required this.layout,
    required this.width,
    required this.card,
    super.key,
  });

  final BoardLayout layout;
  final double width;
  final Widget Function(String id) card;

  @override
  State<BoardRowsView> createState() => _BoardRowsViewState();
}

class _BoardRowsViewState extends State<BoardRowsView> {
  final _keys = <String, GlobalKey>{};

  @override
  Widget build(BuildContext context) {
    final shown = widget.layout.order.toSet();
    _keys.removeWhere((id, _) => !shown.contains(id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: boardGap,
      children: [
        for (final row in widget.layout.rows)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: boardGap,
            children: [
              for (final (c, width) in columnWidths(
                row.split,
                widget.width,
              ).indexed)
                SizedBox(
                  width: width,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: boardGap,
                    children: [
                      for (final id in row.columns[c])
                        KeyedSubtree(
                          key: _keys.putIfAbsent(
                            id,
                            () => GlobalKey(debugLabel: id),
                          ),
                          child: widget.card(id),
                        ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// The bar in place of a screen's header while its board is arranged:
/// "Arrange widgets · Drag to move", Add, Reset (the default rows inside the
/// session; disabled while they show), Cancel and Done.
class BoardArrangeBar extends ConsumerWidget {
  const BoardArrangeBar({
    required this.def,
    required this.labels,
    required this.session,
    required this.fits,
    super.key,
  });

  final BoardDefinition def;
  final BoardLabels labels;
  final ArrangeSession session;
  final int fits;

  /// The bar's width, at 1× text, from which the hint and the labels of
  /// Add widget and Reset show.
  static const double _roomyWidth = 900;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final notifier = ref.read(arrangeSessionProvider(def).notifier);
    final present = session.working.shown(BoardView.expanded);
    final defaults = wideLayout(
      session.working.copyWith(mode: LayoutMode.auto),
      fits,
    ).placed;
    final isDefault = listEquals(
      visibleRows(session.rows, present),
      visibleRows(defaults, present),
    );
    void addCard() => unawaited(
      showAddCards(
        context,
        labels: labels,
        view: BoardView.expanded,
        state: session.working,
        onAdd: (id) => notifier.add(id, fits),
      ),
    );
    final onReset = isDefault ? null : () => notifier.reset(fits);
    return Container(
      color: context.colors.surfaceContainerHigh,
      padding: const EdgeInsets.fromLTRB(
        Space.desktopGutter,
        14,
        Space.desktopGutter - Space.xxs,
        14,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Below this width at the text scale the hint goes and Add
          // and Reset keep only their icons; whatever still does not fit
          // wraps onto a second line rather than overflow.
          final roomy =
              constraints.maxWidth >=
              MediaQuery.textScalerOf(context).scale(_roomyWidth);
          return Wrap(
            spacing: Space.sm,
            runSpacing: Space.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                child: Text.rich(
                  TextSpan(
                    text: labels.arrangeTitle,
                    style: context.text.titleLarge,
                    children: [
                      if (roomy)
                        TextSpan(
                          text: '  ${l.boardArrangeHint}',
                          style: context.text.bodyMedium?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Wrap(
                spacing: Space.xs,
                runSpacing: Space.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (roomy) ...[
                    TextButton.icon(
                      onPressed: addCard,
                      icon: const Icon(Icons.add),
                      label: Text(labels.addTitle),
                    ),
                    TextButton.icon(
                      onPressed: onReset,
                      icon: const Icon(Icons.restart_alt),
                      label: Text(l.boardReset),
                    ),
                  ] else ...[
                    IconButton(
                      tooltip: labels.addTitle,
                      onPressed: addCard,
                      icon: const Icon(Icons.add),
                    ),
                    IconButton(
                      tooltip: l.boardReset,
                      onPressed: onReset,
                      icon: const Icon(Icons.restart_alt),
                    ),
                  ],
                  OutlinedButton(
                    onPressed: () => cancelArrange(context, ref, def),
                    child: Text(l.commonCancel),
                  ),
                  FilledButton(
                    onPressed: () =>
                        unawaited(finishArrange(context, ref, def)),
                    child: Text(l.commonDone),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
