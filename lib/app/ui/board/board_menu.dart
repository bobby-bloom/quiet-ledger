import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/board/board_actions.dart';
import 'package:personal_finance/app/ui/board/board_labels.dart';
import 'package:personal_finance/app/ui/board/board_order_sheet.dart';
import 'package:personal_finance/app/ui/board/drop_slot.dart';
import 'package:personal_finance/app/ui/pickers.dart';
import 'package:personal_finance/core/board/board_layout.dart';
import 'package:personal_finance/core/board/board_state.dart';

/// A board's layout button (docs/BOARD.md, Board menu). Wide, it opens the
/// board menu: the Layout control, Arrange…, Add… and the screen's own
/// [menuExtras]. With one column it opens the order sheet directly, with
/// [orderExtras]. Its tooltip says whose layout shows.
class BoardLayoutButton extends ConsumerWidget {
  const BoardLayoutButton({
    required this.def,
    required this.labels,
    required this.view,
    required this.saved,
    required this.layout,
    super.key,
    this.focusNode,
    this.icon = Icons.dashboard_customize_outlined,
    this.menuExtras = const [],
    this.orderExtras,
  });

  final BoardDefinition def;
  final BoardLabels labels;
  final BoardView view;
  final BoardState saved;

  /// What the wide board shows now; null with one column.
  final BoardLayout? layout;

  /// The button's focus: it gets it back when arrange mode ends.
  final FocusNode? focusNode;
  final IconData icon;

  /// More items at the end of the board menu.
  final List<Widget> menuExtras;

  /// The screen's own controls in the order sheet, for the cards shown.
  final Widget Function(List<String> shown)? orderExtras;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final tooltip = saved.mode == LayoutMode.custom
        ? labels.menuCustom
        : labels.menu;
    final layout = this.layout;
    if (view == BoardView.compact || layout == null) {
      return IconButton(
        focusNode: focusNode,
        tooltip: tooltip,
        icon: Icon(icon),
        onPressed: () => unawaited(
          showBoardOrderSheet(
            context,
            def: def,
            labels: labels,
            extras: orderExtras,
          ),
        ),
      );
    }

    final hasNew = def.cards.any((id) => saved.isNew(view, id));
    return MenuAnchor(
      menuChildren: [
        BoardLayoutChoice(
          def: def,
          labels: labels,
          saved: saved,
          layout: layout,
        ),
        const Divider(),
        MenuItemButton(
          leadingIcon: const Icon(Icons.drag_indicator),
          onPressed: layout.canArrange
              ? () => ref
                    .read(arrangeSessionProvider(def).notifier)
                    .enter(saved, layout.placed)
              : null,
          child: _TwoLines(
            title: labels.arrangeMenu,
            subtitle: layout.canArrange ? null : l.boardArrangeNeeds,
          ),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.add),
          trailingIcon: hasNew ? const NewBadge() : null,
          onPressed: () => unawaited(
            showAddCards(
              context,
              labels: labels,
              view: view,
              state: saved,
              onAdd: (id) => addCard(ref, def, view, id),
            ),
          ),
          child: Text(labels.addMenu),
        ),
        if (menuExtras.isNotEmpty) ...[const Divider(), ...menuExtras],
      ],
      builder: (context, controller, _) => IconButton(
        focusNode: focusNode,
        tooltip: tooltip,
        icon: Icon(icon),
        isSelected: controller.isOpen,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

/// The menu's Layout control: Auto · 1 · 2 · 3 (· Custom while a layout is
/// saved that no number stands for). The selected segment is what shows;
/// numbers wider than the window are disabled, a selected one dimmed. The
/// line under it says whose arrangement shows, or that the window fits
/// fewer columns.
class BoardLayoutChoice extends ConsumerWidget {
  const BoardLayoutChoice({
    required this.def,
    required this.labels,
    required this.saved,
    required this.layout,
    super.key,
  });

  final BoardDefinition def;
  final BoardLabels labels;
  final BoardState saved;
  final BoardLayout layout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final selected = selectedSegment(layout.mode, saved.rows);
    final segments = [
      LayoutSegment.auto,
      ...LayoutSegment.numbers,
      if (offersCustom(saved.rows)) LayoutSegment.custom,
    ];
    final fits = layout.fits;
    final selectedTooWide = (selected.columns ?? 0) > fits;
    final line = layout.isSqueezed || selectedTooWide
        ? (fits == 1 ? l.boardFitsOne : l.boardFitsUpTo(fits))
        : layout.mode == LayoutMode.custom
        ? labels.customHint
        : labels.autoHint;

    return SizedBox(
      width: 320,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.md,
          Space.xs,
          Space.md,
          Space.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: Space.xs,
          children: [
            ExcludeSemantics(
              child: Text(l.boardLabel, style: context.text.labelLarge),
            ),
            Semantics(
              label: l.boardLabel,
              hint: line,
              child: SegmentedButton<LayoutSegment>(
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.padded,
                ),
                segments: [
                  for (final s in segments)
                    ButtonSegment(
                      value: s,
                      enabled: (s.columns ?? 0) <= fits,
                      tooltip: (s.columns ?? 0) > fits
                          ? l.boardSplitFits(fits)
                          : null,
                      label: switch (s) {
                        LayoutSegment.auto => Text(l.boardAuto),
                        LayoutSegment.custom => Text(l.boardCustom),
                        // Read as "Two equal columns", seen as "2".
                        _ => Semantics(
                          label: splitName(l, RowSplit.equal(s.columns!)),
                          excludeSemantics: true,
                          child: Text('${s.columns}'),
                        ),
                      },
                    ),
                ],
                selected: {selected},
                onSelectionChanged: (picked) => unawaited(
                  pickLayout(context, ref, def, picked.first, layout),
                ),
              ),
            ),
            ExcludeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: Space.xxs,
                children: [
                  if (layout.isSqueezed || selectedTooWide)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.info_outline,
                        size: 14,
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      line,
                      style: context.text.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TwoLines extends StatelessWidget {
  const _TwoLines({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    if (subtitle == null) return Text(title);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title),
          Text(
            subtitle,
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// The small "New" badge of a card that shipped after the last save.
class NewBadge extends StatelessWidget {
  const NewBadge({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: Space.xs, vertical: 2),
    decoration: BoxDecoration(
      color: context.colors.primaryContainer,
      borderRadius: BorderRadius.circular(Radii.full),
    ),
    child: Text(
      context.l10n.boardNew,
      style: context.text.labelSmall?.copyWith(
        color: context.colors.onPrimaryContainer,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// The Add dialog (a sheet on phones): every card that does not show in
/// [view] — removed ones ("its settings are kept") and new ones ("New") —
/// with its icon and what it shows; tapping one adds it.
Future<void> showAddCards(
  BuildContext context, {
  required BoardLabels labels,
  required BoardView view,
  required BoardState state,
  required ValueChanged<String> onAdd,
}) => showAdaptiveSheet<void>(
  context,
  builder: (ctx) {
    final l = ctx.l10n;
    final ids = [
      for (final id in state.def.cards)
        if (!state.shows(view, id)) id,
    ];
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.xl,
              Space.lg,
              Space.xl,
              Space.xs,
            ),
            child: Text(labels.addTitle, style: ctx.text.titleLarge),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final id in ids)
                  ListTile(
                    leading: Icon(labels.cardIcon(id)),
                    title: Row(
                      spacing: Space.xs,
                      children: [
                        Flexible(child: Text(labels.cardTitle(id))),
                        if (state.isNew(view, id)) const NewBadge(),
                      ],
                    ),
                    subtitle: Text(
                      state.isNew(view, id) || !state.items.containsKey(id)
                          ? labels.cardDescription(id)
                          : '${labels.cardDescription(id)}\n'
                                '${l.boardRemovedHint}',
                    ),
                    isThreeLine:
                        !state.isNew(view, id) && state.items.containsKey(id),
                    trailing: TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        onAdd(id);
                      },
                      child: Text(l.commonAdd),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      onAdd(id);
                    },
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Space.xs),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l.commonClose),
              ),
            ),
          ),
        ],
      ),
    );
  },
);
