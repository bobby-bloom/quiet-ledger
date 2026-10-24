import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/amount_text.dart';
import 'package:personal_finance/app/ui/breakpoints.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/app/ui/pickers.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/lookups.dart';
import 'package:personal_finance/features/accounts/data/accounts_repository.dart';
import 'package:personal_finance/features/accounts/data/net_worth.dart';
import 'package:personal_finance/features/accounts/domain/account_grouping.dart';
import 'package:personal_finance/features/accounts/presentation/account_actions.dart';
import 'package:personal_finance/features/accounts/presentation/account_detail_screen.dart';
import 'package:personal_finance/features/accounts/presentation/account_labels.dart';
import 'package:personal_finance/features/accounts/presentation/account_providers.dart';
import 'package:personal_finance/features/categories/presentation/appearance_pickers.dart';

/// `/accounts`: grouped account list with the net-worth header. On
/// expanded windows it is a list-detail layout.
class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  bool _reordering = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final size = WindowSize.of(context);
    final accountsAsync = ref.watch(accountsProvider);
    final accounts = accountsAsync.value ?? const <Account>[];
    final selectedId = ref.watch(selectedAccountProvider);
    final liveIds = {for (final a in accounts) a.id};
    final listDetail = size.isExpanded && !_reordering;

    // Keep a valid selection in the detail pane.
    String? detailId;
    if (listDetail) {
      if (selectedId != null && liveIds.contains(selectedId)) {
        detailId = selectedId;
      } else {
        detailId = accounts.where((a) => !a.archived).firstOrNull?.id;
      }
    }

    void open(Account a) {
      if (listDetail) {
        ref.read(selectedAccountProvider.notifier).select(a.id);
      } else {
        unawaited(context.push('/accounts/${a.id}'));
      }
    }

    final list = AsyncView(
      value: accountsAsync,
      data: (all) => all.isEmpty
          ? EmptyState(
              icon: Icons.account_balance_outlined,
              message: l.accountsEmpty,
              actionLabel: l.accountsAdd,
              onAction: () => context.push('/accounts/new'),
            )
          : _reordering
          ? const _ReorderList()
          : _AccountList(
              selectedId: detailId,
              onOpen: open,
              onReorder: () => setState(() => _reordering = true),
            ),
    );

    final appBar = _reordering
        ? AppBar(
            title: Text(l.accountsReorder),
            actions: [
              TextButton(
                onPressed: () => setState(() => _reordering = false),
                child: Text(l.commonDone),
              ),
            ],
          )
        : AppBar(
            title: Text(l.accountsTitle, style: context.text.titleLarge),
            actions: [
              // With the detail pane, reconcile lives in the pane.
              if (!listDetail)
                IconButton(
                  tooltip: l.accountsReconcileBalances,
                  icon: const Icon(Icons.balance_outlined),
                  onPressed: accounts.isEmpty ? null : _reconcile,
                ),
              IconButton(
                tooltip: l.accountsAdd,
                icon: const Icon(Icons.add),
                onPressed: () => context.push('/accounts/new'),
              ),
              _OverflowMenu(
                canReorder: accounts.length > 1,
                onReorder: () => setState(() => _reordering = true),
              ),
            ],
          );

    if (!listDetail) return Scaffold(appBar: appBar, body: list);

    return Scaffold(
      appBar: appBar,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 400, child: list),
          const VerticalDivider(width: 1),
          Expanded(
            child: detailId == null
                ? EmptyState(
                    icon: Icons.touch_app_outlined,
                    message: l.accountsSelectHint,
                  )
                : AccountDetailView(
                    key: ValueKey(detailId),
                    accountId: detailId,
                    embedded: true,
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _reconcile() async {
    final id = await showAccountPicker(context);
    if (id == null || !mounted) return;
    await context.push('/accounts/$id/reconcile');
  }
}

class _OverflowMenu extends ConsumerWidget {
  const _OverflowMenu({required this.canReorder, required this.onReorder});

  final bool canReorder;
  final VoidCallback onReorder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final showArchived = ref.watch(showArchivedAccountsProvider);
    return PopupMenuButton<String>(
      tooltip: l.accountsMoreActions,
      onSelected: (v) {
        switch (v) {
          case 'reorder':
            onReorder();
          case 'groups':
            unawaited(context.push('/accounts/groups'));
          case 'archived':
            ref.read(showArchivedAccountsProvider.notifier).toggle();
        }
      },
      itemBuilder: (ctx) => [
        if (canReorder)
          PopupMenuItem(
            value: 'reorder',
            child: ListTile(
              leading: const Icon(Icons.swap_vert),
              title: Text(l.accountsReorder),
            ),
          ),
        PopupMenuItem(
          value: 'groups',
          child: ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: Text(l.accountsManageGroups),
          ),
        ),
        PopupMenuItem(
          value: 'archived',
          child: ListTile(
            leading: Icon(
              showArchived ? Icons.inventory_2 : Icons.inventory_2_outlined,
            ),
            title: Text(
              showArchived
                  ? l.accountsHideArchived
                  : l.accountsShowArchivedMenu,
            ),
          ),
        ),
      ],
    );
  }
}

/// The grouped list (normal mode).
class _AccountList extends ConsumerWidget {
  const _AccountList({
    required this.selectedId,
    required this.onOpen,
    required this.onReorder,
  });

  final String? selectedId;
  final ValueChanged<Account> onOpen;
  final VoidCallback onReorder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final groups =
        ref.watch(accountGroupsProvider).value ?? const <AccountGroup>[];
    final balances = ref.watch(accountBalancesProvider).value ?? const {};
    final showArchived = ref.watch(showArchivedAccountsProvider);
    final sections = groupAccounts(accounts, groups);
    final archived = [
      for (final a in accounts)
        if (a.archived) a,
    ]..sort(compareAccounts);

    final children = <Widget>[
      const NetWorthHeader(),
      for (final s in sections) ...[
        _SectionHeader(
          title: s.group?.name ?? accountTypeLabel(l, s.type!),
          totalMinor: s.subtotal(balances),
        ),
        for (var i = 0; i < s.accounts.length; i++)
          AccountRow(
            account: s.accounts[i],
            balanceMinor:
                balances[s.accounts[i].id] ?? s.accounts[i].openingBalanceMinor,
            selected: s.accounts[i].id == selectedId,
            divider: i > 0,
            onTap: () => onOpen(s.accounts[i]),
            onLongPress: onReorder,
          ),
      ],
      if (archived.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.xs,
            vertical: Space.xs,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () =>
                  ref.read(showArchivedAccountsProvider.notifier).toggle(),
              icon: Icon(showArchived ? Icons.expand_less : Icons.expand_more),
              label: Text(
                showArchived
                    ? l.accountsHideArchived
                    : l.accountsShowArchived(archived.length),
              ),
            ),
          ),
        ),
      if (showArchived && archived.isNotEmpty) ...[
        _SectionHeader(title: l.accountsArchivedSection),
        for (var i = 0; i < archived.length; i++)
          AccountRow(
            account: archived[i],
            balanceMinor:
                balances[archived[i].id] ?? archived[i].openingBalanceMinor,
            selected: archived[i].id == selectedId,
            divider: i > 0,
            onTap: () => onOpen(archived[i]),
          ),
      ],
      const SizedBox(height: Space.xxxl + Space.xxl),
    ];
    return ListView(children: children);
  }
}

/// Net worth with the assets/liabilities split bar (design: Accounts
/// board, summary section).
class NetWorthHeader extends ConsumerWidget {
  const NetWorthHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final summary =
        ref.watch(netWorthSummaryProvider).value ?? NetWorthSummary.zero;
    final fmt = ref.watch(moneyFormatterProvider);
    final share = summary.assetShare;
    final muted = context.text.bodySmall?.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    final strong = context.text.bodySmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: context.colors.onSurface,
    );
    return Semantics(
      container: true,
      label: l.accountsNetWorthSemantics(
        fmt.minor(summary.netMinor),
        fmt.minor(summary.assetsMinor),
        fmt.minor(summary.liabilitiesMinor),
      ),
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.listInset,
            0,
            Space.listInset,
            Space.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      l.accountsNetWorth,
                      style: muted?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: AmountText(
                        summary.netMinor,
                        colored: false,
                        style: context.text.headlineSmall?.copyWith(
                          fontSize: 28,
                          letterSpacing: -0.8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 6,
                child: share == null
                    ? DecoratedBox(
                        decoration: BoxDecoration(
                          color: context.colors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      )
                    : Row(
                        children: [
                          if (share > 0)
                            Expanded(
                              flex: (share * 1000).round().clamp(1, 1000),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: context.colors.primary,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          if (share > 0 && share < 1) const SizedBox(width: 2),
                          if (share < 1)
                            Expanded(
                              flex: ((1 - share) * 1000).round().clamp(1, 1000),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: context.colors.error,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: '${l.accountsAssets} ',
                        children: [
                          WidgetSpan(
                            alignment: PlaceholderAlignment.baseline,
                            baseline: TextBaseline.alphabetic,
                            child: AmountText(
                              summary.assetsMinor,
                              colored: false,
                              style: strong,
                            ),
                          ),
                        ],
                      ),
                      style: muted,
                    ),
                  ),
                  Text.rich(
                    TextSpan(
                      text: '${l.accountsLiabilities} ',
                      children: [
                        WidgetSpan(
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                          child: AmountText(
                            summary.liabilitiesMinor,
                            colored: false,
                            style: strong,
                          ),
                        ),
                      ],
                    ),
                    style: muted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.totalMinor});

  final String title;
  final int? totalMinor;

  @override
  Widget build(BuildContext context) {
    final style = context.text.labelMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: context.colors.onSurfaceVariant,
      letterSpacing: 0.3,
    );
    return Semantics(
      header: true,
      child: Container(
        height: 32,
        color: context.colors.surfaceContainerLow,
        padding: const EdgeInsets.symmetric(horizontal: Space.listInset),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title.toUpperCase(),
                style: style,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (totalMinor != null)
              AmountText(totalMinor!, colored: false, style: style),
          ],
        ),
      ),
    );
  }
}

/// One account in the list: avatar, name, context line, sparkline and
/// balance (52 px).
class AccountRow extends ConsumerWidget {
  const AccountRow({
    required this.account,
    required this.balanceMinor,
    required this.onTap,
    super.key,
    this.selected = false,
    this.divider = false,
    this.onLongPress,
    this.trailing,
  });

  final Account account;
  final int balanceMinor;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final bool divider;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final fmt = ref.watch(moneyFormatterProvider);
    final locale = ref.watch(formatLocaleProvider);
    final spark = ref.watch(
      accountSparklinesProvider.select((m) => m[account.id]),
    );
    final threshold = account.lowBalanceThresholdMinor;
    final below = threshold != null && balanceMinor < threshold;
    final parts = <String>[
      if (threshold != null && below)
        l.accountsBelowThreshold(fmt.minor(threshold))
      else if (threshold != null)
        l.accountsAlertBelow(fmt.minor(threshold)),
      if (!account.includeInNetWorth) l.accountsNotInNetWorth,
      if (!account.includeInBudgets && !account.type.isLiability)
        l.accountsNotInBudgets,
      if (account.expectedAnnualReturnBp != null)
        l.accountsReturnAssumed(
          formatBp(account.expectedAnnualReturnBp!, locale),
        ),
      if (account.interestRateBp != null)
        l.accountsInterestRate(formatBp(account.interestRateBp!, locale)),
    ];
    if (parts.isEmpty) {
      final note = account.note?.split('\n').first.trim();
      parts.add(
        note != null && note.isNotEmpty
            ? note
            : accountTypeLabel(l, account.type),
      );
    }
    final subtitle = parts.join(' · ');
    final color = accountColor(context, account);
    final showSpark =
        spark != null &&
        spark.length > 1 &&
        MediaQuery.sizeOf(context).width >= 360;

    final content = Container(
      constraints: const BoxConstraints(minHeight: 52),
      decoration: BoxDecoration(
        border: divider
            ? Border(top: BorderSide(color: context.colors.surfaceContainer))
            : null,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: Space.listInset,
        vertical: Space.xxs,
      ),
      child: Row(
        children: [
          TintedAvatar(icon: accountIcon(account), color: color),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  account.name,
                  style: context.text.bodyLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: context.text.labelMedium?.copyWith(
                    fontWeight: FontWeight.w400,
                    color: below
                        ? context.finance.warning
                        : context.colors.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (showSpark) ...[
            const SizedBox(width: Space.sm),
            ExcludeSemantics(
              child: SizedBox(
                width: 56,
                height: 20,
                child: CustomPaint(
                  painter: SparklinePainter(
                    spark,
                    color: context.colors.outline,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(width: Space.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 92),
            child: AmountText(
              balanceMinor,
              colored: false,
              textAlign: TextAlign.end,
              style: context.text.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      label: '${account.name}, ${fmt.minor(balanceMinor)}, $subtitle',
      excludeSemantics: true,
      child: Material(
        color: selected
            ? context.colors.secondaryContainer
            : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          onSecondaryTapUp: (d) =>
              _showContextMenu(context, ref, d.globalPosition),
          child: content,
        ),
      ),
    );
  }

  Future<void> _showContextMenu(
    BuildContext context,
    WidgetRef ref,
    Offset at,
  ) async {
    final l = context.l10n;
    final v = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(at.dx, at.dy, at.dx, at.dy),
      items: [
        PopupMenuItem(value: 'open', child: Text(l.accountsOpen)),
        PopupMenuItem(value: 'edit', child: Text(l.commonEdit)),
        PopupMenuItem(value: 'reconcile', child: Text(l.accountsReconcile)),
        PopupMenuItem(
          value: 'archive',
          child: Text(
            account.archived ? l.accountsUnarchive : l.accountsArchive,
          ),
        ),
      ],
    );
    if (v == null || !context.mounted) return;
    switch (v) {
      case 'open':
        onTap();
      case 'edit':
        await context.push('/accounts/${account.id}/edit');
      case 'reconcile':
        await context.push('/accounts/${account.id}/reconcile');
      case 'archive':
        await setAccountArchived(
          context,
          ref,
          account,
          archived: !account.archived,
        );
    }
  }
}

/// Tiny balance trend line.
class SparklinePainter extends CustomPainter {
  SparklinePainter(this.values, {required this.color});

  final List<int> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    var min = values.first;
    var max = values.first;
    for (final v in values) {
      if (v < min) min = v;
      if (v > max) max = v;
    }
    final range = (max - min).toDouble();
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = range == 0
          ? size.height / 2
          : size.height - 2 - (values[i] - min) / range * (size.height - 4);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(SparklinePainter old) =>
      old.color != color || !_listEq(old.values, values);

  static bool _listEq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Reorder mode: one flat list of group headers and accounts. Dragging an
/// account below another header moves it into that group.
class _ReorderList extends ConsumerStatefulWidget {
  const _ReorderList();

  @override
  ConsumerState<_ReorderList> createState() => _ReorderListState();
}

class _ReorderListState extends ConsumerState<_ReorderList> {
  List<LayoutEntry>? _entries;

  List<LayoutEntry> _build(List<Account> accounts, List<AccountGroup> groups) {
    final live = [
      for (final a in accounts)
        if (!a.archived) a,
    ]..sort(compareAccounts);
    final ids = {for (final g in groups) g.id};
    return [
      for (final g in groups) ...[
        LayoutEntry.header(g.id),
        for (final a in live)
          if (a.groupId == g.id) LayoutEntry.account(a.id),
      ],
      const LayoutEntry.header(null),
      for (final a in live)
        if (a.groupId == null || !ids.contains(a.groupId))
          LayoutEntry.account(a.id),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final groups =
        ref.watch(accountGroupsProvider).value ?? const <AccountGroup>[];
    final balances = ref.watch(accountBalancesProvider).value ?? const {};
    final byId = {for (final a in accounts) a.id: a};
    final groupById = {for (final g in groups) g.id: g};
    final fresh = _build(accounts, groups);
    // Adopt external changes (new account/group) but keep local order.
    if (_entries == null ||
        _entries!.toSet().length != fresh.toSet().length ||
        !_entries!.toSet().containsAll(fresh)) {
      _entries = fresh;
    }
    final entries = _entries!;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.listInset,
            Space.xs,
            Space.listInset,
            Space.sm,
          ),
          child: Text(
            l.accountsReorderHint,
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            itemCount: entries.length,
            onReorderItem: (from, to) async {
              final next = moveItem(entries, from, to);
              setState(() => _entries = next);
              await ref
                  .read(accountsRepositoryProvider)
                  .applyLayout(resolveLayout(next));
            },
            itemBuilder: (context, i) {
              final e = entries[i];
              if (e.isHeader) {
                return KeyedSubtree(
                  key: ValueKey('h:${e.groupId}'),
                  child: _SectionHeader(
                    title: e.groupId == null
                        ? l.accountsNoGroup
                        : groupById[e.groupId]?.name ?? '',
                  ),
                );
              }
              final a = byId[e.accountId];
              if (a == null) {
                return SizedBox.shrink(key: ValueKey('a:${e.accountId}'));
              }
              return ReorderableDelayedDragStartListener(
                key: ValueKey('a:${a.id}'),
                index: i,
                child: AccountRow(
                  account: a,
                  balanceMinor: balances[a.id] ?? a.openingBalanceMinor,
                  onTap: () {},
                  trailing: ReorderableDragStartListener(
                    index: i,
                    child: Semantics(
                      label: l.accountsDragHandle(a.name),
                      child: const SizedBox(
                        width: Space.minTouch,
                        height: Space.minTouch,
                        child: Icon(Icons.drag_handle),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
