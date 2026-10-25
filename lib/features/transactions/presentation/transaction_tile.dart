import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/amount_text.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/lookups.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/transactions/data/txn_list_repository.dart';
import 'package:personal_finance/features/transactions/presentation/txn_labels.dart';

/// Height of a [TransactionTile] row (design: 62 + hairline).
const kTxnTileHeight = 64.0;

/// Height of a table row on wide screens.
const kTxnTableRowHeight = 44.0;

/// Transaction list row (Foundations "List row · transaction"): category
/// avatar, payee, "Category · Account", amount coloured by type, status
/// badge. Reusable by other features (dashboard, account detail).
class TransactionTile extends ConsumerWidget {
  const TransactionTile({
    required this.item,
    super.key,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTapDown,
    this.selected = false,
    this.selectionMode = false,
    this.focused = false,
    this.showAccount = true,
    this.showBalance = false,
    this.showDate = false,
    this.divider = false,
    this.inset = Space.listInset,
  });

  final TxnListItem item;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final GestureTapDownCallback? onSecondaryTapDown;

  /// Highlighted (multi-select or the row shown in the detail pane).
  final bool selected;

  /// Shows a check circle instead of the avatar.
  final bool selectionMode;

  /// Keyboard focus ring.
  final bool focused;
  final bool showAccount;

  /// Shows [TxnListItem.runningBalance] under the amount.
  final bool showBalance;

  /// Shows the date in the subtitle (lists without day headers).
  final bool showDate;

  /// Hairline on top (between rows of one group).
  final bool divider;

  /// Horizontal padding of the row (0 inside a card that already pads).
  final double inset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cs = context.colors;
    final accounts = ref.watch(accountMapProvider);
    final categories = ref.watch(categoryMapProvider);
    final tags = ref.watch(tagMapProvider);
    final tagsOn = ref.watch(
      settingsProvider.select((s) => s.moduleEnabled(AppModule.tags)),
    );
    final fmt = ref.watch(moneyFormatterProvider);
    final dates = ref.watch(dateFormatsProvider);
    // Privacy mode: no amount in plain text or in what a screen reader reads.
    final hidden = ref.watch(privacyModeProvider);

    final title = TxnLabels.title(
      l,
      item,
      accounts: accounts,
      categories: categories,
    );
    var subtitle = TxnLabels.subtitle(
      l,
      item,
      accounts: accounts,
      categories: categories,
      showAccount: showAccount,
    );
    if (showDate) subtitle = '${dates.short(item.date)} · $subtitle';
    final (icon, color) = TxnLabels.avatar(context, item, categories);
    final firstTag = tagsOn && item.tagIds.isNotEmpty
        ? tags[item.tagIds.first]
        : null;

    final Widget leading = selectionMode
        ? _SelectCircle(selected: selected)
        : _Avatar(icon: icon, color: color);

    final badge = item.status == TxnStatus.cleared
        ? null
        : TxnStatusBadge(item.status);
    final balance = showBalance && item.runningBalance != null
        ? (hidden ? '•••' : fmt.minor(item.runningBalance!))
        : null;

    final semantics = [
      title,
      subtitle,
      if (hidden) l.privacyHiddenAmount else fmt.minor(item.amountMinor),
      dates.medium(item.date),
      if (badge != null) TxnLabels.status(l, item.status),
      if (item.attachmentCount > 0) l.txnHasReceipt,
    ].join(', ');

    return Semantics(
      selected: selected,
      button: true,
      label: semantics,
      child: ExcludeSemantics(
        child: Material(
          color: selected ? cs.secondaryContainer : Colors.transparent,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            onSecondaryTapDown: onSecondaryTapDown,
            child: Container(
              height: kTxnTileHeight,
              decoration: BoxDecoration(
                border: Border(
                  top: divider
                      ? BorderSide(color: cs.surfaceContainer)
                      : BorderSide.none,
                ),
              ),
              foregroundDecoration: focused
                  ? BoxDecoration(
                      border: Border.all(color: cs.primary, width: 2),
                    )
                  : null,
              padding: EdgeInsets.symmetric(horizontal: inset),
              child: Row(
                children: [
                  leading,
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodyLarge?.copyWith(
                            color: selected ? cs.onSecondaryContainer : null,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                            if (firstTag != null) ...[
                              const SizedBox(width: 6),
                              TxnTagChip(
                                firstTag.name,
                                more: item.tagIds.length - 1,
                              ),
                            ],
                            if (item.attachmentCount > 0) ...[
                              const SizedBox(width: 6),
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 14,
                                color: cs.onSurfaceVariant,
                              ),
                            ],
                            if (item.recurringRuleId != null) ...[
                              const SizedBox(width: 6),
                              Icon(
                                Icons.repeat,
                                size: 14,
                                color: cs.onSurfaceVariant,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      AmountText(
                        item.amountMinor,
                        type: item.type,
                        style: context.text.titleSmall,
                      ),
                      if (badge != null) ...[const SizedBox(height: 2), badge],
                      if (badge == null && balance != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          l.txnBalanceShort(balance),
                          style: context.text.labelMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
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

class _Avatar extends StatelessWidget {
  const _Avatar({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color.alphaBlend(
          color.withValues(alpha: 0.16),
          context.colors.surfaceContainerLowest,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 20, color: color),
    );
  }
}

class _SelectCircle extends StatelessWidget {
  const _SelectCircle({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? cs.primary : Colors.transparent,
        border: selected ? null : Border.all(color: cs.outline, width: 1.5),
      ),
      alignment: Alignment.center,
      child: selected ? Icon(Icons.check, size: 22, color: cs.onPrimary) : null,
    );
  }
}

/// `#tag` chip (Foundations "Chips & badges").
class TxnTagChip extends StatelessWidget {
  const TxnTagChip(this.name, {super.key, this.more = 0, this.onSelected});

  final String name;

  /// Number of further tags, rendered as "+n".
  final int more;

  /// Chip on a selected (secondaryContainer) row.
  final bool? onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: onSelected ?? false
            ? cs.surfaceContainerLowest
            : cs.surfaceContainer,
        borderRadius: BorderRadius.circular(Radii.xs),
      ),
      child: Text(
        more > 0 ? '#$name +$more' : '#$name',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.text.labelMedium?.copyWith(color: cs.onSurfaceVariant),
      ),
    );
  }
}

/// Outlined "Pending"/"Planned" badge.
class TxnStatusBadge extends StatelessWidget {
  const TxnStatusBadge(this.status, {super.key});

  final TxnStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outline),
        borderRadius: BorderRadius.circular(Radii.xs),
      ),
      child: Text(
        TxnLabels.status(context.l10n, status),
        style: context.text.labelSmall?.copyWith(color: cs.onSurfaceVariant),
      ),
    );
  }
}

/// Day/week/month header with the group's net sum.
class TxnGroupHeader extends StatelessWidget {
  const TxnGroupHeader({
    required this.label,
    super.key,
    this.sum,
    this.height = 36,
    this.leftInset = Space.listInset,
  });

  final String label;
  final int? sum;
  final double height;
  final double leftInset;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final style = context.text.bodySmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: cs.onSurfaceVariant,
      fontSize: height < 34 ? 12 : 13,
    );
    return Semantics(
      header: true,
      child: Container(
        height: height,
        color: cs.surfaceContainerLow,
        padding: EdgeInsets.only(left: leftInset, right: Space.md),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (sum != null)
              AmountText(
                sum!,
                colored: false,
                explicitPlus: sum! > 0,
                style: style,
              ),
          ],
        ),
      ),
    );
  }
}

/// Column layout of the wide table.
@immutable
class TxnTableLayout {
  const TxnTableLayout(this.columns);

  final List<TxnColumn> columns;

  static int flex(TxnColumn c) => switch (c) {
    TxnColumn.payee => 15,
    TxnColumn.note => 12,
    TxnColumn.category => 10,
    TxnColumn.account => 10,
    TxnColumn.tags => 9,
    _ => 0,
  };

  static double width(TxnColumn c) => switch (c) {
    TxnColumn.date => 112,
    TxnColumn.status => 92,
    TxnColumn.amount => 112,
    TxnColumn.balance => 112,
    _ => 0,
  };

  static bool alignEnd(TxnColumn c) =>
      c == TxnColumn.amount || c == TxnColumn.balance;
}

Widget _cell(TxnColumn c, Widget child) {
  final f = TxnTableLayout.flex(c);
  final aligned = Align(
    alignment: TxnTableLayout.alignEnd(c)
        ? Alignment.centerRight
        : Alignment.centerLeft,
    child: child,
  );
  final padded = Padding(
    padding: const EdgeInsets.only(right: Space.sm),
    child: aligned,
  );
  return f > 0
      ? Expanded(flex: f, child: padded)
      : SizedBox(width: TxnTableLayout.width(c), child: padded);
}

/// Header row of the wide table, with a select-all checkbox.
class TxnTableHeader extends StatelessWidget {
  const TxnTableHeader({
    required this.layout,
    required this.allSelected,
    required this.onSelectAll,
    super.key,
  });

  final TxnTableLayout layout;

  /// null = some selected (tristate).
  final bool? allSelected;
  final ValueChanged<bool> onSelectAll;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final style = context.text.labelMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: context.colors.onSurfaceVariant,
    );
    return Container(
      height: 36,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: context.colors.surfaceContainerHigh),
        ),
      ),
      padding: const EdgeInsets.only(right: Space.xxs),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Checkbox(
              tristate: true,
              value: allSelected,
              semanticLabel: l.txnSelectAll,
              onChanged: (v) => onSelectAll(allSelected != true),
            ),
          ),
          for (final c in layout.columns)
            _cell(
              c,
              Text(
                txnColumnLabel(l, c),
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

/// One row of the wide table (DesktopTransactions board).
class TxnTableRow extends ConsumerWidget {
  const TxnTableRow({
    required this.item,
    required this.layout,
    super.key,
    this.selected = false,
    this.checked = false,
    this.focused = false,
    this.divider = false,
    this.onTap,
    this.onCheck,
    this.onSecondaryTapDown,
  });

  final TxnListItem item;
  final TxnTableLayout layout;

  /// Shown in the detail pane.
  final bool selected;

  /// Multi-select checkbox state.
  final bool checked;
  final bool focused;
  final bool divider;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onCheck;
  final GestureTapDownCallback? onSecondaryTapDown;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cs = context.colors;
    final accounts = ref.watch(accountMapProvider);
    final categories = ref.watch(categoryMapProvider);
    final tags = ref.watch(tagMapProvider);
    final dates = ref.watch(dateFormatsProvider);
    final fmt = ref.watch(moneyFormatterProvider);
    final highlight = selected || checked;
    final fg = highlight ? cs.onSecondaryContainer : cs.onSurfaceVariant;
    final base = context.text.bodyMedium?.copyWith(color: fg);
    final title = TxnLabels.title(
      l,
      item,
      accounts: accounts,
      categories: categories,
    );

    Widget text(String s, {TextStyle? style}) => Text(
      s,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style ?? base,
    );

    Widget cellFor(TxnColumn c) => switch (c) {
      TxnColumn.date => text(dates.short(item.date)),
      TxnColumn.payee => Row(
        children: [
          Flexible(
            child: text(
              title,
              style: context.text.bodyMedium?.copyWith(
                fontWeight: highlight ? FontWeight.w700 : FontWeight.w600,
                color: highlight ? cs.onSecondaryContainer : cs.onSurface,
              ),
            ),
          ),
          if (item.status != TxnStatus.cleared) ...[
            const SizedBox(width: Space.xs),
            TxnStatusBadge(item.status),
          ],
          if (item.attachmentCount > 0) ...[
            const SizedBox(width: 6),
            Icon(Icons.receipt_long_outlined, size: 14, color: fg),
          ],
        ],
      ),
      TxnColumn.category => Row(
        children: [
          if (item.isSplit) ...[
            Icon(Icons.call_split, size: 16, color: fg),
            const SizedBox(width: 6),
          ],
          Flexible(child: text(TxnLabels.categoryLabel(l, item, categories))),
        ],
      ),
      TxnColumn.account => text(
        item.isTransfer
            ? '${accounts[item.accountId]?.name ?? l.txnUnknownAccount} '
                  '${item.amountMinor > 0 ? '←' : '→'} '
                  '${accounts[item.peerAccountId]?.name ?? l.txnUnknownAccount}'
            : accounts[item.accountId]?.name ?? l.txnUnknownAccount,
      ),
      TxnColumn.tags => Wrap(
        spacing: 4,
        clipBehavior: Clip.hardEdge,
        children: [
          for (final id in item.tagIds.take(2))
            if (tags[id] != null)
              TxnTagChip(tags[id]!.name, onSelected: highlight),
        ],
      ),
      TxnColumn.note => text(item.note ?? ''),
      TxnColumn.status => text(TxnLabels.status(l, item.status)),
      TxnColumn.amount => AmountText(
        item.amountMinor,
        type: item.type,
        style: context.text.bodyMedium?.copyWith(
          fontWeight: highlight ? FontWeight.w800 : FontWeight.w700,
        ),
      ),
      TxnColumn.balance =>
        item.runningBalance == null
            ? const SizedBox.shrink()
            : AmountText(
                item.runningBalance!,
                colored: false,
                style: base?.copyWith(fontWeight: FontWeight.w600),
              ),
    };

    return Semantics(
      selected: highlight,
      label: [
        title,
        if (ref.watch(privacyModeProvider))
          l.privacyHiddenAmount
        else
          fmt.minor(item.amountMinor),
        dates.medium(item.date),
      ].join(', '),
      child: Material(
        color: highlight ? cs.secondaryContainer : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onSecondaryTapDown: onSecondaryTapDown,
          child: Container(
            height: kTxnTableRowHeight,
            decoration: BoxDecoration(
              border: Border(
                top: divider
                    ? BorderSide(color: cs.surfaceContainer)
                    : BorderSide.none,
              ),
            ),
            foregroundDecoration: focused
                ? BoxDecoration(border: Border.all(color: cs.primary, width: 2))
                : null,
            padding: const EdgeInsets.only(right: Space.xxs),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Checkbox(
                    value: checked,
                    semanticLabel: '${l.txnSelect}: $title',
                    onChanged: onCheck == null
                        ? null
                        : (v) => onCheck!(v ?? false),
                  ),
                ),
                for (final c in layout.columns) _cell(c, cellFor(c)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
