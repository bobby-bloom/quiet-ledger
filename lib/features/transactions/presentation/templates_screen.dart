import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/amount_text.dart';
import 'package:personal_finance/app/ui/app_icons.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/ledger_repository.dart';
import 'package:personal_finance/core/ledger/lookups.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/features/rules/domain/rule_service.dart';
import 'package:personal_finance/features/transactions/data/templates_repository.dart';
import 'package:personal_finance/features/transactions/data/txn_actions.dart';
import 'package:personal_finance/features/transactions/presentation/quick_add.dart';
import 'package:personal_finance/features/transactions/presentation/txn_ui_actions.dart';

/// Creates a transaction from [t] dated today in one tap (rules apply as
/// for any new entry) and offers undo. Returns the new id, or null when the
/// template is incomplete.
Future<String?> postTemplate(
  BuildContext context,
  WidgetRef ref,
  TxnTemplate t,
) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final accounts = ref.read(accountMapProvider);
  var draft = templateDraft(t);
  if (draft == null ||
      accounts[draft.accountId] == null ||
      (draft.isTransfer && accounts[draft.transferAccountId] == null)) {
    messenger?.showSnackBar(SnackBar(content: Text(l.txnTemplateInvalid)));
    return null;
  }
  draft = draft.copyWith(date: dateOnly(DateTime.now()));
  draft = await ref
      .read(ruleServiceProvider)
      .apply(draft, trigger: RuleTrigger.entry);
  if (draft.validate().isNotEmpty) {
    messenger?.showSnackBar(SnackBar(content: Text(l.txnTemplateInvalid)));
    return null;
  }
  final id = await ref.read(ledgerRepositoryProvider).create(draft);
  final actions = ref.read(txnActionsProvider);
  showUndoSnackBar(
    messenger,
    l.txnTemplatePosted(t.name),
    undoLabel: l.commonUndo,
    onUndo: () async {
      await actions.delete([id]);
    },
  );
  return id;
}

/// More › Templates: favourite transactions for one-tap entry.
class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(templatesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.moreTemplates),
        actions: [
          IconButton(
            tooltip: l.txnNewTemplate,
            icon: const Icon(Icons.add),
            onPressed: () => showTemplateEditor(context),
          ),
        ],
      ),
      body: AsyncView<List<TxnTemplate>>(
        value: async,
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.bookmarks_outlined,
              message: l.txnTemplatesEmpty,
              actionLabel: l.txnNewTemplate,
              onAction: () => showTemplateEditor(context),
            );
          }
          final repo = ref.read(templatesRepositoryProvider);
          return ReorderableListView(
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.only(bottom: Space.xxxl),
            onReorderItem: (from, to) {
              final ids = [for (final t in list) t.id];
              final id = ids.removeAt(from);
              ids.insert(to, id);
              unawaited(repo.reorder(ids));
            },
            children: [
              for (var i = 0; i < list.length; i++)
                _TemplateRow(key: ValueKey(list[i].id), t: list[i], index: i),
            ],
          );
        },
      ),
    );
  }
}

class _TemplateRow extends ConsumerWidget {
  const _TemplateRow({required this.t, required this.index, super.key});

  final TxnTemplate t;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final accounts = ref.watch(accountMapProvider);
    final categories = ref.watch(categoryMapProvider);
    final draft = templateDraft(t);
    final repo = ref.read(templatesRepositoryProvider);
    final category = draft == null ? null : categories[draft.categoryId];
    final subtitle = draft == null
        ? l.txnTemplateInvalid
        : [
            if (draft.isTransfer)
              '${accounts[draft.accountId]?.name ?? '?'} → '
                  '${accounts[draft.transferAccountId]?.name ?? '?'}'
            else ...[
              if (draft.isSplit)
                l.txnSplitCount(draft.splits.length)
              else
                category?.name ?? l.txnUncategorized,
              accounts[draft.accountId]?.name ?? l.txnUnknownAccount,
            ],
          ].join(' · ');
    return ListTile(
      leading: IconTile(
        icon: draft?.isTransfer ?? false
            ? Icons.swap_horiz
            : AppIcons.of(category?.icon, fallback: Icons.bookmark_outline),
        color: category?.color == null ? null : Color(category!.color!),
      ),
      title: Text(t.name),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: draft == null
          ? () => showTemplateEditor(context, template: t)
          : () => showQuickAdd(context, initial: _fillIn(draft)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (draft != null && draft.amountMinor != 0)
            Padding(
              padding: const EdgeInsets.only(right: Space.xs),
              child: AmountText(
                draft.amountMinor,
                type: draft.type,
                style: context.text.titleSmall,
              ),
            ),
          if (draft != null)
            FilledButton.tonal(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () => postTemplate(context, ref, t),
              child: Text(l.txnTemplateAddNow),
            ),
          PopupMenuButton<String>(
            tooltip: l.txnMoreActions,
            onSelected: (v) async {
              switch (v) {
                case 'fill':
                  if (draft != null) {
                    await showQuickAdd(context, initial: _fillIn(draft));
                  }
                case 'edit':
                  await showTemplateEditor(context, template: t);
                case 'rename':
                  final name = await promptName(
                    context,
                    title: l.txnRename,
                    label: l.txnTemplateName,
                    initial: t.name,
                  );
                  if (name != null) await repo.update(t.id, name: name);
                case 'delete':
                  final messenger = ScaffoldMessenger.maybeOf(context);
                  await repo.delete(t.id);
                  showUndoSnackBar(
                    messenger,
                    l.txnTemplateDeleted,
                    undoLabel: l.commonUndo,
                    onUndo: () => repo.restore(t.id),
                  );
              }
            },
            itemBuilder: (_) => [
              if (draft != null)
                PopupMenuItem(value: 'fill', child: Text(l.txnTemplateFillIn)),
              PopupMenuItem(value: 'edit', child: Text(l.txnEditTemplate)),
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

  static TxnDraft _fillIn(TxnDraft d) =>
      d.copyWith(date: dateOnly(DateTime.now()));
}
