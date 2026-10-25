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
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/features/accounts/data/reconciliation.dart';
import 'package:personal_finance/features/accounts/domain/account_grouping.dart';
import 'package:personal_finance/features/accounts/presentation/account_labels.dart';
import 'package:personal_finance/features/accounts/presentation/account_providers.dart';
import 'package:personal_finance/features/categories/presentation/appearance_pickers.dart';

/// `/accounts/:id/reconcile`: compare the bank balance with the cleared
/// balance, clear pending transactions and book a correction for the rest.
class ReconcileScreen extends ConsumerStatefulWidget {
  const ReconcileScreen({required this.accountId, super.key});

  final String accountId;

  @override
  ConsumerState<ReconcileScreen> createState() => _ReconcileScreenState();
}

class _ReconcileScreenState extends ConsumerState<ReconcileScreen> {
  int? _actual;
  DateTime _date = dateOnly(DateTime.now());
  final Set<String> _selected = {};
  bool _busy = false;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1970),
      lastDate: dateOnly(DateTime.now()).add(const Duration(days: 366)),
    );
    if (picked != null) {
      setState(() {
        _date = dateOnly(picked);
        _selected.clear();
      });
    }
  }

  Future<void> _markCleared() async {
    final l = context.l10n;
    final ids = {..._selected};
    setState(() => _busy = true);
    try {
      await ref.read(reconciliationServiceProvider).markCleared(ids);
      if (!mounted) return;
      setState(_selected.clear);
      showSnack(context, l.accountsMarkedCleared(ids.length));
    } on Exception catch (e) {
      if (mounted) showSnack(context, l.commonError(e.toString()));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _correct(int difference) async {
    final l = context.l10n;
    final fmt = ref.read(moneyFormatterProvider);
    final ok = await confirmDialog(
      context,
      title: l.accountsCorrectionConfirmTitle,
      message: l.accountsCorrectionConfirm(fmt.minor(difference)),
      confirmLabel: l.accountsCreateCorrectionShort,
      destructive: false,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final id = await ref
          .read(reconciliationServiceProvider)
          .createCorrection(
            accountId: widget.accountId,
            actualMinor: _actual!,
            asOf: _date,
            payee: l.accountsCorrectionPayee,
            note: l.accountsCorrectionNote,
          );
      if (!mounted) return;
      if (id != null) showSnack(context, l.accountsCorrectionCreated);
    } on Exception catch (e) {
      if (mounted) showSnack(context, l.commonError(e.toString()));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final account = ref.watch(accountMapProvider)[widget.accountId];
    if (account == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l.accountsReconcileTitle)),
        body: ref.watch(accountsProvider).isLoading
            ? const Center(child: CircularProgressIndicator.adaptive())
            : EmptyState(message: l.accountsNotFound),
      );
    }
    final key = (account.id, _date);
    final recorded = ref.watch(recordedBalanceProvider(key));
    final pending = ref.watch(pendingTransactionsProvider(key));
    final dates = ref.watch(dateFormatsProvider);
    final wide = !WindowSize.of(context).isCompact;

    final rec = recorded.value;
    final difference = rec == null || _actual == null
        ? null
        : reconciliationDifference(
            actualMinor: _actual!,
            clearedMinor: rec.clearedMinor,
          );
    final pendingRows = pending.value ?? const <Txn>[];
    final selectedSum = pendingRows
        .where((t) => _selected.contains(t.id))
        .fold<int>(0, (s, t) => s + t.amountMinor);

    final input = SectionCard(
      title: l.accountsBankBalance,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.accountsReconcileIntro,
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Space.sm),
          MoneyField(
            autofocus: true,
            allowNegative: true,
            label: l.accountsBankBalance,
            onChanged: (v) => setState(() => _actual = v),
          ),
          const SizedBox(height: Space.xs),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: Text(l.accountsBankDate),
            subtitle: Text(dates.medium(_date)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickDate,
          ),
        ],
      ),
    );

    final summary = SectionCard(
      title: l.accountsDifference,
      child: rec == null
          ? const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator.adaptive()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Line(l.accountsClearedBalance, rec.clearedMinor),
                _Line(
                  l.accountsPendingSum(rec.pendingCount),
                  rec.pendingMinor,
                  muted: true,
                ),
                if (_actual != null) _Line(l.accountsBankBalance, _actual!),
                const Divider(height: Space.lg),
                _DifferenceBanner(
                  difference: difference,
                  busy: _busy,
                  onCorrect: difference == null || difference == 0
                      ? null
                      : () => _correct(difference),
                  onDone: () => context.pop(),
                ),
              ],
            ),
    );

    final pendingCard = SectionCard(
      title: l.accountsPendingTitle,
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
      child: AsyncView(
        value: pending,
        loading: const SizedBox(height: 80),
        data: (rows) {
          if (rows.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(Space.md),
              child: Text(
                l.accountsNoPending,
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            );
          }
          final allSelected = rows.every((t) => _selected.contains(t.id));
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.md),
                child: Text(
                  l.accountsPendingHint,
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
              CheckboxListTile(
                value: allSelected,
                onChanged: (v) => setState(() {
                  if (v ?? false) {
                    _selected.addAll(rows.map((t) => t.id));
                  } else {
                    _selected.clear();
                  }
                }),
                title: Text(l.accountsSelectAll),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              for (final t in rows)
                CheckboxListTile(
                  value: _selected.contains(t.id),
                  onChanged: (v) => setState(
                    () => (v ?? false)
                        ? _selected.add(t.id)
                        : _selected.remove(t.id),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    t.payee ?? t.note ?? l.accountsUncategorized,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(dates.short(t.date)),
                  secondary: AmountText(
                    t.amountMinor,
                    type: t.type,
                    style: context.text.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.md,
                  Space.xs,
                  Space.md,
                  0,
                ),
                child: FilledButton.tonal(
                  onPressed: _selected.isEmpty || _busy ? null : _markCleared,
                  child: Text(
                    _selected.isEmpty
                        ? l.accountsMarkClearedNone
                        : l.accountsMarkCleared(
                            _selected.length,
                            ref
                                .watch(moneyFormatterProvider)
                                .minor(selectedSum),
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    final body = wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    input,
                    const SizedBox(height: Space.cardGap),
                    summary,
                  ],
                ),
              ),
              const SizedBox(width: Space.cardGap),
              Expanded(child: pendingCard),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              input,
              const SizedBox(height: Space.cardGap),
              summary,
              const SizedBox(height: Space.cardGap),
              pendingCard,
            ],
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(l.accountsReconcileTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(
              left: Space.md,
              right: Space.md,
              bottom: Space.xs,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${account.name} · ${accountTypeLabel(l, account.type)}',
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          wide ? Space.xl : Space.md,
          Space.md,
          wide ? Space.xl : Space.md,
          Space.xxxl + Space.xxl,
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: body,
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.minor, {this.muted = false});

  final String label;
  final int minor;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final style = context.text.bodyMedium?.copyWith(
      color: muted ? context.colors.onSurfaceVariant : null,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xxs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          AmountText(
            minor,
            colored: false,
            style: style?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _DifferenceBanner extends StatelessWidget {
  const _DifferenceBanner({
    required this.difference,
    required this.busy,
    required this.onCorrect,
    required this.onDone,
  });

  final int? difference;
  final bool busy;
  final VoidCallback? onCorrect;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (difference == null) {
      return Text(
        l.accountsEnterBankBalance,
        style: context.text.bodyMedium?.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
      );
    }
    if (difference == 0) {
      return Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.all(Space.sm),
          decoration: BoxDecoration(
            color: context.colors.primaryContainer,
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: context.colors.onPrimaryContainer,
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  l.accountsReconciled,
                  style: context.text.bodyMedium?.copyWith(
                    color: context.colors.onPrimaryContainer,
                  ),
                ),
              ),
              TextButton(onPressed: onDone, child: Text(l.commonDone)),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l.accountsDifference,
                  style: context.text.titleSmall,
                ),
              ),
              AmountText(
                difference!,
                colored: false,
                explicitPlus: difference! > 0,
                style: context.text.titleMedium?.copyWith(
                  color: context.finance.warning,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.xxs),
        Text(
          difference! > 0 ? l.accountsDifferenceMore : l.accountsDifferenceLess,
          style: context.text.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Space.sm),
        Consumer(
          builder: (context, ref, _) => FilledButton(
            onPressed: busy ? null : onCorrect,
            child: Text(
              l.accountsCreateCorrection(
                ref.watch(moneyFormatterProvider).minor(difference!),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
