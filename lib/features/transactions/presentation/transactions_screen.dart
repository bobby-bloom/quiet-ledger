import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/amount_text.dart';
import 'package:personal_finance/app/ui/breakpoints.dart';
import 'package:personal_finance/app/ui/pickers.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/transactions/data/saved_filters_repository.dart';
import 'package:personal_finance/features/transactions/data/txn_actions.dart';
import 'package:personal_finance/features/transactions/data/txn_list_repository.dart';
import 'package:personal_finance/features/transactions/domain/txn_filter.dart';
import 'package:personal_finance/features/transactions/domain/txn_grouping.dart';
import 'package:personal_finance/features/transactions/presentation/filter_bar.dart';
import 'package:personal_finance/features/transactions/presentation/providers.dart';
import 'package:personal_finance/features/transactions/presentation/quick_add.dart';
import 'package:personal_finance/features/transactions/presentation/quick_add_extras.dart';
import 'package:personal_finance/features/transactions/presentation/transaction_detail.dart';
import 'package:personal_finance/features/transactions/presentation/transaction_list_view.dart';
import 'package:personal_finance/features/transactions/presentation/txn_labels.dart';
import 'package:personal_finance/features/transactions/presentation/txn_ui_actions.dart';

/// The Transactions tab: search, filter chips, saved filters, summary,
/// the (grouped, paginated) list and — on wide layouts — a detail pane.
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key, this.deepLink});

  /// Filter from the route's query parameters ([TxnFilter.fromQuery]);
  /// replaces the current filter when it changes.
  final TxnFilter? deepLink;

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final _ctrl = TxnListController();
  final _search = TextEditingController();
  final _searchFocus = FocusNode(debugLabel: 'txn-search');
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(txnScreenProvider).filter.search;
    _ctrl.addListener(_onCtrl);
    _applyDeepLink();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !WindowSize.of(context).isCompact) {
        _ctrl.focusNode.requestFocus();
      }
    });
  }

  @override
  void didUpdateWidget(TransactionsScreen old) {
    super.didUpdateWidget(old);
    if (old.deepLink != widget.deepLink) _applyDeepLink();
  }

  void _applyDeepLink() {
    final f = widget.deepLink;
    if (f == null || f.isEmpty) return;
    // Providers must not change during build.
    scheduleMicrotask(() {
      if (!mounted) return;
      ref.read(txnScreenProvider.notifier).setFilter(f);
      _search.text = f.search;
      _ctrl
        ..clearSelection()
        ..open(null);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl
      ..removeListener(_onCtrl)
      ..dispose();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onCtrl() {
    if (mounted) setState(() {});
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      ref.read(txnScreenProvider.notifier).setSearch(v);
    });
  }

  void _setFilter(TxnFilter f) {
    ref.read(txnScreenProvider.notifier).setFilter(f);
    _ctrl.clearSelection();
  }

  Future<void> _saveFilter(TxnFilter filter) async {
    final l = context.l10n;
    final name = await promptName(
      context,
      title: l.txnSaveFilter,
      label: l.txnFilterName,
    );
    if (name == null || !mounted) return;
    final id = await ref
        .read(savedFiltersRepositoryProvider)
        .create(name, filter);
    ref.read(txnScreenProvider.notifier).markSaved(id);
    if (mounted) showInfoSnackBar(context, l.txnFilterSaved);
  }

  // ---------------------------------------------------------- bulk ---

  Future<void> _bulk(
    Future<TxnSnapshot> Function(TxnActions a, List<String> ids) run,
  ) async {
    final l = context.l10n;
    final ids = _ctrl.selected.toList();
    if (ids.isEmpty) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final actions = ref.read(txnActionsProvider);
    try {
      final snap = await run(actions, ids);
      showUndoSnackBar(
        messenger,
        l.txnBulkUpdated(ids.length),
        undoLabel: l.commonUndo,
        onUndo: () => actions.restoreSnapshot(snap),
      );
      _ctrl.clearSelection();
    } on Object catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text(l.commonError('$e'))));
    }
  }

  Future<void> _bulkCategory() async {
    final id = await showCategoryPicker(context);
    if (id == null || id.isEmpty) return;
    await _bulk((a, ids) => a.bulkUpdate(ids, categoryId: id));
  }

  Future<void> _bulkDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );
    if (d == null) return;
    await _bulk((a, ids) => a.bulkUpdate(ids, date: d));
  }

  Future<void> _bulkAccount() async {
    final id = await showAccountPicker(context);
    if (id == null) return;
    await _bulk((a, ids) => a.bulkUpdate(ids, accountId: id));
  }

  Future<void> _bulkTags() async {
    final tags = await showTagPicker(context);
    if (tags == null || tags.isEmpty) return;
    await _bulk((a, ids) => a.bulkUpdate(ids, addTagIds: tags.toList()));
  }

  Future<void> _bulkStatus(TxnStatus s) =>
      _bulk((a, ids) => a.bulkUpdate(ids, status: s));

  Future<void> _bulkDelete() async {
    final ok = await deleteTransactionsWithUndo(
      context,
      ref,
      _ctrl.selected.toList(),
    );
    if (ok) _ctrl.clearSelection();
  }

  // ---------------------------------------------------------- build ---

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = ref.watch(txnScreenProvider);
    final filter = state.filter;
    if (!_searchFocus.hasFocus && _search.text != filter.search) {
      _search.text = filter.search;
    }
    final size = WindowSize.of(context);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _searchFocus.requestFocus,
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            _searchFocus.requestFocus,
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth;
              final wide = w >= 720;
              final canPane = w >= 720;
              final detailWidth = w >= 1200 ? 420.0 : 360.0;
              final openId = canPane ? _ctrl.openId : null;

              void onOpen(TxnListItem item) {
                if (canPane) {
                  _ctrl.open(item.id);
                } else {
                  unawaited(context.push('/transactions/${item.id}'));
                }
              }

              final list = TransactionListView(
                filter: filter,
                controller: _ctrl,
                onOpen: onOpen,
                onClearFilters: () => _setFilter(TxnFilter.empty),
                padding: EdgeInsets.only(
                  bottom: size.isCompact ? Space.xxxl + Space.xxl : Space.md,
                ),
              );

              final main = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_ctrl.selectionMode)
                    _SelectionBar(
                      count: _ctrl.selected.length,
                      onClose: _ctrl.clearSelection,
                      onSelectAll: _ctrl.selectAll,
                      onCategory: _bulkCategory,
                      onStatus: _bulkStatus,
                      onDate: _bulkDate,
                      onAccount: _bulkAccount,
                      onTags:
                          ref.watch(
                            settingsProvider.select(
                              (s) => s.moduleEnabled(AppModule.tags),
                            ),
                          )
                          ? _bulkTags
                          : null,
                      onDelete: _bulkDelete,
                    )
                  else
                    _Header(
                      wide: wide,
                      search: _searchField(context, wide: true),
                      onSelect: _ctrl.startSelection,
                    ),
                  if (!wide && !_ctrl.selectionMode)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Space.md,
                        4,
                        Space.md,
                        4,
                      ),
                      child: _searchField(context, wide: false),
                    ),
                  _SavedFilterChips(
                    activeId: state.savedFilterId,
                    padding: EdgeInsets.symmetric(
                      horizontal: wide ? Space.xxl : Space.md,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      left: wide ? Space.xxl - Space.md : 0,
                      right: wide ? Space.xl : 0,
                    ),
                    child: TxnFilterBar(
                      filter: filter,
                      wrap: wide,
                      onChanged: _setFilter,
                      trailing: filter.isEmpty || (state.savedFilterId != null)
                          ? null
                          : TextButton.icon(
                              onPressed: () => _saveFilter(filter),
                              icon: const Icon(Icons.bookmark_add_outlined),
                              label: Text(l.txnSaveFilter),
                            ),
                    ),
                  ),
                  _SummaryLine(
                    filter: filter,
                    wide: wide,
                    padding: EdgeInsets.fromLTRB(
                      wide ? Space.xxl + 4 : Space.lg,
                      4,
                      wide ? Space.xl : Space.lg,
                      6,
                    ),
                  ),
                  _RunningBalanceHint(
                    filter: filter,
                    onChooseAccount: () async {
                      final id = await showAccountPicker(context);
                      if (id != null) {
                        _setFilter(filter.copyWith(accountIds: {id}));
                      }
                    },
                  ),
                  Expanded(
                    child: wide
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(
                              Space.xxl - Space.xs,
                              0,
                              Space.xl,
                              Space.md,
                            ),
                            child: Card(
                              clipBehavior: Clip.antiAlias,
                              child: list,
                            ),
                          )
                        : list,
                  ),
                ],
              );

              if (openId == null) return main;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: main),
                  VerticalDivider(
                    width: 1,
                    color: context.colors.surfaceContainerHigh,
                  ),
                  SizedBox(
                    width: detailWidth,
                    child: Material(
                      color: context.colors.surfaceContainerLowest,
                      child: TransactionDetailView(
                        key: ValueKey(openId),
                        id: openId,
                        pane: true,
                        onClose: () {
                          _ctrl.open(null);
                          _ctrl.focusNode.requestFocus();
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _searchField(BuildContext context, {required bool wide}) {
    final l = context.l10n;
    final cs = context.colors;
    return Semantics(
      label: l.txnSearchLabel,
      textField: true,
      child: SizedBox(
        height: wide ? 44 : 52,
        child: TextField(
          controller: _search,
          focusNode: _searchFocus,
          onChanged: _onSearchChanged,
          textInputAction: TextInputAction.search,
          onSubmitted: (v) {
            _debounce?.cancel();
            ref.read(txnScreenProvider.notifier).setSearch(v);
            _ctrl.focusNode.requestFocus();
          },
          style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: wide ? l.txnSearchHintWide : l.txnSearchHint,
            filled: true,
            fillColor: cs.surfaceContainer,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: l.txnClear,
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _search.clear();
                      _debounce?.cancel();
                      ref.read(txnScreenProvider.notifier).setSearch('');
                      setState(() {});
                    },
                  ),
            contentPadding: const EdgeInsets.symmetric(horizontal: Space.md),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.full),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.full),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.full),
              borderSide: BorderSide(color: cs.primary, width: 2),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({
    required this.wide,
    required this.search,
    required this.onSelect,
  });

  final bool wide;
  final Widget search;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cs = context.colors;
    final actions = [
      IconButton(
        tooltip: l.txnViewOptions,
        icon: const Icon(Icons.tune),
        onPressed: () => showViewOptions(context),
      ),
      IconButton(
        tooltip: l.txnSelectMultiple,
        icon: const Icon(Icons.checklist),
        onPressed: onSelect,
      ),
    ];
    if (!wide) {
      return SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.only(left: Space.lg, right: 4),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l.navTransactions,
                    style: context.text.titleLarge,
                  ),
                ),
              ),
              ...actions,
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.xxl, Space.lg, Space.xl, 8),
      child: Row(
        children: [
          Semantics(
            header: true,
            child: Text(
              l.navTransactions,
              style: context.text.headlineSmall?.copyWith(fontSize: 26),
            ),
          ),
          const Spacer(),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: search,
          ),
          const SizedBox(width: Space.sm),
          ...actions,
          const SizedBox(width: Space.xs),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => showQuickAdd(context),
            icon: const Icon(Icons.add),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.txnNew),
                const SizedBox(width: Space.xs),
                ExcludeSemantics(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: cs.onPrimary.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      '${TxnLabels.modifier(l)} N',
                      style: context.mono.copyWith(
                        fontSize: 11,
                        color: cs.onPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.count,
    required this.onClose,
    required this.onSelectAll,
    required this.onCategory,
    required this.onStatus,
    required this.onDate,
    required this.onAccount,
    required this.onDelete,
    this.onTags,
  });

  final int count;
  final VoidCallback onClose;
  final VoidCallback onSelectAll;
  final VoidCallback onCategory;
  final ValueChanged<TxnStatus> onStatus;
  final VoidCallback onDate;
  final VoidCallback onAccount;
  final VoidCallback? onTags;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = context.colors;
    final enabled = count > 0;
    return Material(
      color: cs.secondaryContainer,
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            IconButton(
              tooltip: l.txnClearSelection,
              icon: const Icon(Icons.close),
              color: cs.onSecondaryContainer,
              onPressed: onClose,
            ),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  l.txnSelectedCount(count),
                  style: context.text.titleMedium?.copyWith(
                    color: cs.onSecondaryContainer,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: l.txnSelectAll,
              icon: const Icon(Icons.select_all),
              onPressed: onSelectAll,
            ),
            IconButton(
              tooltip: l.txnSetCategory,
              icon: const Icon(Icons.category_outlined),
              onPressed: enabled ? onCategory : null,
            ),
            PopupMenuButton<TxnStatus>(
              tooltip: l.txnSetStatus,
              enabled: enabled,
              icon: const Icon(Icons.check_circle_outline),
              onSelected: onStatus,
              itemBuilder: (_) => [
                for (final s in TxnStatus.values)
                  PopupMenuItem(value: s, child: Text(TxnLabels.status(l, s))),
              ],
            ),
            IconButton(
              tooltip: l.commonDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: enabled ? onDelete : null,
            ),
            PopupMenuButton<String>(
              tooltip: l.txnMoreActions,
              enabled: enabled,
              onSelected: (v) => switch (v) {
                'date' => onDate(),
                'account' => onAccount(),
                'tags' => onTags?.call(),
                _ => null,
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'date', child: Text(l.txnSetDate)),
                PopupMenuItem(value: 'account', child: Text(l.txnSetAccount)),
                if (onTags != null)
                  PopupMenuItem(value: 'tags', child: Text(l.txnAddTags)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedFilterChips extends ConsumerWidget {
  const _SavedFilterChips({required this.activeId, required this.padding});

  final String? activeId;
  final EdgeInsets padding;

  Future<void> _menu(
    BuildContext context,
    WidgetRef ref,
    SavedFilter f,
    Offset? at,
  ) async {
    final l = context.l10n;
    final repo = ref.read(savedFiltersRepositoryProvider);
    final settings = ref.read(settingsProvider);
    final isDefault = settings.get(TransactionSettings.defaultFilterId) == f.id;
    final current = ref.read(txnScreenProvider).filter;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final box = context.findRenderObject() as RenderBox?;
    final origin = at ?? box?.localToGlobal(Offset.zero) ?? Offset.zero;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(origin.dx, origin.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(value: 'rename', child: Text(l.txnRename)),
        if (!current.isEmpty)
          PopupMenuItem(value: 'update', child: Text(l.txnUpdateFilter)),
        PopupMenuItem(
          value: 'default',
          child: Text(isDefault ? l.txnUnsetDefault : l.txnSetDefault),
        ),
        PopupMenuItem(value: 'delete', child: Text(l.commonDelete)),
      ],
    );
    if (!context.mounted || choice == null) return;
    switch (choice) {
      case 'rename':
        final name = await promptName(
          context,
          title: l.txnRename,
          label: l.txnFilterName,
          initial: f.name,
        );
        if (name != null) await repo.update(f.id, name: name);
      case 'update':
        await repo.update(f.id, filter: current);
        ref.read(txnScreenProvider.notifier).markSaved(f.id);
        if (context.mounted) showInfoSnackBar(context, l.txnFilterUpdated);
      case 'default':
        await ref
            .read(settingsProvider.notifier)
            .set(TransactionSettings.defaultFilterId, isDefault ? null : f.id);
      case 'delete':
        final messenger = ScaffoldMessenger.maybeOf(context);
        await repo.delete(f.id);
        if (activeId == f.id) ref.read(txnScreenProvider.notifier).clear();
        showUndoSnackBar(
          messenger,
          l.txnFilterDeleted,
          undoLabel: l.commonUndo,
          onUndo: () => repo.restore(f.id),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final filters = ref.watch(savedFiltersProvider).value ?? const [];
    if (filters.isEmpty) return const SizedBox.shrink();
    final defaultId = ref.watch(
      settingsProvider.select(
        (s) => s.get(TransactionSettings.defaultFilterId),
      ),
    );
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: Space.xs),
            child: Center(
              child: ChoiceChip(
                label: Text(l.txnAllTransactions),
                selected: activeId == null,
                onSelected: (_) => ref.read(txnScreenProvider.notifier).clear(),
              ),
            ),
          ),
          for (final f in filters)
            Padding(
              padding: const EdgeInsets.only(right: Space.xs),
              child: Center(
                child: Builder(
                  builder: (chipContext) => GestureDetector(
                    onLongPress: () => _menu(chipContext, ref, f, null),
                    onSecondaryTapDown: (d) =>
                        _menu(chipContext, ref, f, d.globalPosition),
                    child: ChoiceChip(
                      avatar: defaultId == f.id
                          ? const Icon(Icons.star_outline, size: 18)
                          : null,
                      label: Text(f.name),
                      selected: activeId == f.id,
                      onSelected: (sel) => sel
                          ? ref.read(txnScreenProvider.notifier).applySaved(f)
                          : ref.read(txnScreenProvider.notifier).clear(),
                    ),
                  ),
                ),
              ),
            ),
          Center(
            child: IconButton(
              tooltip: l.txnSavedFilters,
              icon: const Icon(Icons.more_horiz),
              onPressed: () => context.push('/transactions/filters'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends ConsumerWidget {
  const _SummaryLine({
    required this.filter,
    required this.wide,
    required this.padding,
  });

  final TxnFilter filter;
  final bool wide;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cs = context.colors;
    final fin = context.finance;
    final totals = ref.watch(txnTotalsProvider(filter)).value;
    final settings = ref.watch(settingsProvider);
    final sort = settings.get(TransactionSettings.sort);
    final grouping = settings.get(TransactionSettings.grouping);
    final style = context.text.bodySmall?.copyWith(color: cs.onSurfaceVariant);
    Widget dot(Color c) => Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
    );
    final view = [
      if (groupingApplies(grouping, sort)) TxnLabels.grouping(l, grouping),
      TxnLabels.sort(l, sort),
    ].join(' · ');
    return Padding(
      padding: padding,
      child: DefaultTextStyle.merge(
        style: style,
        child: Wrap(
          spacing: wide ? Space.lg : 14,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(l.txnEntries(totals?.count ?? 0)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                dot(fin.income),
                const SizedBox(width: 6),
                Text('${l.txnIn} '),
                AmountText(
                  totals?.inMinor ?? 0,
                  explicitPlus: false,
                  style: style?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: fin.income,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                dot(fin.expenseFill),
                const SizedBox(width: 6),
                Text('${l.txnOut} '),
                AmountText(
                  (totals?.outMinor ?? 0).abs(),
                  colored: false,
                  style: style?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: fin.expense,
                  ),
                ),
              ],
            ),
            if (wide)
              InkWell(
                borderRadius: BorderRadius.circular(Radii.sm),
                onTap: () => showViewOptions(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Text(view),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RunningBalanceHint extends ConsumerWidget {
  const _RunningBalanceHint({
    required this.filter,
    required this.onChooseAccount,
  });

  final TxnFilter filter;
  final VoidCallback onChooseAccount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cs = context.colors;
    final settings = ref.watch(settingsProvider);
    final wanted =
        settings.get(TransactionSettings.runningBalance) ||
        settings.get(TransactionSettings.visibleColumns).contains('balance');
    final sort = settings.get(TransactionSettings.sort);
    if (!wanted || TxnListRepository.runningBalanceApplies(filter, sort)) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.xs),
      padding: const EdgeInsets.fromLTRB(Space.sm, 4, 4, 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: Space.xs),
          Expanded(
            child: Text(
              l.txnRunningBalanceHint,
              style: context.text.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          if (filter.accountIds.length != 1)
            TextButton(
              onPressed: onChooseAccount,
              child: Text(l.txnChooseAccountAction),
            ),
        ],
      ),
    );
  }
}

/// Sort, grouping and running balance (Settings › Transactions), editable
/// right from the list.
Future<void> showViewOptions(BuildContext context) =>
    showAdaptiveSheet<void>(context, builder: (_) => const _ViewOptions());

class _ViewOptions extends ConsumerWidget {
  const _ViewOptions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final sort = s.get(TransactionSettings.sort);
    final grouping = s.get(TransactionSettings.grouping);
    final applies = groupingApplies(TxnGrouping.day, sort);
    Widget label(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, 4),
      child: Text(
        t,
        style: context.text.bodySmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          label(l.setSort),
          RadioGroup<TxnSort>(
            groupValue: sort,
            onChanged: (v) {
              if (v != null) unawaited(n.set(TransactionSettings.sort, v));
            },
            child: Column(
              children: [
                for (final v in TxnSort.values)
                  RadioListTile<TxnSort>(
                    value: v,
                    title: Text(TxnLabels.sort(l, v)),
                  ),
              ],
            ),
          ),
          label(l.setGrouping),
          if (!applies)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.lg),
              child: Text(
                l.txnGroupingOffHint,
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
          RadioGroup<TxnGrouping>(
            groupValue: grouping,
            onChanged: (v) {
              if (v != null) unawaited(n.set(TransactionSettings.grouping, v));
            },
            child: Column(
              children: [
                for (final v in TxnGrouping.values)
                  RadioListTile<TxnGrouping>(
                    value: v,
                    enabled: applies,
                    title: Text(TxnLabels.grouping(l, v)),
                  ),
              ],
            ),
          ),
          SwitchListTile(
            title: Text(l.setRunningBalance),
            subtitle: Text(l.txnRunningBalanceHint),
            value: s.get(TransactionSettings.runningBalance),
            onChanged: (v) =>
                unawaited(n.set(TransactionSettings.runningBalance, v)),
          ),
          const SizedBox(height: Space.md),
        ],
      ),
    );
  }
}
