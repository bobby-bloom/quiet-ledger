import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/ui/board/board_labels.dart';
import 'package:personal_finance/core/board/board_layout.dart';
import 'package:personal_finance/core/board/board_state.dart';
import 'package:personal_finance/core/board/board_storage.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

// What a board's controls do to its saved views (docs/BOARD.md): every
// change is one update of the whole view, and the ones that replace
// something offer Undo, which puts back only what they changed.

/// The Undo toast of a layout change, taken before the change is awaited:
/// the control that started it (the arrange bar, a menu) may be gone by the
/// time the write is done, the app's messenger is not.
class BoardUndo {
  BoardUndo.of(BuildContext context, WidgetRef ref, this.def)
    : l = context.l10n,
      _messenger = ScaffoldMessenger.maybeOf(context),
      _repo = ref.read(boardRepositoryProvider);

  final BoardDefinition def;
  final AppLocalizations l;
  final ScaffoldMessengerState? _messenger;
  final BoardRepository _repo;

  /// Shows [message] with Undo, which changes [view] by [undo]: each Undo
  /// puts back only what its action changed, on the state as it is then.
  void show(
    String message,
    BoardView view,
    BoardState Function(BoardState current) undo,
  ) {
    final messenger = _messenger;
    if (messenger == null || !messenger.mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: l.commonUndo,
            onPressed: () => unawaited(_repo.update(def, view, undo)),
          ),
        ),
      );
  }
}

/// The wide layout of [state] where [fits] columns fit.
BoardLayout wideLayout(BoardState state, int fits) => resolveBoardLayout(
  mode: state.mode,
  saved: state.rows,
  defaultRows: state.def.defaultRows(fits),
  present: state.shown(BoardView.expanded),
  fits: fits,
);

/// The one-column order with every id placed, hidden ones in their slots:
/// the saved order on Custom, else the default.
List<String> placedOrder(BoardState state) {
  final def = state.def;
  final base = state.mode == LayoutMode.custom && state.order != null
      ? state.order!
      : def.defaultOrder;
  return placeNewCardsInOrder(
    base,
    state.shown(BoardView.compact),
    def.defaultOrder,
  );
}

/// The cards the one-column board shows, in order.
List<String> shownOrder(BoardState state) {
  final present = state.shown(BoardView.compact).toSet();
  return [
    for (final id in placedOrder(state))
      if (present.contains(id)) id,
  ];
}

/// Takes [id] off [view] (its slot and options kept), with Undo.
Future<void> removeCard(
  BuildContext context,
  WidgetRef ref,
  BoardDefinition def,
  BoardLabels labels,
  BoardView view,
  String id,
) async {
  final undo = BoardUndo.of(context, ref, def);
  await ref
      .read(boardRepositoryProvider)
      .update(def, view, (s) => s.withVisible(view, id, visible: false));
  undo.show(
    undo.l.boardRemoved(labels.cardTitle(id)),
    view,
    (s) => s.withVisible(view, id, visible: true),
  );
}

/// Puts [id] back on [view]: into its kept slot, else after its nearest
/// default neighbour.
Future<void> addCard(
  WidgetRef ref,
  BoardDefinition def,
  BoardView view,
  String id,
) => ref
    .read(boardRepositoryProvider)
    .update(def, view, (s) => s.withVisible(view, id, visible: true));

/// Replaces [id]'s options in [view].
Future<void> setCardOptions(
  WidgetRef ref,
  BoardDefinition def,
  BoardView view,
  String id,
  Map<String, Object?> options,
) => ref
    .read(boardRepositoryProvider)
    .update(def, view, (s) => s.withOptions(view, id, options));

/// The Layout control's pick on the wide board. Auto and Custom switch the
/// mode (the saved rows stay); a number restores a saved layout of that many
/// equal columns, or deals the cards on screen into one — hidden cards keep
/// a slot after their neighbour — with Undo when that replaces a different
/// saved layout.
Future<void> pickLayout(
  BuildContext context,
  WidgetRef ref,
  BoardDefinition def,
  LayoutSegment segment,
  BoardLayout layout,
) async {
  const view = BoardView.expanded;
  final undo = BoardUndo.of(context, ref, def);
  final columns = segment.columns;
  final (before, after) = await ref.read(boardRepositoryProvider).update(
    def,
    view,
    (s) {
      if (columns == null) {
        if (segment == LayoutSegment.auto) {
          return s.copyWith(mode: LayoutMode.auto);
        }
        if (s.rows == null) return s;
        // Entries written as things show now, so a card that shows on Auto
        // without one (shipped after the last save) stays shown on Custom.
        return s.normalized(view).copyWith(mode: LayoutMode.custom);
      }
      if (equalRowColumns(s.rows) == columns) {
        return s.normalized(view).copyWith(mode: LayoutMode.custom);
      }
      // From the state as it is now, not as the menu last drew it.
      final now = wideLayout(s, layout.fits);
      final placed = [for (final r in now.placed) ...r.cardIds];
      final dealt = dealRow(now.order, columns);
      return s
          .normalized(view)
          .copyWith(
            mode: LayoutMode.custom,
            rows: placeNewCards([dealt], placed, placed),
          );
    },
  );
  if (columns != null &&
      before.rows != null &&
      !const ListEquality<BoardRow>().equals(before.rows, after.rows)) {
    undo.show(
      undo.l.boardFlattened(columns),
      view,
      (s) => s.withArrangementOf(before),
    );
  }
}

/// Auto with the default cards, options and saved arrangements kept, with
/// Undo: an empty board's way back.
Future<void> resetToDefault(
  BuildContext context,
  WidgetRef ref,
  BoardDefinition def,
  BoardLabels labels,
  BoardView view,
) async {
  final undo = BoardUndo.of(context, ref, def);
  final (before, _) = await ref
      .read(boardRepositoryProvider)
      .update(
        def,
        view,
        (s) => s
            .withVisibilityOf(view, BoardState(def))
            .copyWith(mode: LayoutMode.auto),
      );
  undo.show(
    labels.resetDone,
    view,
    (s) => s.withVisibilityOf(view, before).copyWith(mode: before.mode),
  );
}

/// An arrange session on a wide board: the saved state when it began
/// ([before]), the rows it started from ([start]) and the work so far
/// ([working]: rows, and cards removed or added inside the session).
@immutable
class ArrangeSession {
  const ArrangeSession({
    required this.before,
    required this.start,
    required this.working,
  });

  final BoardState before;
  final List<BoardRow> start;
  final BoardState working;

  List<BoardRow> get rows => working.rows ?? start;

  bool get hasChanges =>
      !listEquals(rows, start) ||
      !mapEquals(
        working.normalized(BoardView.expanded).items,
        before.normalized(BoardView.expanded).items,
      );

  ArrangeSession copyWith(BoardState working) =>
      ArrangeSession(before: before, start: start, working: working);
}

/// The running arrange session of the board [def], or null. Kept while the
/// window is too narrow to arrange (paused): the board shows normally and
/// the session resumes once two columns fit again.
class ArrangeSessionNotifier extends Notifier<ArrangeSession?> {
  ArrangeSessionNotifier(this.def);

  final BoardDefinition def;

  @override
  ArrangeSession? build() => null;

  /// Starts arranging [saved] from the rows on screen, [seed].
  void enter(BoardState saved, List<BoardRow> seed) => state = ArrangeSession(
    before: saved,
    start: seed,
    working: saved.copyWith(rows: seed),
  );

  /// Puts back a session Cancel discarded.
  // A setter would read as assigning the session, not as putting one back.
  // ignore: use_setters_to_change_properties
  void restore(ArrangeSession session) => state = session;

  void update(List<BoardRow> rows) =>
      state = state?.copyWith(state!.working.copyWith(rows: rows));

  /// Takes [id] off the board inside the session; it keeps its slot.
  void remove(String id) {
    final s = state;
    if (s == null) return;
    state = s.copyWith(
      s.working.withVisible(BoardView.expanded, id, visible: false),
    );
  }

  /// Adds [id] inside the session: into its kept slot, else after its
  /// nearest default neighbour.
  void add(String id, int fits) {
    final s = state;
    if (s == null) return;
    final working = s.working.withVisible(
      BoardView.expanded,
      id,
      visible: true,
    );
    final present = working.shown(BoardView.expanded);
    state = s.copyWith(
      working.copyWith(
        rows: placeNewCards(
          s.rows,
          present,
          defaultOrder(def.defaultRows(fits), present),
        ),
      ),
    );
  }

  /// The default rows inside the session; Cancel still undoes it.
  void reset(int fits) {
    final s = state;
    if (s == null) return;
    final present = s.working.shown(BoardView.expanded);
    final defaults = def.defaultRows(fits);
    state = s.copyWith(
      s.working.copyWith(
        rows: placeNewCards(defaults, present, defaultOrder(defaults, present)),
      ),
    );
  }

  /// Ends the session and hands it back.
  ArrangeSession? end() {
    final s = state;
    state = null;
    return s;
  }
}

final arrangeSessionProvider =
    NotifierProvider.family<
      ArrangeSessionNotifier,
      ArrangeSession?,
      BoardDefinition
    >(ArrangeSessionNotifier.new);

/// Leaves arrange mode without saving; discarded changes come back with
/// Undo.
void cancelArrange(BuildContext context, WidgetRef ref, BoardDefinition def) {
  final notifier = ref.read(arrangeSessionProvider(def).notifier);
  final session = notifier.end();
  if (session == null || !session.hasChanges) return;
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(context.l10n.boardDiscarded),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: context.l10n.commonUndo,
          onPressed: () => notifier.restore(session),
        ),
      ),
    );
}

/// Saves the session as the custom layout: its rows and the cards it
/// removed or added, on top of the saved state as it is now (options and
/// other changes made meanwhile stay). Without a change it leaves like
/// Cancel. From Auto over a different saved layout, Undo puts the board
/// back as it was.
Future<void> finishArrange(
  BuildContext context,
  WidgetRef ref,
  BoardDefinition def,
) async {
  final undo = BoardUndo.of(context, ref, def);
  final session = ref.read(arrangeSessionProvider(def).notifier).end();
  if (session == null || !session.hasChanges) return;

  const view = BoardView.expanded;
  final (before, after) = await ref.read(boardRepositoryProvider).update(
    def,
    view,
    (current) {
      // Normalized under the mode it had, so a card that showed on Auto
      // without an entry (shipped after the last save) stays shown.
      var next = current
          .normalized(view)
          .copyWith(mode: LayoutMode.custom, rows: session.rows);
      for (final id in def.cards) {
        final shows = session.working.shows(view, id);
        if (shows != session.before.shows(view, id)) {
          next = next.withVisible(view, id, visible: shows);
        }
      }
      return next;
    },
  );
  if (before.mode == LayoutMode.auto &&
      before.rows != null &&
      !const ListEquality<BoardRow>().equals(after.rows, before.rows)) {
    undo.show(
      undo.l.boardReplaced,
      view,
      (s) => s.withArrangementOf(before).withVisibilityOf(view, before),
    );
  }
}
