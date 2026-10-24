import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/app_icons.dart';
import 'package:personal_finance/app/ui/pickers.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/lookups.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/accounts/domain/account_grouping.dart';
import 'package:personal_finance/features/categories/data/categories_repository.dart';
import 'package:personal_finance/features/categories/domain/drafts.dart';
import 'package:personal_finance/features/categories/presentation/category_editor.dart';

/// `/more/categories`: the two-level category hierarchy with Expense and
/// Income tabs.
class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this)
    ..addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });
  bool _reordering = false;
  bool _showArchived = false;

  CategoryKind get _kind =>
      _tabs.index == 0 ? CategoryKind.expense : CategoryKind.income;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _seed() async {
    final set = ref.read(settingsProvider).get(CategorySettings.defaultSet);
    await ref.read(categoriesRepositoryProvider).seedDefaults(set);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final async = ref.watch(categoriesProvider);
    final all = async.value ?? const <Category>[];
    final hasArchived = all.any((c) => c.archived);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _reordering ? l.categoriesReorder : l.categoriesTitle,
          style: context.text.titleLarge,
        ),
        actions: _reordering
            ? [
                TextButton(
                  onPressed: () => setState(() => _reordering = false),
                  child: Text(l.commonDone),
                ),
                const SizedBox(width: Space.xs),
              ]
            : [
                IconButton(
                  tooltip: l.categoriesAdd,
                  icon: const Icon(Icons.add),
                  onPressed: () =>
                      showCategoryEditor(context, ref, kind: _kind),
                ),
                PopupMenuButton<String>(
                  tooltip: l.categoriesMoreActions,
                  onSelected: (v) {
                    switch (v) {
                      case 'reorder':
                        setState(() => _reordering = true);
                      case 'archived':
                        setState(() => _showArchived = !_showArchived);
                      case 'defaults':
                        unawaited(_seed());
                    }
                  },
                  itemBuilder: (ctx) => [
                    if (all.length > 1)
                      PopupMenuItem(
                        value: 'reorder',
                        child: ListTile(
                          leading: const Icon(Icons.swap_vert),
                          title: Text(l.categoriesReorder),
                        ),
                      ),
                    if (hasArchived)
                      PopupMenuItem(
                        value: 'archived',
                        child: ListTile(
                          leading: const Icon(Icons.inventory_2_outlined),
                          title: Text(
                            _showArchived
                                ? l.categoriesHideArchived
                                : l.categoriesShowArchived,
                          ),
                        ),
                      ),
                    if (all.isEmpty)
                      PopupMenuItem(
                        value: 'defaults',
                        child: ListTile(
                          leading: const Icon(Icons.auto_awesome_outlined),
                          title: Text(l.categoriesAddDefaults),
                        ),
                      ),
                  ],
                ),
              ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: l.typeExpense),
            Tab(text: l.typeIncome),
          ],
        ),
      ),
      body: AsyncView(
        value: async,
        data: (cats) {
          if (cats.isEmpty) {
            return _EmptyCategories(
              onDefaults: _seed,
              onAdd: () => showCategoryEditor(context, ref, kind: _kind),
            );
          }
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: TabBarView(
                controller: _tabs,
                children: [
                  for (final kind in CategoryKind.values)
                    if (_reordering)
                      _ReorderCategories(kind: kind, all: cats)
                    else
                      CategoryTreeList(
                        kind: kind,
                        all: cats,
                        showArchived: _showArchived,
                      ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyCategories extends StatelessWidget {
  const _EmptyCategories({required this.onDefaults, required this.onAdd});

  final VoidCallback onDefaults;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.category_outlined,
              size: 40,
              color: context.colors.onSurfaceVariant,
            ),
            const SizedBox(height: Space.sm),
            Text(
              l.categoriesEmpty,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Space.md),
            FilledButton(
              onPressed: onDefaults,
              child: Text(l.categoriesAddDefaults),
            ),
            const SizedBox(height: Space.xs),
            TextButton(onPressed: onAdd, child: Text(l.categoriesAdd)),
          ],
        ),
      ),
    );
  }
}

/// Parent categories with their subcategories, indented.
class CategoryTreeList extends ConsumerWidget {
  const CategoryTreeList({
    required this.kind,
    required this.all,
    super.key,
    this.showArchived = false,
  });

  final CategoryKind kind;
  final List<Category> all;
  final bool showArchived;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final usage = ref.watch(categoryUsageCountsProvider).value ?? const {};
    final tree = categoryTree(all, kind: kind, includeArchived: showArchived);
    if (tree.isEmpty) {
      return EmptyState(
        icon: Icons.category_outlined,
        message: kind == CategoryKind.expense
            ? l.categoriesEmptyExpense
            : l.categoriesEmptyIncome,
        actionLabel: l.categoriesAdd,
        onAction: () => showCategoryEditor(context, ref, kind: kind),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(top: Space.xs, bottom: Space.xxxl * 2),
      children: [
        for (final (parent, children) in tree) ...[
          _CategoryRow(
            category: parent,
            depth: 0,
            subtitle: [
              if (children.isNotEmpty) l.categoriesSubCount(children.length),
              l.categoriesUsage(usage[parent.id] ?? 0),
            ].join(' · '),
          ),
          for (final c in children)
            _CategoryRow(
              category: c,
              depth: 1,
              subtitle: l.categoriesUsage(usage[c.id] ?? 0),
            ),
          const Divider(height: 1, indent: Space.listInset),
        ],
      ],
    );
  }
}

class _CategoryRow extends ConsumerWidget {
  const _CategoryRow({
    required this.category,
    required this.depth,
    required this.subtitle,
  });

  final Category category;
  final int depth;
  final String subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = category;
    final color = c.color == null ? null : Color(c.color!);
    final repo = ref.read(categoriesRepositoryProvider);
    final overrides = <String>[
      if (c.rolloverOverride != null)
        rolloverLabel(
          l,
          parseRollover(c.rolloverOverride) ?? RolloverMode.none,
        ),
      if (c.warnThresholdOverride != null) '${c.warnThresholdOverride} %',
    ];
    return Opacity(
      opacity: c.archived ? 0.6 : 1,
      child: ListTile(
        contentPadding: EdgeInsets.only(
          left: Space.listInset + depth * 28,
          right: Space.xxs,
        ),
        minVerticalPadding: Space.xs,
        leading: IconTile(
          icon: AppIcons.of(c.icon),
          color: color,
          size: depth == 0 ? 40 : 32,
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                c.name,
                overflow: TextOverflow.ellipsis,
                style: depth == 0 ? context.text.bodyLarge : null,
              ),
            ),
            if (c.archived) ...[
              const SizedBox(width: Space.xs),
              StatusBadge(l.categoriesArchived),
            ],
          ],
        ),
        subtitle: Text(
          [subtitle, ...overrides].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () => showCategoryEditor(context, ref, category: c),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: c.favourite
                  ? l.categoriesUnfavourite
                  : l.categoriesFavourite,
              isSelected: c.favourite,
              icon: const Icon(Icons.star_border),
              selectedIcon: Icon(
                Icons.star,
                color: context.finance.warningFill,
              ),
              onPressed: () => repo.setFavourite(c.id, favourite: !c.favourite),
            ),
            PopupMenuButton<String>(
              tooltip: l.categoriesMoreActions,
              onSelected: (v) async {
                switch (v) {
                  case 'edit':
                    await showCategoryEditor(context, ref, category: c);
                  case 'sub':
                    await showCategoryEditor(context, ref, parentId: c.id);
                  case 'merge':
                    await mergeCategoryFlow(context, ref, c);
                  case 'archive':
                    await repo.setArchived(c.id, archived: !c.archived);
                  case 'delete':
                    await deleteCategoryFlow(context, ref, c);
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(value: 'edit', child: Text(l.commonEdit)),
                if (c.parentId == null)
                  PopupMenuItem(value: 'sub', child: Text(l.categoriesAddSub)),
                PopupMenuItem(
                  value: 'merge',
                  child: Text(l.categoriesMergeAction),
                ),
                PopupMenuItem(
                  value: 'archive',
                  child: Text(
                    c.archived ? l.categoriesUnarchive : l.categoriesArchive,
                  ),
                ),
                PopupMenuItem(value: 'delete', child: Text(l.commonDelete)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Reorder mode for one kind: top-level categories; each parent offers a
/// sheet to reorder its subcategories.
class _ReorderCategories extends ConsumerStatefulWidget {
  const _ReorderCategories({required this.kind, required this.all});

  final CategoryKind kind;
  final List<Category> all;

  @override
  ConsumerState<_ReorderCategories> createState() => _ReorderCategoriesState();
}

class _ReorderCategoriesState extends ConsumerState<_ReorderCategories> {
  List<String>? _order;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tree = categoryTree(widget.all, kind: widget.kind);
    final byId = {for (final (p, _) in tree) p.id: p};
    final children = {for (final (p, ch) in tree) p.id: ch};
    final ids = [for (final (p, _) in tree) p.id];
    if (_order == null ||
        _order!.length != ids.length ||
        !_order!.every(byId.containsKey)) {
      _order = ids;
    }
    final order = _order!;
    return ReorderableListView.builder(
      padding: const EdgeInsets.only(bottom: Space.xxxl),
      header: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.listInset,
          Space.sm,
          Space.listInset,
          Space.xs,
        ),
        child: Text(
          l.categoriesReorderHint,
          style: context.text.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ),
      itemCount: order.length,
      onReorderItem: (from, to) async {
        final next = moveItem(order, from, to);
        setState(() => _order = next);
        await ref.read(categoriesRepositoryProvider).reorder(next);
      },
      itemBuilder: (context, i) {
        final c = byId[order[i]]!;
        final subs = children[c.id] ?? const <Category>[];
        return ListTile(
          key: ValueKey(c.id),
          contentPadding: const EdgeInsets.only(
            left: Space.listInset,
            right: Space.xxxl,
          ),
          leading: IconTile(
            icon: AppIcons.of(c.icon),
            color: c.color == null ? null : Color(c.color!),
          ),
          title: Text(c.name),
          subtitle: subs.isEmpty
              ? null
              : Text(l.categoriesSubCount(subs.length)),
          trailing: subs.length > 1
              ? IconButton(
                  tooltip: l.categoriesReorderChildren,
                  icon: const Icon(Icons.low_priority),
                  onPressed: () => showAdaptiveSheet<void>(
                    context,
                    builder: (_) => _ReorderChildrenSheet(parent: c),
                  ),
                )
              : null,
        );
      },
    );
  }
}

class _ReorderChildrenSheet extends ConsumerStatefulWidget {
  const _ReorderChildrenSheet({required this.parent});

  final Category parent;

  @override
  ConsumerState<_ReorderChildrenSheet> createState() =>
      _ReorderChildrenSheetState();
}

class _ReorderChildrenSheetState extends ConsumerState<_ReorderChildrenSheet> {
  List<Category>? _order;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final all = ref.watch(categoriesProvider).value ?? const <Category>[];
    final subs = [
      for (final c in all)
        if (c.parentId == widget.parent.id && !c.archived) c,
    ];
    final order = _order ??= subs;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.xl,
            Space.lg,
            Space.xs,
            Space.xs,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.parent.name,
                  style: context.text.titleMedium,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l.commonDone),
              ),
            ],
          ),
        ),
        Flexible(
          child: ReorderableListView.builder(
            shrinkWrap: true,
            itemCount: order.length,
            onReorderItem: (from, to) async {
              final next = moveItem(order, from, to);
              setState(() => _order = next);
              await ref.read(categoriesRepositoryProvider).reorder([
                for (final c in next) c.id,
              ]);
            },
            itemBuilder: (context, i) => ListTile(
              key: ValueKey(order[i].id),
              contentPadding: const EdgeInsets.only(
                left: Space.listInset,
                right: Space.xxxl,
              ),
              leading: IconTile(
                icon: AppIcons.of(order[i].icon),
                color: order[i].color == null ? null : Color(order[i].color!),
                size: 32,
              ),
              title: Text(order[i].name),
            ),
          ),
        ),
        const SizedBox(height: Space.md),
      ],
    );
  }
}
