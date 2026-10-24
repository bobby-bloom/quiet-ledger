import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/features/dashboard/data/dashboard_layout.dart';
import 'package:personal_finance/features/dashboard/domain/board_layout.dart';
import 'package:personal_finance/features/dashboard/domain/dashboard_view.dart';
import 'package:personal_finance/features/dashboard/presentation/widget_registry.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

// What the dashboard's controls do to its saved views (docs/DASHBOARD.md):
// every change is one write of the whole view, and the ones that replace
// something offer Undo, which writes the view back as it was.

/// The Undo toast of a layout change, taken before the change is awaited:
/// the control that started it (the arrange bar, a menu) may be gone by the
/// time the write is done, the app's messenger is not.
class LayoutUndo {
  LayoutUndo.of(BuildContext context, WidgetRef ref)
    : l = context.l10n,
      _messenger = ScaffoldMessenger.maybeOf(context),
      _repo = ref.read(dashboardLayoutRepositoryProvider);

  final AppLocalizations l;
  final ScaffoldMessengerState? _messenger;
  final DashboardLayoutRepository _repo;

  /// Shows [message] with Undo, which changes [view] by [undo]: each Undo
  /// puts back only what its action changed, on the state as it is then.
  void show(
    String message,
    DashboardView view,
    DashboardViewState Function(DashboardViewState current) undo,
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
            onPressed: () => unawaited(_repo.update(view, undo)),
          ),
        ),
      );
  }
}

/// The widgets that show in [view], in reading order, for the wide board.
List<String> presentIds(DashboardViewState state, DashboardView view) => [
  for (final t in state.shown(view)) t.name,
];

/// The wide layout of [state] where [fits] columns fit.
BoardLayout wideLayout(DashboardViewState state, int fits) =>
    resolveBoardLayout(
      mode: state.mode,
      saved: state.rows,
      defaultRows: defaultRows(fits),
      present: presentIds(state, DashboardView.expanded),
      fits: fits,
    );

/// The phone's order with every id placed, hidden ones in their slots: the
/// saved order on Custom, else the default.
List<String> placedPhoneOrder(DashboardViewState state) {
  final base = state.mode == LayoutMode.custom && state.order != null
      ? state.order!
      : defaultPhoneOrder();
  return placeNewCardsInOrder(
    base,
    presentIds(state, DashboardView.compact),
    defaultPhoneOrder(),
  );
}

/// The widgets the phone shows, in order.
List<DashboardWidgetType> phoneOrder(DashboardViewState state) {
  final present = presentIds(state, DashboardView.compact).toSet();
  return [
    for (final id in placedPhoneOrder(state))
      if (present.contains(id)) DashboardWidgetType.values.byName(id),
  ];
}

/// Takes [type] off [view] (its slot and options kept), with Undo.
Future<void> removeWidget(
  BuildContext context,
  WidgetRef ref,
  DashboardView view,
  DashboardWidgetType type,
) async {
  final undo = LayoutUndo.of(context, ref);
  final repo = ref.read(dashboardLayoutRepositoryProvider);
  await repo.update(view, (s) => s.withVisible(view, type, visible: false));
  undo.show(
    undo.l.dashLayoutRemoved(widgetTypeLabel(undo.l, type)),
    view,
    (s) => s.withVisible(view, type, visible: true),
  );
}

/// Puts [type] back on [view]: into its kept slot, else after its nearest
/// default neighbour.
Future<void> addWidget(
  WidgetRef ref,
  DashboardView view,
  DashboardWidgetType type,
) => ref
    .read(dashboardLayoutRepositoryProvider)
    .update(view, (s) => s.withVisible(view, type, visible: true));

/// Replaces [type]'s options in [view].
Future<void> setWidgetOptions(
  WidgetRef ref,
  DashboardView view,
  DashboardWidgetType type,
  Map<String, Object?> options,
) => ref
    .read(dashboardLayoutRepositoryProvider)
    .update(view, (s) => s.withOptions(view, type, options));

/// The Layout control's pick on the wide board. Auto and Custom switch the
/// mode (the saved rows stay); a number restores a saved layout of that many
/// equal columns, or deals the widgets on screen into one — hidden widgets
/// keep a slot after their neighbour — with Undo when that replaces a
/// different saved layout.
Future<void> pickLayout(
  BuildContext context,
  WidgetRef ref,
  LayoutSegment segment,
  BoardLayout layout,
) async {
  const view = DashboardView.expanded;
  final undo = LayoutUndo.of(context, ref);
  final repo = ref.read(dashboardLayoutRepositoryProvider);
  final columns = segment.columns;
  final (before, after) = await repo.update(view, (s) {
    if (columns == null) {
      if (segment == LayoutSegment.auto) {
        return s.copyWith(mode: LayoutMode.auto);
      }
      if (s.rows == null) return s;
      // Entries written as things show now, so a type that shows on Auto
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
  });
  if (columns != null &&
      before.rows != null &&
      !const ListEquality<BoardRow>().equals(before.rows, after.rows)) {
    undo.show(
      undo.l.dashLayoutFlattened(columns),
      view,
      (s) => s.withArrangementOf(before),
    );
  }
}

/// Auto with the default widgets, options and saved arrangements kept, with
/// Undo: the empty dashboard's way back.
Future<void> resetToDefault(
  BuildContext context,
  WidgetRef ref,
  DashboardView view,
) async {
  final undo = LayoutUndo.of(context, ref);
  final repo = ref.read(dashboardLayoutRepositoryProvider);
  final (before, _) = await repo.update(
    view,
    (s) => s
        .withVisibilityOf(view, DashboardViewState.empty)
        .copyWith(mode: LayoutMode.auto),
  );
  undo.show(
    undo.l.dashLayoutResetDone,
    view,
    (s) => s.withVisibilityOf(view, before).copyWith(mode: before.mode),
  );
}

/// An arrange session on the wide board: the saved state when it began
/// ([before]), the rows it started from ([start]) and the work so far
/// ([working]: rows, and widgets removed or added inside the session).
@immutable
class ArrangeSession {
  const ArrangeSession({
    required this.before,
    required this.start,
    required this.working,
  });

  final DashboardViewState before;
  final List<BoardRow> start;
  final DashboardViewState working;

  List<BoardRow> get rows => working.rows ?? start;

  bool get hasChanges =>
      !listEquals(rows, start) ||
      !mapEquals(
        working.normalized(DashboardView.expanded).items,
        before.normalized(DashboardView.expanded).items,
      );

  ArrangeSession copyWith(DashboardViewState working) =>
      ArrangeSession(before: before, start: start, working: working);
}

/// The running arrange session, or null. Kept while the window is too
/// narrow to arrange (paused): the board shows normally and the session
/// resumes once two columns fit again.
class ArrangeSessionNotifier extends Notifier<ArrangeSession?> {
  @override
  ArrangeSession? build() => null;

  /// Starts arranging [saved] from the rows on screen, [seed].
  void enter(DashboardViewState saved, List<BoardRow> seed) =>
      state = ArrangeSession(
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
      s.working.withVisible(
        DashboardView.expanded,
        DashboardWidgetType.values.byName(id),
        visible: false,
      ),
    );
  }

  /// Adds [type] inside the session: into its kept slot, else after its
  /// nearest default neighbour.
  void add(DashboardWidgetType type, int fits) {
    final s = state;
    if (s == null) return;
    final working = s.working.withVisible(
      DashboardView.expanded,
      type,
      visible: true,
    );
    final present = presentIds(working, DashboardView.expanded);
    state = s.copyWith(
      working.copyWith(
        rows: placeNewCards(
          s.rows,
          present,
          defaultOrder(defaultRows(fits), present),
        ),
      ),
    );
  }

  /// The default rows inside the session; Cancel still undoes it.
  void reset(int fits) {
    final s = state;
    if (s == null) return;
    final present = presentIds(s.working, DashboardView.expanded);
    final defaults = defaultRows(fits);
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
    NotifierProvider<ArrangeSessionNotifier, ArrangeSession?>(
      ArrangeSessionNotifier.new,
    );

/// Leaves arrange mode without saving; discarded changes come back with
/// Undo.
void cancelArrange(BuildContext context, WidgetRef ref) {
  final notifier = ref.read(arrangeSessionProvider.notifier);
  final session = notifier.end();
  if (session == null || !session.hasChanges) return;
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(context.l10n.dashLayoutDiscarded),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: context.l10n.commonUndo,
          onPressed: () => notifier.restore(session),
        ),
      ),
    );
}

/// Saves the session as the custom layout: its rows and the widgets it
/// removed or added, on top of the saved state as it is now (options and
/// other changes made meanwhile stay). Without a change it leaves like
/// Cancel. From Auto over a different saved layout, Undo puts the board
/// back as it was.
Future<void> finishArrange(BuildContext context, WidgetRef ref) async {
  final undo = LayoutUndo.of(context, ref);
  final session = ref.read(arrangeSessionProvider.notifier).end();
  if (session == null || !session.hasChanges) return;

  const view = DashboardView.expanded;
  final repo = ref.read(dashboardLayoutRepositoryProvider);
  final (before, after) = await repo.update(view, (current) {
    // Normalized under the mode it had, so a type that showed on Auto
    // without an entry (shipped after the last save) stays shown.
    var next = current
        .normalized(view)
        .copyWith(mode: LayoutMode.custom, rows: session.rows);
    for (final t in DashboardWidgetType.values) {
      final shows = session.working.shows(view, t);
      if (shows != session.before.shows(view, t)) {
        next = next.withVisible(view, t, visible: shows);
      }
    }
    return next;
  });
  if (before.mode == LayoutMode.auto &&
      before.rows != null &&
      !const ListEquality<BoardRow>().equals(after.rows, before.rows)) {
    undo.show(
      undo.l.dashLayoutReplaced,
      view,
      (s) => s.withArrangementOf(before).withVisibilityOf(view, before),
    );
  }
}
