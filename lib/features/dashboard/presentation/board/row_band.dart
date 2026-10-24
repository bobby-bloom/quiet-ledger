import 'package:flutter/material.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/features/dashboard/domain/arrange.dart';
import 'package:personal_finance/features/dashboard/domain/board_layout.dart';
import 'package:personal_finance/features/dashboard/presentation/board/drop_slot.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

/// A row in arrange mode: a dashed band around its columns ([child]) with a
/// slim toolbar — the small "Row n" label, the [SplitPicker] and ⋮ for the
/// [RowMenu]. A row saved wider than the window fits says so ("Needs a
/// wider window") and its split button shows the saved split dimmed.
class RowBand extends StatelessWidget {
  const RowBand({
    required this.index,
    required this.count,
    required this.row,
    required this.fits,
    required this.onSplit,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
    required this.menuFocusNode,
    required this.child,
    super.key,
  });

  /// The row's place among the working rows, from 0, and how many there are.
  final int index;
  final int count;

  /// The row as saved.
  final BoardRow row;

  /// How many columns fit the window.
  final int fits;

  final ValueChanged<RowSplit> onSplit;

  /// The row menu's actions; null disables one (the first row cannot move
  /// up, the only row cannot go).
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onRemove;

  /// The ⋮ button's focus, owned by the board: focus follows a moved row.
  final FocusNode menuFocusNode;

  final Widget child;

  /// Inside the band, between its dashed outline and the columns.
  static const double padding = Space.xs;

  /// The toolbar's height.
  static const double toolbarHeight = 32;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final isTooWide = isRowTooWide(row, fits);

    // One node per band, read as "Row 2 of 3, Two equal columns".
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label:
          '${l.dashLayoutRowOf(index + 1, count)}, ${splitName(l, row.split)}',
      child: DashedOutline(
        color: theme.colorScheme.outline,
        child: Padding(
          padding: const EdgeInsets.all(padding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: Space.xs,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: toolbarHeight),
                child: Row(
                  spacing: Space.xxs,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: Space.xxs,
                        ),
                        child: Wrap(
                          spacing: Space.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // The band's label says it in full.
                            ExcludeSemantics(
                              child: Text(
                                l.dashLayoutRow(index + 1).toUpperCase(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: muted,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            if (isTooWide)
                              Text(
                                l.dashLayoutRowTooWide,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: muted,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    SplitPicker(
                      split: row.split,
                      fits: fits,
                      onSelected: onSplit,
                    ),
                    RowMenu(
                      index: index,
                      focusNode: menuFocusNode,
                      onMoveUp: onMoveUp,
                      onMoveDown: onMoveDown,
                      onRemove: onRemove,
                    ),
                  ],
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// The ⋮ button of a [RowBand] and its menu: Move row up, Move row down
/// and, set apart, Remove row. Actions that cannot apply are disabled.
class RowMenu extends StatelessWidget {
  const RowMenu({
    required this.index,
    required this.focusNode,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
    super.key,
  });

  final int index;
  final FocusNode focusNode;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.arrow_upward),
          onPressed: onMoveUp,
          child: Text(l.dashLayoutMoveRowUp),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.arrow_downward),
          onPressed: onMoveDown,
          child: Text(l.dashLayoutMoveRowDown),
        ),
        const Divider(),
        MenuItemButton(
          leadingIcon: const Icon(Icons.remove),
          onPressed: onRemove,
          child: Text(l.dashLayoutRemoveRow),
        ),
      ],
      builder: (context, controller, _) => IconButton(
        focusNode: focusNode,
        tooltip: l.dashLayoutRowMenu(index + 1),
        icon: const Icon(Icons.more_vert, size: 20),
        style: IconButton.styleFrom(
          minimumSize: const Size.square(RowBand.toolbarHeight),
          fixedSize: const Size.square(RowBand.toolbarHeight),
          padding: EdgeInsets.zero,
        ),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

/// The split button of a row band: the row's [split] as a small diagram
/// and a caret, opening the templates of [RowSplit.templates]. The current
/// one is selected; splits wider than the [fits] columns are disabled with
/// the fit hint, and a saved split already too wide shows dimmed.
class SplitPicker extends StatefulWidget {
  const SplitPicker({
    required this.split,
    required this.fits,
    required this.onSelected,
    super.key,
  });

  final RowSplit split;
  final int fits;
  final ValueChanged<RowSplit> onSelected;

  @override
  State<SplitPicker> createState() => _SplitPickerState();
}

class _SplitPickerState extends State<SplitPicker> {
  final _menu = MenuController();

  /// The option focused when the menu opens: the current split, or the
  /// first that fits while the current one does not.
  final _openFocus = FocusNode(debugLabel: 'split picker');

  @override
  void dispose() {
    _openFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final isTooWide = !splitFits(widget.split, widget.fits);

    return MenuAnchor(
      controller: _menu,
      onOpen: () => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openFocus.requestFocus();
      }),
      menuChildren: [_grid(context)],
      builder: (context, controller, _) => Tooltip(
        message: l.dashLayoutRowSplit,
        excludeFromSemantics: true,
        child: MergeSemantics(
          child: Semantics(
            label: l.dashLayoutRowSplit,
            value: splitName(l, widget.split),
            child: OutlinedButton(
              onPressed: () =>
                  controller.isOpen ? controller.close() : controller.open(),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, RowBand.toolbarHeight),
                fixedSize: const Size.fromHeight(RowBand.toolbarHeight),
                padding: const EdgeInsetsDirectional.only(
                  start: Space.xs,
                  end: Space.xxs,
                ),
                foregroundColor: colors.onSurface,
                side: BorderSide(color: colors.outline),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: Space.xxs,
                children: [
                  Opacity(
                    opacity: isTooWide ? 0.38 : 1,
                    child: SplitDiagram(weights: widget.split.weights),
                  ),
                  const Icon(Icons.expand_more, size: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _grid(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    const templates = RowSplit.templates;
    final focused = splitFits(widget.split, widget.fits)
        ? widget.split
        : templates.firstWhere((s) => splitFits(s, widget.fits));
    final hasTooWide = templates.any((s) => !splitFits(s, widget.fits));

    Widget option(RowSplit split) => _SplitOption(
      split: split,
      name: splitName(l, split),
      isCurrent: split == widget.split,
      fitHint: splitFits(split, widget.fits)
          ? null
          : l.dashLayoutSplitFits(widget.fits),
      focusNode: split == focused ? _openFocus : null,
      onPressed: () {
        _menu.close();
        if (split != widget.split) widget.onSelected(split);
      },
    );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: l.dashLayoutRowSplit,
      child: SizedBox(
        width: 252,
        child: Padding(
          padding: const EdgeInsets.all(Space.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: Space.xs,
            children: [
              ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.xxs),
                  child: Text(
                    l.dashLayoutRowSplit,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              for (var start = 0; start < templates.length; start += 3)
                Row(
                  spacing: Space.xs,
                  children: [
                    for (final split in templates.skip(start).take(3))
                      Expanded(child: option(split)),
                    // Keeps the last row's options as wide as the first's.
                    for (
                      var pad = templates.skip(start).take(3).length;
                      pad < 3;
                      pad++
                    )
                      const Expanded(child: SizedBox.shrink()),
                  ],
                ),
              if (hasTooWide)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.xxs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: Space.xxs,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.info_outline,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          l.dashLayoutSplitFits(widget.fits),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One split in the picker: its diagram, named [name], outlined in primary
/// while [isCurrent], dimmed and disabled with [fitHint] while the window
/// is too narrow for it.
class _SplitOption extends StatelessWidget {
  const _SplitOption({
    required this.split,
    required this.name,
    required this.isCurrent,
    required this.fitHint,
    required this.focusNode,
    required this.onPressed,
  });

  final RowSplit split;
  final String name;
  final bool isCurrent;
  final String? fitHint;
  final FocusNode? focusNode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isEnabled = fitHint == null;
    return Tooltip(
      message: name,
      excludeFromSemantics: true,
      child: MergeSemantics(
        child: Semantics(
          label: name,
          hint: fitHint,
          selected: isCurrent,
          child: Opacity(
            opacity: isEnabled ? 1 : 0.35,
            child: OutlinedButton(
              focusNode: focusNode,
              onPressed: isEnabled ? onPressed : null,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                side: isCurrent
                    ? BorderSide(color: colors.primary, width: 2)
                    : BorderSide(color: colors.outline),
                backgroundColor: isCurrent
                    ? colors.primary.withValues(alpha: 0.1)
                    : null,
                foregroundColor: isCurrent ? colors.primary : colors.onSurface,
                disabledForegroundColor: colors.onSurface,
              ),
              child: SplitDiagram(weights: split.weights),
            ),
          ),
        ),
      ),
    );
  }
}
