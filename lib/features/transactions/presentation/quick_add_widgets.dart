import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/app_icons.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/features/transactions/domain/calculator.dart';
import 'package:personal_finance/features/transactions/presentation/txn_labels.dart';

/// Expense / income / transfer segmented switch. The selected segment takes
/// the type's container colour (Foundations "Segmented / type switch").
class TxnTypeSwitch extends StatelessWidget {
  const TxnTypeSwitch({
    required this.value,
    required this.onChanged,
    super.key,
    this.types = TxnType.values,
  });

  final TxnType value;
  final ValueChanged<TxnType> onChanged;
  final List<TxnType> types;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final fin = context.finance;
    final l = context.l10n;
    (Color, Color) colorsFor(TxnType t) => switch (t) {
      TxnType.expense => (fin.expenseContainer, fin.onExpenseContainer),
      TxnType.income => (fin.incomeContainer, fin.onIncomeContainer),
      TxnType.transfer => (fin.transferContainer, cs.onSurface),
    };
    IconData iconFor(TxnType t) => switch (t) {
      TxnType.expense => Icons.north_east,
      TxnType.income => Icons.south_west,
      TxnType.transfer => Icons.swap_horiz,
    };
    return Semantics(
      label: l.txnFilterType,
      container: true,
      // The segments are clipped to the inside of the outline, so the
      // selected fill never paints over the border.
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          border: Border.all(color: cs.outline),
          borderRadius: BorderRadius.circular(22),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(21),
          child: Row(
            children: [
              for (var i = 0; i < types.length; i++)
                Expanded(
                  child: Semantics(
                    inMutuallyExclusiveGroup: true,
                    checked: types[i] == value,
                    button: true,
                    child: Material(
                      color: types[i] == value
                          ? colorsFor(types[i]).$1
                          : Colors.transparent,
                      child: InkWell(
                        onTap: () => onChanged(types[i]),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(
                              left: i == 0
                                  ? BorderSide.none
                                  : BorderSide(color: cs.outline),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (types[i] == value) ...[
                                Icon(
                                  iconFor(types[i]),
                                  size: 18,
                                  color: colorsFor(types[i]).$2,
                                ),
                                const SizedBox(width: 6),
                              ],
                              Flexible(
                                child: Text(
                                  TxnLabels.type(l, types[i]),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.text.bodyMedium?.copyWith(
                                    fontWeight: types[i] == value
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: types[i] == value
                                        ? colorsFor(types[i]).$2
                                        : cs.onSurface,
                                  ),
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
          ),
        ),
      ),
    );
  }
}

/// The big centred amount field, coloured by [type]. Uses the platform
/// keyboard; it takes a calculation ("20+4.80"), shows the result
/// underneath, and Enter replaces the calculation by it ([onSubmitted]).
class AmountField extends ConsumerWidget {
  const AmountField({
    required this.controller,
    required this.type,
    required this.decimalSeparator,
    required this.label,
    required this.onChanged,
    required this.onSubmitted,
    super.key,
    this.error,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final TxnType type;
  final String decimalSeparator;

  /// Accessible name ("Amount", "Amount *" when required).
  final String label;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;
  final String? error;
  final bool autofocus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.colors;
    final fin = context.finance;
    final l = context.l10n;
    final fmt = ref.watch(moneyFormatterProvider);
    final expression = controller.text;
    final color = expression.isEmpty
        ? cs.onSurfaceVariant
        : switch (type) {
            TxnType.expense => fin.expense,
            TxnType.income => fin.income,
            TxnType.transfer => fin.transfer,
          };
    final hasOp = AmountCalculator.hasOperator(expression);
    final preview = hasOp
        ? AmountCalculator.evaluate(
            expression,
            decimalSeparator: decimalSeparator,
            lenient: true,
          )
        : null;
    final big = hasOp ? 34.0 : 50.0;
    final style = TextStyle(
      fontSize: big,
      height: 56 / 50,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.2,
      fontFeatures: const [FontFeature.tabularFigures()],
      color: color,
    );
    const none = InputBorder.none;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ExcludeSemantics(
                child: Text(
                  '€',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Sized to its text so the amount stays centred with the €.
              Flexible(
                child: IntrinsicWidth(
                  child: Semantics(
                    label: label,
                    child: TextField(
                      controller: controller,
                      autofocus: autofocus,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9.,+\-−×÷*/() ]'),
                        ),
                      ],
                      style: style,
                      cursorColor: cs.primary,
                      decoration: InputDecoration(
                        isCollapsed: true,
                        filled: false,
                        hintText: '0',
                        hintStyle: style.copyWith(color: cs.onSurfaceVariant),
                        border: none,
                        enabledBorder: none,
                        focusedBorder: none,
                        errorBorder: none,
                        focusedErrorBorder: none,
                        disabledBorder: none,
                      ),
                      onChanged: onChanged,
                      onSubmitted: (_) => onSubmitted(),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (error != null)
            Text(
              error!,
              style: context.text.labelMedium?.copyWith(color: cs.error),
            )
          else if (preview != null)
            Text(
              preview.isOk
                  ? l.txnAmountPreview(fmt.minor(preview.minor!.abs()))
                  : l.txnErrAmountInvalid,
              style: context.text.bodyMedium?.copyWith(
                color: preview.isOk ? cs.onSurfaceVariant : cs.error,
              ),
            ),
        ],
      ),
    );
  }
}

/// Outlined two-line field button ("Account / Everyday checking").
class TxnFieldButton extends StatelessWidget {
  const TxnFieldButton({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    super.key,
    this.error,
    this.placeholder = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final String? error;

  /// [value] is a hint (nothing chosen yet).
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final hasError = error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: cs.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
            side: BorderSide(
              color: hasError ? cs.error : cs.surfaceContainerHighest,
              width: hasError ? 1.5 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Semantics(
              button: true,
              label: '$label: $value',
              excludeSemantics: true,
              child: SizedBox(
                height: 56,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.sm),
                  child: Row(
                    children: [
                      Icon(icon, size: 20, color: cs.onSurfaceVariant),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: context.text.labelMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: placeholder
                                    ? cs.onSurfaceVariant
                                    : cs.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: Space.sm, top: 2),
            child: Text(
              error!,
              style: context.text.labelMedium?.copyWith(color: cs.error),
            ),
          ),
      ],
    );
  }
}

/// Grid of category shortcuts (favourites + recent) with an "All" tile.
class CategoryShortcutGrid extends StatelessWidget {
  const CategoryShortcutGrid({
    required this.categories,
    required this.selectedId,
    required this.onSelect,
    required this.onAll,
    super.key,
    this.columns = 5,
  });

  final List<Category> categories;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final VoidCallback onAll;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = context.colors;
    final tiles = <Widget>[
      for (final c in categories)
        _CategoryTile(
          label: c.name,
          icon: AppIcons.of(c.icon),
          color: c.color == null ? cs.primary : Color(c.color!),
          selected: c.id == selectedId,
          onTap: () => onSelect(c.id),
        ),
      _CategoryTile(
        label: l.commonAll,
        icon: Icons.grid_view_outlined,
        color: cs.onSurfaceVariant,
        selected: false,
        outlined: true,
        semantics: l.txnChooseCategory,
        onTap: onAll,
      ),
    ];
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += columns) {
      final slice = tiles.sublist(i, (i + columns).clamp(0, tiles.length));
      rows.add(
        Row(
          children: [
            for (final t in slice) Expanded(child: t),
            for (var j = slice.length; j < columns; j++)
              const Expanded(child: SizedBox()),
          ],
        ),
      );
    }
    return Semantics(
      label: l.fieldCategory,
      container: true,
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
    this.outlined = false,
    this.semantics,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final bool outlined;
  final VoidCallback onTap;
  final String? semantics;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Semantics(
        button: true,
        inMutuallyExclusiveGroup: !outlined,
        checked: outlined ? null : selected,
        label: semantics ?? label,
        excludeSemantics: true,
        child: Material(
          color: selected ? cs.secondaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: SizedBox(
              height: 68,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: outlined
                          ? null
                          : selected
                          ? cs.primary
                          : Color.alphaBlend(
                              color.withValues(alpha: 0.16),
                              cs.surfaceContainerLowest,
                            ),
                      border: outlined ? Border.all(color: cs.outline) : null,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      icon,
                      size: 20,
                      color: outlined
                          ? cs.onSurfaceVariant
                          : selected
                          ? cs.onPrimary
                          : color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelMedium?.copyWith(
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: selected
                            ? cs.onSecondaryContainer
                            : cs.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small section label ("Recent categories", "Split", "Tags").
class TxnSectionLabel extends StatelessWidget {
  const TxnSectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: context.text.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
