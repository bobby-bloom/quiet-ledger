import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/csv/file_output.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/platform/capabilities.dart';
import 'package:personal_finance/features/import/data/import_repository.dart';
import 'package:personal_finance/features/import/data/profile_repository.dart';

/// `/more/import/history`: past batches (undo, show rows) and profiles
/// (export, import, rename, delete, start an import).
class ImportHistoryScreen extends ConsumerWidget {
  const ImportHistoryScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.importHistory),
          bottom: TabBar(
            tabs: [
              Tab(text: l.importHistoryTab),
              Tab(text: l.importProfilesTab),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/more/import'),
          icon: const Icon(Icons.upload_file_outlined),
          label: Text(l.importNew),
        ),
        body: const TabBarView(children: [_BatchList(), _ProfileList()]),
      ),
    );
  }
}

class _BatchList extends ConsumerWidget {
  const _BatchList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return AsyncView(
      value: ref.watch(importHistoryProvider),
      data: (batches) => batches.isEmpty
          ? EmptyState(
              icon: Icons.history,
              message: l.importHistoryEmpty,
              actionLabel: l.importNew,
              onAction: () => context.push('/more/import'),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                Space.md,
                Space.sm,
                Space.md,
                96,
              ),
              itemCount: batches.length,
              separatorBuilder: (_, _) => const SizedBox(height: Space.xs),
              itemBuilder: (context, i) => _BatchCard(info: batches[i]),
            ),
    );
  }
}

class _BatchCard extends ConsumerWidget {
  const _BatchCard({required this.info});

  final ImportBatchInfo info;

  Future<void> _undo(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmDialog(
      context,
      title: l.importHistoryUndoTitle,
      message: l.importHistoryUndoMessage(info.liveCount),
      confirmLabel: l.importHistoryUndoAction,
    );
    if (!ok) return;
    await ref.read(importRepositoryProvider).undo(info.batch.id);
    messenger.showSnackBar(SnackBar(content: Text(l.importUndone)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final dates = ref.watch(dateFormatsProvider);
    final b = info.batch;
    final undone = info.isUndone;
    final when = '${dates.medium(b.importedAt)} ${dates.time(b.importedAt)}';
    final details = [
      when,
      l.importHistoryCount(b.rowCount),
      if (undone)
        l.importHistoryUndone(dates.medium(b.undoneAt!))
      else if (info.liveCount <
          info.intOf('transactions') + info.intOf('transfers'))
        l.importHistoryLive(
          info.liveCount,
          info.intOf('transactions') + info.intOf('transfers'),
        ),
    ];
    return SectionCard(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, Space.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: IconTile(
              icon: undone ? Icons.undo : Icons.upload_file_outlined,
              color: undone ? context.colors.outline : context.colors.primary,
            ),
            title: Text(
              b.fileName,
              style: undone
                  ? TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: context.colors.onSurfaceVariant,
                    )
                  : null,
            ),
            subtitle: Text(details.join(' · ')),
          ),
          if (!undone)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.sm),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: Space.xs,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.format_list_bulleted, size: 18),
                    label: Text(l.importShowTransactions),
                    onPressed: () => context.go(
                      Uri(
                        path: '/transactions',
                        queryParameters: {'importBatch': b.id},
                      ).toString(),
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.undo, size: 18),
                    label: Text(l.importHistoryUndoAction),
                    style: TextButton.styleFrom(
                      foregroundColor: context.colors.error,
                    ),
                    onPressed: () => _undo(context, ref),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileList extends ConsumerWidget {
  const _ProfileList();

  Future<void> _importFile(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final file = await pickFileBytes(extensions: const ['json']);
    if (file == null) return;
    try {
      await ref
          .read(importProfileRepositoryProvider)
          .importJson(utf8.decode(file.bytes, allowMalformed: true));
      messenger.showSnackBar(SnackBar(content: Text(l.importProfileImported)));
    } on FormatException {
      messenger.showSnackBar(SnackBar(content: Text(l.importProfileInvalid)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return AsyncView(
      value: ref.watch(importProfilesProvider),
      data: (profiles) => ListView(
        padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, 96),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.file_open_outlined),
              label: Text(l.importProfileLoadFile),
              onPressed: () => _importFile(context, ref),
            ),
          ),
          if (profiles.isEmpty)
            EmptyState(
              icon: Icons.bookmarks_outlined,
              message: l.importProfilesEmpty,
            ),
          for (final p in profiles) _ProfileTile(profile: p),
        ],
      ),
    );
  }
}

enum _ProfileAction { start, export, rename, delete }

class _ProfileTile extends ConsumerWidget {
  const _ProfileTile({required this.profile});

  final ImportProfile profile;

  Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    _ProfileAction a,
  ) async {
    final l = context.l10n;
    final repo = ref.read(importProfileRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    switch (a) {
      case _ProfileAction.start:
        await context.push(
          Uri(
            path: '/more/import',
            queryParameters: {'profile': profile.id},
          ).toString(),
        );
      case _ProfileAction.export:
        final json = ImportProfileRepository.exportJson(profile);
        final safe = profile.name.replaceAll(RegExp(r'[^\w\- ]+'), '_');
        final r = await saveOrShareBytes(
          bytes: Uint8List.fromList(utf8.encode(json)),
          fileName: '$safe.import-profile.json',
          mimeType: 'application/json',
          capabilities: ref.read(platformCapabilitiesProvider),
        );
        if (r.ok) {
          messenger.showSnackBar(
            SnackBar(content: Text(l.importProfileExported)),
          );
        }
      case _ProfileAction.rename:
        final name = await _askName(context, profile.name);
        if (name != null && name.trim().isNotEmpty) {
          await repo.rename(profile.id, name);
        }
      case _ProfileAction.delete:
        final ok = await confirmDialog(
          context,
          title: l.commonDeleteConfirm(profile.name),
        );
        if (ok) await repo.delete(profile.id);
    }
  }

  Future<String?> _askName(BuildContext context, String current) {
    final controller = TextEditingController(text: current);
    final l = context.l10n;
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.importProfileRename),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l.importProfileName),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(l.commonSave),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cfg = ImportProfileRepository.configOf(profile);
    final sheets = cfg.sheets.map((s) => s.sheetName).toSet().join(', ');
    return Card(
      child: ListTile(
        leading: const Icon(Icons.bookmark_outline),
        title: Text(profile.name),
        subtitle: sheets.isEmpty
            ? null
            : Text(sheets, maxLines: 1, overflow: TextOverflow.ellipsis),
        onTap: () => _act(context, ref, _ProfileAction.start),
        trailing: PopupMenuButton<_ProfileAction>(
          onSelected: (a) => _act(context, ref, a),
          itemBuilder: (_) => [
            PopupMenuItem(
              value: _ProfileAction.start,
              child: Text(l.importProfileStart),
            ),
            PopupMenuItem(
              value: _ProfileAction.export,
              child: Text(l.importProfileExport),
            ),
            PopupMenuItem(
              value: _ProfileAction.rename,
              child: Text(l.importProfileRename),
            ),
            PopupMenuItem(
              value: _ProfileAction.delete,
              child: Text(l.commonDelete),
            ),
          ],
        ),
      ),
    );
  }
}
