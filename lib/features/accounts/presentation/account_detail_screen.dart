import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/amount_text.dart';
import 'package:personal_finance/app/ui/app_icons.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/lookups.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/features/accounts/data/account_queries.dart';
import 'package:personal_finance/features/accounts/data/net_worth.dart';
import 'package:personal_finance/features/accounts/presentation/account_actions.dart';
import 'package:personal_finance/features/accounts/presentation/account_labels.dart';
import 'package:personal_finance/features/accounts/presentation/account_providers.dart';
import 'package:personal_finance/features/accounts/presentation/balance_chart.dart';
import 'package:personal_finance/features/categories/presentation/appearance_pickers.dart';
import 'package:personal_finance/features/transactions/presentation/quick_add.dart';

/// `/accounts/:id` as a full screen.
class AccountDetailScreen extends ConsumerWidget {
  const AccountDetailScreen({required this.accountId, super.key});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(accountsProvider);
    final account = ref.watch(accountMapProvider)[accountId];
    if (account == null) {
      return Scaffold(
        appBar: AppBar(),
        body: async.isLoading
            ? const Center(child: CircularProgressIndicator.adaptive())
            : EmptyState(message: l.accountsNotFound),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(account.name, overflow: TextOverflow.ellipsis),
        actions: _actions(
          context,
          ref,
          account,
          onDeleted: () {
            if (context.canPop()) context.pop();
          },
        ),
      ),
      body: AccountDetailBody(account: account),
    );
  }
}

/// Detail of one account inside the list-detail pane (expanded).
class AccountDetailView extends ConsumerWidget {
  const AccountDetailView({
    required this.accountId,
    super.key,
    this.embedded = false,
  });

  final String accountId;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final account = ref.watch(accountMapProvider)[accountId];
    if (account == null) return EmptyState(message: l.accountsNotFound);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 56,
          child: Row(
            children: [
              const SizedBox(width: Space.xl),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    account.name,
                    style: context.text.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              // Reconcile is the button in the body.
              ..._actions(
                context,
                ref,
                account,
                reconcile: false,
                onDeleted: () =>
                    ref.read(selectedAccountProvider.notifier).select(null),
              ),
              const SizedBox(width: Space.xs),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: AccountDetailBody(account: account)),
      ],
    );
  }
}

List<Widget> _actions(
  BuildContext context,
  WidgetRef ref,
  Account account, {
  required VoidCallback onDeleted,
  bool reconcile = true,
}) {
  final l = context.l10n;
  return [
    IconButton(
      tooltip: l.commonEdit,
      icon: const Icon(Icons.edit_outlined),
      onPressed: () => context.push('/accounts/${account.id}/edit'),
    ),
    if (reconcile)
      IconButton(
        tooltip: l.accountsReconcile,
        icon: const Icon(Icons.balance_outlined),
        onPressed: () => context.push('/accounts/${account.id}/reconcile'),
      ),
    PopupMenuButton<String>(
      tooltip: l.accountsMoreActions,
      onSelected: (v) async {
        switch (v) {
          case 'archive':
            await setAccountArchived(
              context,
              ref,
              account,
              archived: !account.archived,
            );
          case 'delete':
            final deleted = await deleteAccountFlow(context, ref, account);
            if (deleted) onDeleted();
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'archive',
          child: ListTile(
            leading: Icon(
              account.archived
                  ? Icons.unarchive_outlined
                  : Icons.archive_outlined,
            ),
            title: Text(
              account.archived ? l.accountsUnarchive : l.accountsArchive,
            ),
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_outline, color: ctx.colors.error),
            title: Text(l.commonDelete),
          ),
        ),
      ],
    ),
  ];
}

enum _Range { m1, m3, m6, y1, all }

/// Scrollable content of the account detail: balance, chart, recent
/// transactions and settings summary.
class AccountDetailBody extends ConsumerStatefulWidget {
  const AccountDetailBody({required this.account, super.key});

  final Account account;

  @override
  ConsumerState<AccountDetailBody> createState() => _AccountDetailBodyState();
}

class _AccountDetailBodyState extends ConsumerState<AccountDetailBody> {
  _Range _range = _Range.y1;

  BalanceHistoryQuery _query() {
    final today = dateOnly(DateTime.now());
    final to = today.add(const Duration(days: 1));
    final a = widget.account;
    final from = switch (_range) {
      _Range.m1 => DateTime(today.year, today.month - 1, today.day),
      _Range.m3 => DateTime(today.year, today.month - 3, today.day),
      _Range.m6 => DateTime(today.year, today.month - 6, today.day),
      _Range.y1 => DateTime(today.year - 1, today.month, today.day),
      _Range.all =>
        a.openingDate.isBefore(today.subtract(const Duration(days: 30)))
            ? dateOnly(a.openingDate)
            : today.subtract(const Duration(days: 30)),
    };
    final long = to.difference(from).inDays > 3 * 366;
    return BalanceHistoryQuery(
      accountIds: {a.id},
      from: from,
      to: to,
      bucket: long ? BalanceBucket.month : BalanceBucket.day,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final a = widget.account;
    final fmt = ref.watch(moneyFormatterProvider);
    final dates = ref.watch(dateFormatsProvider);
    final locale = ref.watch(formatLocaleProvider);
    final balance =
        ref.watch(accountBalancesProvider).value?[a.id] ??
        a.openingBalanceMinor;
    final groups = ref.watch(accountGroupsProvider).value ?? const [];
    final group = groups.where((g) => g.id == a.groupId).firstOrNull;
    final color = accountColor(context, a);
    final threshold = a.lowBalanceThresholdMinor;
    final below = threshold != null && balance < threshold;
    final query = _query();
    final history = ref.watch(balanceHistoryProvider(query));
    final recent = ref.watch(recentTransactionsProvider(a.id));

    final rangeLabels = {
      _Range.m1: l.accountsRange1M,
      _Range.m3: l.accountsRange3M,
      _Range.m6: l.accountsRange6M,
      _Range.y1: l.accountsRange1Y,
      _Range.all: l.accountsRangeAll,
    };

    final flags = <String>[
      if (!a.includeInNetWorth) l.accountsNotInNetWorth,
      if (!a.includeInBudgets) l.accountsNotInBudgets,
      if (!a.includeInForecast) l.accountsNotInForecast,
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Space.md,
        Space.md,
        Space.md,
        Space.xxxl + Space.xxl,
      ),
      children: [
        // ------------------------------------------------ balance header
        Row(
          children: [
            TintedAvatar(icon: accountIcon(a), color: color, size: 44),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Text(
                [
                  accountTypeLabel(l, a.type),
                  ?group?.name,
                  if (a.archived) l.accountsArchivedSection,
                ].join(' · '),
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.sm),
        Text(
          l.accountsCurrentBalance,
          style: context.text.labelMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        AmountText(balance, colored: false, style: context.text.displaySmall),
        if (below) ...[
          const SizedBox(height: Space.xxs),
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: context.finance.warning,
              ),
              const SizedBox(width: Space.xxs),
              Expanded(
                child: Text(
                  l.accountsLowBalanceWarning(fmt.minor(threshold)),
                  style: context.text.labelMedium?.copyWith(
                    color: context.finance.warning,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: Space.md),
        Wrap(
          spacing: Space.xs,
          runSpacing: Space.xs,
          children: [
            FilledButton.tonalIcon(
              onPressed: () => showQuickAdd(
                context,
                initial: TxnDraft(
                  accountId: a.id,
                  amountMinor: 0,
                  date: dateOnly(DateTime.now()),
                ),
              ),
              icon: const Icon(Icons.add),
              label: Text(l.addTransaction),
            ),
            OutlinedButton.icon(
              onPressed: () => context.push('/accounts/${a.id}/reconcile'),
              icon: const Icon(Icons.balance_outlined),
              label: Text(l.accountsReconcile),
            ),
          ],
        ),
        const SizedBox(height: Space.md),

        // ------------------------------------------------------- chart
        SectionCard(
          title: l.accountsBalanceOverTime,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<_Range>(
                showSelectedIcon: false,
                segments: [
                  for (final r in _Range.values)
                    ButtonSegment(value: r, label: Text(rangeLabels[r]!)),
                ],
                selected: {_range},
                onSelectionChanged: (s) => setState(() => _range = s.first),
              ),
              const SizedBox(height: Space.md),
              history.when(
                loading: () => const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator.adaptive()),
                ),
                error: (e, _) => SizedBox(
                  height: 200,
                  child: Center(child: Text(l.commonError(e.toString()))),
                ),
                data: (points) {
                  if (points.length < 2) {
                    return SizedBox(
                      height: 120,
                      child: Center(
                        child: Text(
                          l.accountsChartEmpty,
                          style: context.text.bodySmall?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  }
                  final lowest = points.reduce(
                    (x, y) => y.balanceMinor < x.balanceMinor ? y : x,
                  );
                  return BalanceChart(
                    points: points,
                    thresholdMinor: threshold,
                    color: color,
                    semanticLabel: l.accountsChartSemantics(
                      a.name,
                      dates.medium(points.first.date),
                      dates.medium(points.last.date),
                      fmt.minor(points.first.balanceMinor),
                      fmt.minor(points.last.balanceMinor),
                      fmt.minor(lowest.balanceMinor),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.md),

        // ------------------------------------------- recent transactions
        SectionCard(
          title: l.accountsRecentTransactions,
          actionLabel: l.accountsAllTransactions,
          onAction: () => context.go(
            Uri(
              path: '/transactions',
              queryParameters: {'account': a.id},
            ).toString(),
          ),
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
          child: AsyncView(
            value: recent,
            loading: const SizedBox(height: 80),
            data: (rows) => rows.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(Space.md),
                    child: Text(
                      l.accountsNoTransactions,
                      style: context.text.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < rows.length; i++)
                        _RecentRow(txn: rows[i], divider: i > 0),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: Space.md),

        // ------------------------------------------------------ details
        SectionCard(
          title: l.accountsDetails,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _InfoRow(
                l.accountsFieldOpeningBalance,
                AmountText(a.openingBalanceMinor, colored: false),
              ),
              _InfoRow(
                l.accountsFieldOpeningDate,
                Text(dates.medium(a.openingDate)),
              ),
              if (threshold != null)
                _InfoRow(l.accountsLowBalance, Text(fmt.minor(threshold))),
              if (a.expectedAnnualReturnBp != null)
                _InfoRow(
                  l.accountsExpectedReturn,
                  Text(formatBp(a.expectedAnnualReturnBp!, locale)),
                ),
              if (a.interestRateBp != null)
                _InfoRow(
                  l.accountsInterest,
                  Text(formatBp(a.interestRateBp!, locale)),
                ),
              if (flags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: Space.xs),
                  child: Wrap(
                    spacing: Space.xs,
                    runSpacing: Space.xs,
                    children: [for (final f in flags) StatusBadge(f)],
                  ),
                ),
              if (a.note != null && a.note!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: Space.sm),
                  child: Text(a.note!, style: context.text.bodyMedium),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
        DefaultTextStyle.merge(
          style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          child: value,
        ),
      ],
    ),
  );
}

class _RecentRow extends ConsumerWidget {
  const _RecentRow({required this.txn, required this.divider});

  final RecentTxn txn;
  final bool divider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final dates = ref.watch(dateFormatsProvider);
    final isTransfer = txn.type == TxnType.transfer;
    final category = txn.categoryName == null
        ? null
        : (txn.parentCategoryName == null
              ? txn.categoryName
              : '${txn.parentCategoryName} › ${txn.categoryName}');
    final what = isTransfer
        ? l.accountsTransferWith(txn.peerAccountName ?? '?')
        : txn.isSplit
        ? l.accountsSplit
        : category ?? l.accountsUncategorized;
    final title = txn.payee ?? (isTransfer ? what : (category ?? what));
    final subtitle = [
      dates.short(txn.date),
      if (txn.payee != null || isTransfer) what,
    ].join(' · ');
    final icon = isTransfer
        ? Icons.swap_horiz
        : txn.isSplit
        ? Icons.call_split
        : AppIcons.of(txn.categoryIcon);
    final color = isTransfer
        ? context.finance.transfer
        : txn.categoryColor == null
        ? null
        : Color(txn.categoryColor!);
    return InkWell(
      onTap: () => showQuickAdd(context, editId: txn.id),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(
          horizontal: Space.md,
          vertical: Space.xs,
        ),
        decoration: BoxDecoration(
          border: divider
              ? Border(top: BorderSide(color: context.colors.surfaceContainer))
              : null,
        ),
        child: Row(
          children: [
            IconTile(icon: icon, color: color, size: 36),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.text.bodyLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (txn.status != TxnStatus.cleared) ...[
              StatusBadge(
                txn.status == TxnStatus.pending
                    ? l.statusPending
                    : l.statusPlanned,
              ),
              const SizedBox(width: Space.xs),
            ],
            AmountText(
              txn.amountMinor,
              type: txn.type,
              style: context.text.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
