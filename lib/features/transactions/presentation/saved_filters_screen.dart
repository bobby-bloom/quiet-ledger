import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/transactions/data/saved_filters_repository.dart';
import 'package:personal_finance/features/transactions/presentation/providers.dart';
import 'package:personal_finance/features/transactions/presentation/txn_ui_actions.dart';

/// Saved filters ("smart lists"): open, rename, reorder, delete and choose
/// the default filter of the transaction list. Route
/// `/transactions/filters` (also Settings › Transactions › Default filter).
class SavedFiltersScreen extends ConsumerWidget {
  const SavedFiltersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(savedFiltersProvider);
    final defaultId = ref.watch(
      settingsProvider.select(
        (s) => s.get(TransactionSettings.defaultFilterId),
      ),
    );
    final repo = ref.read(savedFiltersRepositoryProvider);
    final settings = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l.txnSavedFilters)),
      body: AsyncView<List<SavedFilter>>(
        value: async,
        data: (filters) {
          if (filters.isEmpty) {
            return EmptyState(
              icon: Icons.bookmarks_outlined,
              message: l.txnNoSavedFilters,
              actionLabel: l.navTransactions,
              onAction: () => context.go('/transactions'),
            );
          }
          return RadioGroup<String>(
            groupValue: defaultId ?? '',
            onChanged: (v) => unawaited(
              settings.set(
                TransactionSettings.defaultFilterId,
                v == null || v.isEmpty ? null : v,
              ),
            ),
            child: ReorderableListView(
              buildDefaultDragHandles: false,
              header: RadioListTile<String>(
                value: '',
                title: Text(l.txnNoDefaultFilter),
                subtitle: Text(l.setDefaultFilter),
              ),
              onReorderItem: (from, to) {
                final ids = [for (final f in filters) f.id];
                final id = ids.removeAt(from);
                ids.insert(to, id);
                unawaited(repo.reorder(ids));
              },
              children: [
                for (var i = 0; i < filters.length; i++)
                  _FilterRow(
                    key: ValueKey(filters[i].id),
                    filter: filters[i],
                    index: i,
                    isDefault: filters[i].id == defaultId,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FilterRow extends ConsumerWidget {
  const _FilterRow({
    required this.filter,
    required this.index,
    required this.isDefault,
    super.key,
  });

  final SavedFilter filter;
  final int index;
  final bool isDefault;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final repo = ref.read(savedFiltersRepositoryProvider);
    final count = ref.watch(txnCountProvider(decodeSavedFilter(filter))).value;
    return ListTile(
      leading: Radio<String>(value: filter.id),
      title: Text(filter.name),
      subtitle: count == null ? null : Text(l.txnEntries(count)),
      onTap: () {
        ref.read(txnScreenProvider.notifier).applySaved(filter);
        context.go('/transactions');
      },
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PopupMenuButton<String>(
            tooltip: l.txnMoreActions,
            onSelected: (v) async {
              switch (v) {
                case 'rename':
                  final name = await promptName(
                    context,
                    title: l.txnRename,
                    label: l.txnFilterName,
                    initial: filter.name,
                  );
                  if (name != null) await repo.update(filter.id, name: name);
                case 'delete':
                  final messenger = ScaffoldMessenger.maybeOf(context);
                  if (isDefault) {
                    await ref
                        .read(settingsProvider.notifier)
                        .set(TransactionSettings.defaultFilterId, null);
                  }
                  await repo.delete(filter.id);
                  showUndoSnackBar(
                    messenger,
                    l.txnFilterDeleted,
                    undoLabel: l.commonUndo,
                    onUndo: () => repo.restore(filter.id),
                  );
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'rename', child: Text(l.txnRename)),
              PopupMenuItem(value: 'delete', child: Text(l.commonDelete)),
            ],
          ),
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(Icons.drag_handle),
            ),
          ),
        ],
      ),
    );
  }
}
