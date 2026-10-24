import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/lookups.dart';
import 'package:personal_finance/features/accounts/data/accounts_repository.dart';
import 'package:personal_finance/features/accounts/domain/account_grouping.dart';
import 'package:personal_finance/features/categories/presentation/appearance_pickers.dart';

/// `/accounts/groups`: rename, reorder and delete account groups.
class AccountGroupsScreen extends ConsumerStatefulWidget {
  const AccountGroupsScreen({super.key});

  @override
  ConsumerState<AccountGroupsScreen> createState() =>
      _AccountGroupsScreenState();
}

class _AccountGroupsScreenState extends ConsumerState<AccountGroupsScreen> {
  List<AccountGroup>? _order;

  Future<void> _add() async {
    final l = context.l10n;
    final name = await promptText(
      context,
      title: l.accountsGroupAdd,
      label: l.accountsGroupName,
      confirmLabel: l.commonAdd,
    );
    if (name == null) return;
    await ref.read(accountsRepositoryProvider).createGroup(name);
  }

  Future<void> _rename(AccountGroup g) async {
    final l = context.l10n;
    final name = await promptText(
      context,
      title: l.accountsGroupRename,
      label: l.accountsGroupName,
      initial: g.name,
    );
    if (name == null || name == g.name) return;
    await ref.read(accountsRepositoryProvider).renameGroup(g.id, name);
  }

  Future<void> _delete(AccountGroup g) async {
    final l = context.l10n;
    final ok = await confirmDialog(
      context,
      title: l.commonDeleteConfirm(g.name),
      message: l.accountsGroupDeleteMessage,
    );
    if (!ok) return;
    await ref.read(accountsRepositoryProvider).deleteGroup(g.id);
    if (mounted) showSnack(context, l.accountsGroupDeleted);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final async = ref.watch(accountGroupsProvider);
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final counts = <String, int>{};
    for (final a in accounts) {
      if (a.groupId != null && !a.archived) {
        counts[a.groupId!] = (counts[a.groupId!] ?? 0) + 1;
      }
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(l.accountsGroupsTitle),
        actions: [
          IconButton(
            tooltip: l.accountsGroupAdd,
            icon: const Icon(Icons.add),
            onPressed: _add,
          ),
        ],
      ),
      body: AsyncView(
        value: async,
        data: (groups) {
          if (groups.isEmpty) {
            return EmptyState(
              icon: Icons.folder_outlined,
              message: l.accountsGroupsEmpty,
              actionLabel: l.accountsGroupAdd,
              onAction: _add,
            );
          }
          final ids = groups.map((g) => g.id).toList();
          if (_order == null ||
              _order!.length != groups.length ||
              !_order!.every((g) => ids.contains(g.id))) {
            _order = groups;
          } else {
            // Pick up renames.
            final byId = {for (final g in groups) g.id: g};
            _order = [for (final g in _order!) byId[g.id]!];
          }
          final order = _order!;
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ReorderableListView.builder(
                padding: const EdgeInsets.only(bottom: Space.xxxl),
                header: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.listInset,
                    Space.xs,
                    Space.listInset,
                    Space.sm,
                  ),
                  child: Text(
                    l.accountsGroupsHint,
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ),
                itemCount: order.length,
                onReorderItem: (from, to) async {
                  final next = moveItem(order, from, to);
                  setState(() => _order = next);
                  await ref.read(accountsRepositoryProvider).reorderGroups([
                    for (final g in next) g.id,
                  ]);
                },
                itemBuilder: (context, i) {
                  final g = order[i];
                  return ListTile(
                    key: ValueKey(g.id),
                    contentPadding: const EdgeInsets.only(
                      left: Space.listInset,
                      right: Space.xxxl,
                    ),
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(g.name),
                    subtitle: Text(l.accountsGroupCount(counts[g.id] ?? 0)),
                    onTap: () => _rename(g),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: l.accountsGroupRename,
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _rename(g),
                        ),
                        IconButton(
                          tooltip: l.commonDelete,
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(g),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
