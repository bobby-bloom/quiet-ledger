import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/features/dashboard/data/dashboard_layout.dart';
import 'package:personal_finance/features/dashboard/domain/board_layout.dart';
import 'package:personal_finance/features/dashboard/domain/dashboard_view.dart';
import 'package:personal_finance/features/dashboard/presentation/widget_registry.dart';

// What the dashboard's controls do to its saved views (docs/DASHBOARD.md):
// every change is one write of the whole view, and the ones that replace
// something offer Undo, which writes the view back as it was.

/// Shows [message] with Undo, which writes [before] back for [view].
void showLayoutUndo(
  BuildContext context,
  WidgetRef ref,
  String message,
  DashboardView view,
  DashboardViewState before,
) {
  final repo = ref.read(dashboardLayoutRepositoryProvider);
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: context.l10n.commonUndo,
          onPressed: () => unawaited(repo.save(view, before)),
        ),
      ),
    );
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
  final repo = ref.read(dashboardLayoutRepositoryProvider);
  final before = await repo.read(view);
  await repo.save(view, before.withVisible(view, type, visible: false));
  if (!context.mounted) return;
  showLayoutUndo(
    context,
    ref,
    context.l10n.dashLayoutRemoved(widgetTypeLabel(context.l10n, type)),
    view,
    before,
  );
}

/// Puts [type] back on [view]: into its kept slot, else after its nearest
/// default neighbour.
Future<void> addWidget(
  WidgetRef ref,
  DashboardView view,
  DashboardWidgetType type,
) async {
  final repo = ref.read(dashboardLayoutRepositoryProvider);
  final state = await repo.read(view);
  await repo.save(view, state.withVisible(view, type, visible: true));
}

/// Replaces [type]'s options in [view].
Future<void> setWidgetOptions(
  WidgetRef ref,
  DashboardView view,
  DashboardWidgetType type,
  Map<String, Object?> options,
) async {
  final repo = ref.read(dashboardLayoutRepositoryProvider);
  final state = await repo.read(view);
  await repo.save(view, state.withOptions(view, type, options));
}

/// The Layout control's pick on the wide board. Auto and Custom switch the
/// mode (the saved rows stay); a number restores a saved layout of that many
/// equal columns, or deals the widgets on screen into one — with Undo when
/// that replaces a different saved layout.
Future<void> pickLayout(
  BuildContext context,
  WidgetRef ref,
  LayoutSegment segment,
  BoardLayout layout,
) async {
  const view = DashboardView.expanded;
  final repo = ref.read(dashboardLayoutRepositoryProvider);
  final before = await repo.read(view);
  final columns = segment.columns;
  if (columns == null) {
    final mode = segment == LayoutSegment.auto
        ? LayoutMode.auto
        : LayoutMode.custom;
    if (mode == LayoutMode.custom && before.rows == null) return;
    await repo.save(view, before.copyWith(mode: mode));
    return;
  }
  if (equalRowColumns(before.rows) == columns) {
    await repo.save(view, before.copyWith(mode: LayoutMode.custom));
    return;
  }
  final rows = [dealRow(layout.order, columns)];
  await repo.save(view, before.copyWith(mode: LayoutMode.custom, rows: rows));
  if (before.rows != null && context.mounted) {
    showLayoutUndo(
      context,
      ref,
      context.l10n.dashLayoutFlattened(columns),
      view,
      before,
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
  final repo = ref.read(dashboardLayoutRepositoryProvider);
  final before = await repo.read(view);
  await repo.save(
    view,
    before.copyWith(
      mode: LayoutMode.auto,
      items: {
        for (final t in DashboardWidgetType.values)
          t.name: WidgetEntry(
            visible: defaultTypes(view).contains(t),
            options: before.optionsOf(t),
          ),
      },
    ),
  );
  if (!context.mounted) return;
  showLayoutUndo(context, ref, context.l10n.dashLayoutResetDone, view, before);
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

/// Saves the session as the custom layout — except from Auto with nothing
/// changed, which leaves like Cancel. From Auto over a different saved
/// layout, Undo puts the board back as it was.
Future<void> finishArrange(BuildContext context, WidgetRef ref) async {
  final session = ref.read(arrangeSessionProvider.notifier).end();
  if (session == null) return;
  final before = session.before;
  final isAuto = before.mode == LayoutMode.auto;
  if (isAuto && !session.hasChanges) return;

  const view = DashboardView.expanded;
  final repo = ref.read(dashboardLayoutRepositoryProvider);
  final next = session.working.copyWith(
    mode: LayoutMode.custom,
    rows: session.rows,
  );
  await repo.save(view, next);
  final saved = await repo.read(view);
  if (isAuto &&
      before.rows != null &&
      !listEquals(saved.rows, before.rows) &&
      context.mounted) {
    showLayoutUndo(context, ref, context.l10n.dashLayoutReplaced, view, before);
  }
}
