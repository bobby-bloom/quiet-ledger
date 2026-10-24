import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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
import 'package:personal_finance/core/ledger/ledger_repository.dart';
import 'package:personal_finance/core/ledger/lookups.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/rules/rules_routes.dart';
import 'package:personal_finance/features/transactions/data/attachments_repository.dart';
import 'package:personal_finance/features/transactions/presentation/providers.dart';
import 'package:personal_finance/features/transactions/presentation/quick_add.dart';
import 'package:personal_finance/features/transactions/presentation/quick_add_extras.dart';
import 'package:personal_finance/features/transactions/presentation/transaction_tile.dart';
import 'package:personal_finance/features/transactions/presentation/txn_labels.dart';
import 'package:personal_finance/features/transactions/presentation/txn_ui_actions.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';
import 'package:share_plus/share_plus.dart';

/// Full-screen detail (compact layouts, `/transactions/:id`).
class TransactionDetailScreen extends ConsumerWidget {
  const TransactionDetailScreen({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final detail = ref.watch(txnDetailProvider(id)).value;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.txnDetailTitle),
        actions: [
          if (detail != null) ...[
            IconButton(
              tooltip: l.commonEdit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => showQuickAdd(context, editId: id),
            ),
            IconButton(
              tooltip: l.txnDuplicate,
              icon: const Icon(Icons.copy_outlined),
              onPressed: () => duplicateInQuickAdd(context, ref, id),
            ),
            IconButton(
              tooltip: l.commonDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final router = GoRouter.maybeOf(context);
                final ok = await deleteTransactionsWithUndo(context, ref, [id]);
                if (ok && router != null && router.canPop()) router.pop();
              },
            ),
          ],
        ],
      ),
      body: TransactionDetailView(id: id),
    );
  }
}

/// Transaction details: amount, status, category or splits, transfer
/// accounts, tags, custom fields, note, attachments and origin; actions
/// edit, duplicate, delete, save as template. Used as the right pane on
/// medium/expanded layouts ([pane] = true) and inside the detail screen.
class TransactionDetailView extends ConsumerWidget {
  const TransactionDetailView({
    required this.id,
    super.key,
    this.pane = false,
    this.onClose,
  });

  final String id;
  final bool pane;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(txnDetailProvider(id));
    return AsyncView<TxnDetail?>(
      value: async,
      data: (d) {
        if (d == null) {
          return EmptyState(
            icon: Icons.search_off,
            message: l.txnNotFound,
            actionLabel: pane ? l.commonClose : null,
            onAction: onClose,
          );
        }
        return _DetailBody(detail: d, pane: pane, onClose: onClose);
      },
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.detail, required this.pane, this.onClose});

  final TxnDetail detail;
  final bool pane;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cs = context.colors;
    final fin = context.finance;
    final settings = ref.watch(settingsProvider);
    final accounts = ref.watch(accountMapProvider);
    final categories = ref.watch(categoryMapProvider);
    final tags = ref.watch(tagMapProvider);
    final defs = ref.watch(customFieldDefsProvider).value ?? const [];
    final dates = ref.watch(dateFormatsProvider);
    final t = detail.txn;
    final account = accounts[t.accountId]?.name ?? l.txnUnknownAccount;
    final peerAccount = detail.peer == null
        ? null
        : accounts[detail.peer!.accountId]?.name ?? l.txnUnknownAccount;

    final String title;
    if ((t.payee ?? '').trim().isNotEmpty) {
      title = t.payee!.trim();
    } else if (detail.isTransfer) {
      title = t.amountMinor > 0
          ? l.txnTransferFrom(peerAccount!)
          : l.txnTransferTo(peerAccount!);
    } else if ((t.note ?? '').trim().isNotEmpty) {
      title = t.note!.trim();
    } else {
      title = categories[t.categoryId]?.name ?? l.txnNoPayee;
    }
    final heroColor = switch (t.type) {
      TxnType.expense => fin.expense,
      _ => null,
    };
    final tagsOn = settings.moduleEnabled(AppModule.tags);
    final cfOn = settings.moduleEnabled(AppModule.customFields);
    final attachOn = settings.moduleEnabled(AppModule.attachments);
    final sectionStyle = context.text.bodySmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: cs.onSurface,
    );

    Widget section(String label, Widget child) => Padding(
      padding: const EdgeInsets.only(top: Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: sectionStyle),
          const SizedBox(height: Space.xs),
          child,
        ],
      ),
    );

    Widget infoRow(IconData icon, String text, {Widget? trailing}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: cs.onSurfaceVariant),
          const SizedBox(width: Space.sm),
          Expanded(child: Text(text, style: context.text.bodyMedium)),
          ?trailing,
        ],
      ),
    );

    final children = <Widget>[
      if (pane)
        Row(
          children: [
            Expanded(
              child: Text(
                l.txnDetailTitle.toUpperCase(),
                style: context.text.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            IconButton(
              tooltip: l.txnDuplicate,
              icon: const Icon(Icons.copy_outlined),
              onPressed: () => duplicateInQuickAdd(context, ref, t.id),
            ),
            IconButton(
              tooltip: l.commonDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await deleteTransactionsWithUndo(context, ref, [
                  t.id,
                ]);
                if (ok) onClose?.call();
              },
            ),
            if (onClose != null)
              IconButton(
                tooltip: l.txnCloseDetail,
                icon: const Icon(Icons.close),
                onPressed: onClose,
              ),
          ],
        ),
      const SizedBox(height: Space.xs),
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: Space.sm,
        runSpacing: Space.xs,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: context.text.titleLarge?.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 2),
                Text(
                  '${dates.medium(t.date)} · $account',
                  style: context.text.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          AmountText(
            t.amountMinor,
            type: t.type,
            style: context.text.headlineMedium?.copyWith(
              fontSize: 30,
              color: heroColor,
            ),
          ),
        ],
      ),
      const SizedBox(height: Space.md),
      Text(l.fieldStatus, style: sectionStyle),
      const SizedBox(height: Space.xs),
      SegmentedButton<TxnStatus>(
        showSelectedIcon: false,
        segments: [
          for (final s in TxnStatus.values)
            ButtonSegment(value: s, label: Text(TxnLabels.status(l, s))),
        ],
        selected: {t.status},
        onSelectionChanged: (v) =>
            setStatusWithUndo(context, ref, [t.id], v.first),
      ),
      if (detail.isTransfer)
        section(
          l.typeTransfer,
          infoRow(
            Icons.swap_horiz,
            t.amountMinor > 0
                ? '$peerAccount → $account'
                : '$account → $peerAccount',
          ),
        )
      else if (detail.splits.isNotEmpty)
        section(
          l.txnSplit,
          Column(
            children: [
              for (final s in detail.splits)
                infoRow(
                  AppIcons.of(categories[s.categoryId]?.icon),
                  categories[s.categoryId] == null
                      ? l.txnUncategorized
                      : categoryPath(categories[s.categoryId]!, categories),
                  trailing: AmountText(
                    s.amountMinor,
                    type: t.type,
                    style: context.text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        )
      else
        section(
          l.fieldCategory,
          infoRow(
            AppIcons.of(categories[t.categoryId]?.icon),
            categories[t.categoryId] == null
                ? l.txnUncategorized
                : categoryPath(categories[t.categoryId]!, categories),
          ),
        ),
      if (tagsOn && detail.tagIds.isNotEmpty)
        section(
          l.navTags,
          Wrap(
            spacing: Space.xs,
            runSpacing: Space.xs,
            children: [
              for (final id in detail.tagIds)
                if (tags[id] != null) TxnTagChip(tags[id]!.name),
            ],
          ),
        ),
      if (cfOn && detail.customFields.isNotEmpty)
        section(
          l.txnCustomFields,
          Column(
            children: [
              for (final d in defs)
                if (detail.customFields.containsKey(d.id))
                  _KeyValue(
                    d.name,
                    _cfText(l, dates, d, detail.customFields[d.id]),
                  ),
            ],
          ),
        ),
      if ((t.note ?? '').trim().isNotEmpty)
        section(l.fieldNote, Text(t.note!, style: context.text.bodyMedium)),
      if (t.valueDate != null)
        section(l.txnValueDate, Text(dates.medium(t.valueDate!))),
      if (attachOn) _AttachmentsSection(txnId: t.id),
      section(
        l.txnOrigin,
        infoRow(
          detail.recurringRuleName != null || t.recurringRuleId != null
              ? Icons.repeat
              : t.importBatchId != null
              ? Icons.upload_file_outlined
              : Icons.edit_note,
          t.recurringRuleId != null
              ? l.txnOriginRecurring(detail.recurringRuleName ?? '—')
              : t.importBatchId != null
              ? l.txnOriginImport(detail.importFileName ?? '—')
              : l.txnOriginManual,
        ),
      ),
      const SizedBox(height: Space.lg),
      Wrap(
        spacing: Space.sm,
        runSpacing: Space.xs,
        alignment: WrapAlignment.end,
        children: [
          OutlinedButton.icon(
            onPressed: () async {
              final draft = await ref
                  .read(ledgerRepositoryProvider)
                  .draftFor(t.id);
              if (draft != null && context.mounted) {
                await openRuleEditor(context, from: draft);
              }
            },
            icon: const Icon(Icons.auto_fix_high_outlined),
            label: Text(l.txnCreateRule),
          ),
          OutlinedButton.icon(
            onPressed: () => saveAsTemplate(context, ref, t.id),
            icon: const Icon(Icons.bookmark_add_outlined),
            label: Text(l.txnSaveAsTemplate),
          ),
          FilledButton.icon(
            onPressed: () => showQuickAdd(context, editId: t.id),
            icon: const Icon(Icons.edit_outlined),
            label: Text(l.txnEditTransaction),
          ),
        ],
      ),
      const SizedBox(height: Space.lg),
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        pane ? Space.xl : Space.listInset,
        pane ? Space.md : Space.xs,
        pane ? Space.md : Space.listInset,
        Space.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  static String _cfText(
    AppLocalizations l,
    DateFormats dates,
    CustomFieldDef d,
    Object? v,
  ) {
    if (v == null) return '—';
    return switch (d.type) {
      CustomFieldType.boolean => v == true ? l.commonYes : l.commonNo,
      CustomFieldType.date =>
        v is String && DateTime.tryParse(v) != null
            ? dates.medium(DateTime.parse(v))
            : '$v',
      CustomFieldType.multiselect => v is List ? v.join(', ') : '$v',
      _ => v is String ? v : jsonEncode(v),
    };
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue(this.k, this.v);

  final String k;
  final String v;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              k,
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              v,
              style: context.text.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentsSection extends ConsumerWidget {
  const _AttachmentsSection({required this.txnId});

  final String txnId;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final files = await pickAttachments();
    if (files.isEmpty) return;
    await ref.read(attachmentsRepositoryProvider).addAll(txnId, files);
  }

  Future<void> _open(BuildContext context, WidgetRef ref, Attachment a) async {
    final l = context.l10n;
    final bytes = await ref.read(attachmentsRepositoryProvider).bytesOf(a);
    if (!context.mounted) return;
    if (bytes == null) {
      showInfoSnackBar(context, l.txnAttachmentUnavailable);
      return;
    }
    if (a.mimeType.startsWith('image/') && a.mimeType != 'image/heic') {
      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: InteractiveViewer(
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.contain,
                    semanticLabel: a.fileName,
                  ),
                ),
              ),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => unawaited(_share(a, bytes)),
                    icon: const Icon(Icons.share_outlined),
                    label: Text(l.txnShare),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(l.commonClose),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      return;
    }
    await _share(a, bytes);
  }

  Future<void> _share(Attachment a, Uint8List bytes) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, name: a.fileName, mimeType: a.mimeType)],
        fileNameOverrides: [a.fileName],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cs = context.colors;
    final list = ref.watch(attachmentsForProvider(txnId)).value ?? const [];
    return Padding(
      padding: const EdgeInsets.only(top: Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  list.isEmpty
                      ? l.txnAttachments
                      : l.txnAttachmentCount(list.length),
                  style: context.text.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: l.txnAddAttachment,
                icon: const Icon(Icons.attach_file),
                onPressed: () => _add(context, ref),
              ),
            ],
          ),
          for (final a in list)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.surfaceContainer,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.surfaceContainerHighest),
                ),
                child: Icon(
                  a.mimeType.startsWith('image/')
                      ? Icons.image_outlined
                      : Icons.description_outlined,
                  color: cs.onSurfaceVariant,
                ),
              ),
              title: Text(
                a.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _open(context, ref, a),
              trailing: IconButton(
                tooltip: l.txnRemoveAttachment(a.fileName),
                icon: const Icon(Icons.close),
                onPressed: () async {
                  final repo = ref.read(attachmentsRepositoryProvider);
                  final messenger = ScaffoldMessenger.maybeOf(context);
                  await repo.delete(a.id);
                  showUndoSnackBar(
                    messenger,
                    l.txnRemoveAttachment(a.fileName),
                    undoLabel: l.commonUndo,
                    onUndo: () => repo.restore(a.id),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
