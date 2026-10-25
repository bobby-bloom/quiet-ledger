import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/features/dashboard/data/dashboard_layout.dart';
import 'package:personal_finance/features/dashboard/domain/board_layout.dart';
import 'package:personal_finance/features/dashboard/domain/dashboard_view.dart';
import 'package:personal_finance/features/dashboard/presentation/card_expansion.dart';
import 'package:personal_finance/features/dashboard/presentation/dashboard_layout_actions.dart';
import 'package:personal_finance/features/dashboard/presentation/dashboard_menu.dart';
import 'package:personal_finance/features/dashboard/presentation/widget_registry.dart';

/// Opens the phone's dashboard editor (docs/DASHBOARD.md, Phone): the
/// Layout choice Auto · Custom, one row per widget with a grip, ▲ ▼ and
/// Remove, the widgets not on the dashboard with Add, and Done. Every
/// change applies at once and the board behind follows; Auto is the way
/// back. It is also the non-drag way to reorder (▲ ▼).
Future<void> showPhoneEditor(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const PhoneEditorSheet(),
    );

class PhoneEditorSheet extends ConsumerStatefulWidget {
  const PhoneEditorSheet({super.key});

  @override
  ConsumerState<PhoneEditorSheet> createState() => _PhoneEditorSheetState();
}

class _PhoneEditorSheetState extends ConsumerState<PhoneEditorSheet> {
  static const _view = DashboardView.compact;

  /// The arrows of each row: focus stays on the pressed one, or moves to
  /// the other one when the widget reaches an end.
  final _up = <DashboardWidgetType, FocusNode>{};
  final _down = <DashboardWidgetType, FocusNode>{};

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

  Future<void> _change(
    DashboardViewState Function(DashboardViewState current) change,
  ) => ref.read(dashboardLayoutRepositoryProvider).update(_view, change);

  /// Moves [type] to [position] among the widgets shown and saves the order
  /// — from Auto, the default order with the move becomes the custom one,
  /// and a custom order saved before can come back with Undo. Hidden
  /// widgets keep their place.
  Future<void> _move(DashboardWidgetType type, int position) async {
    final l = context.l10n;
    final view = View.of(context);
    final direction = Directionality.of(context);
    List<String>? replaced;
    var count = 0;
    var to = -1;
    final (_, after) = await ref.read(dashboardLayoutRepositoryProvider).update(
      _view,
      (s) {
        final shown = [for (final t in phoneOrder(s)) t.name];
        final from = shown.indexOf(type.name);
        to = position.clamp(0, shown.length - 1);
        count = shown.length;
        if (from < 0 || from == to) return s;
        if (s.mode == LayoutMode.auto && s.order != null) replaced = s.order;
        // Normalized first: a type that shows on Auto without an entry
        // stays shown on Custom.
        return s
            .normalized(_view)
            .copyWith(
              mode: LayoutMode.custom,
              order: moveInOrder(placedPhoneOrder(s), shown, type.name, to),
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
        l.dashLayoutMovedTo(widgetTypeLabel(l, type), to + 1, count),
        direction,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state =
        ref.watch(dashboardViewProvider(_view)).value ??
        DashboardViewState.empty;
    final shown = phoneOrder(state);
    final hidden = [
      for (final t in DashboardWidgetType.values)
        if (!state.shows(_view, t)) t,
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
                  Text(l.dashEditTitle, style: context.text.titleLarge),
                  Text(
                    l.dashLayoutSheetSubtitle,
                    style: context.text.bodyMedium?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Space.sm),
                  _PhoneLayoutChoice(
                    state: state,
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
                            l.dashLayoutOrderReplaced,
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
                  _FoldAll(types: shown),
                ],
              ),
            ),
          ),
          SliverReorderableList(
            itemCount: shown.length,
            onReorderItem: (from, to) => unawaited(_move(shown[from], to)),
            itemBuilder: (context, i) {
              final t = shown[i];
              final name = widgetName(ref, l, t, state);
              final arrows = [
                IconButton(
                  focusNode: _up.putIfAbsent(t, FocusNode.new),
                  tooltip: l.dashLayoutMoveUpWidget(name),
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
                  tooltip: l.dashLayoutMoveDownWidget(name),
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
                  tooltip: l.dashLayoutRemoveWidget(name),
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
                        widgetIcon(t),
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
                  l.dashLayoutNotOnDashboard,
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
                  leading: Icon(widgetIcon(t)),
                  title: Row(
                    spacing: Space.xs,
                    children: [
                      Flexible(child: Text(widgetTypeLabel(l, t))),
                      if (state.isNew(_view, t)) const NewBadge(),
                    ],
                  ),
                  subtitle: Text(widgetDescription(l, t)),
                  trailing: TextButton.icon(
                    onPressed: () => unawaited(addWidget(ref, _view, t)),
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

/// Auto · Custom for the phone order (Custom only while one is saved) and
/// the line saying whose order shows.
class _PhoneLayoutChoice extends StatelessWidget {
  const _PhoneLayoutChoice({required this.state, required this.onMode});

  final DashboardViewState state;
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
          child: Text(l.dashLayoutLabel, style: context.text.labelLarge),
        ),
        SegmentedButton<LayoutMode>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: LayoutMode.auto,
              label: Text(l.dashLayoutAuto),
            ),
            if (state.order != null)
              ButtonSegment(
                value: LayoutMode.custom,
                label: Text(l.dashLayoutCustom),
              ),
          ],
          selected: {mode},
          onSelectionChanged: (picked) => onMode(picked.first),
        ),
        Text(
          mode == LayoutMode.custom
              ? l.dashLayoutPhoneCustomHint
              : l.dashLayoutPhoneAutoHint,
          style: context.text.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Expand all and Collapse all for the phone's cards that fold (all but
/// Net worth, the hero); each disabled when it would change nothing.
class _FoldAll extends ConsumerWidget {
  const _FoldAll({required this.types});

  final List<DashboardWidgetType> types;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final expansion = ref.watch(cardExpansionProvider);
    final foldable = [
      for (final t in types)
        if (t != DashboardWidgetType.netWorth) t,
    ];
    void setAll(bool open) =>
        ref.read(cardExpansionProvider.notifier).setAll(foldable, open);
    return Wrap(
      spacing: Space.xs,
      children: [
        TextButton.icon(
          onPressed: expansion.wouldChange(foldable, true)
              ? () => setAll(true)
              : null,
          icon: const Icon(Icons.unfold_more),
          label: Text(l.dashLayoutExpandAll),
        ),
        TextButton.icon(
          onPressed: expansion.wouldChange(foldable, false)
              ? () => setAll(false)
              : null,
          icon: const Icon(Icons.unfold_less),
          label: Text(l.dashLayoutCollapseAll),
        ),
      ],
    );
  }
}
