import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/pickers.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/lookups.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/categories/data/tags_repository.dart';
import 'package:personal_finance/features/categories/presentation/appearance_pickers.dart';
import 'package:personal_finance/features/categories/presentation/module_notice.dart';
import 'package:personal_finance/features/export/data/safety_copies.dart';

/// `/more/tags`: create, edit, archive, merge and delete tags.
class TagsScreen extends ConsumerStatefulWidget {
  const TagsScreen({super.key});

  @override
  ConsumerState<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends ConsumerState<TagsScreen> {
  bool _showArchived = false;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final enabled = ref.watch(
      settingsProvider.select((s) => s.moduleEnabled(AppModule.tags)),
    );
    final async = ref.watch(tagsProvider);
    final tags = async.value ?? const <Tag>[];
    final usage = ref.watch(tagUsageCountsProvider).value ?? const {};
    final hasArchived = tags.any((t) => t.archived);
    final q = _query.trim().toLowerCase();
    final visible = [
      for (final t in tags)
        if ((_showArchived || !t.archived) &&
            (q.isEmpty || t.name.toLowerCase().contains(q)))
          t,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l.categoriesTagsTitle, style: context.text.titleLarge),
        actions: [
          if (enabled) ...[
            if (hasArchived)
              IconButton(
                tooltip: _showArchived
                    ? l.categoriesHideArchived
                    : l.categoriesShowArchived,
                isSelected: _showArchived,
                icon: const Icon(Icons.inventory_2_outlined),
                selectedIcon: const Icon(Icons.inventory_2),
                onPressed: () => setState(() => _showArchived = !_showArchived),
              ),
            IconButton(
              tooltip: l.categoriesTagAdd,
              icon: const Icon(Icons.add),
              onPressed: () => showTagEditor(context),
            ),
          ],
        ],
      ),
      body: !enabled
          ? ModuleDisabledNotice(moduleName: l.navTags)
          : AsyncView(
              value: async,
              data: (_) => tags.isEmpty
                  ? EmptyState(
                      icon: Icons.sell_outlined,
                      message: l.categoriesTagsEmpty,
                      actionLabel: l.categoriesTagAdd,
                      onAction: () => showTagEditor(context),
                    )
                  : Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: ListView(
                          padding: const EdgeInsets.only(
                            bottom: Space.xxxl * 2,
                          ),
                          children: [
                            if (tags.length > 8)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  Space.md,
                                  Space.xs,
                                  Space.md,
                                  Space.xs,
                                ),
                                child: TextField(
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.search),
                                    hintText: l.commonSearch,
                                    border: const OutlineInputBorder(
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(Radii.full),
                                      ),
                                    ),
                                  ),
                                  onChanged: (v) => setState(() => _query = v),
                                ),
                              ),
                            for (final t in visible)
                              _TagRow(tag: t, count: usage[t.id] ?? 0),
                            if (visible.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(Space.xl),
                                child: Text(
                                  l.commonEmpty,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
            ),
    );
  }
}

class _TagRow extends ConsumerWidget {
  const _TagRow({required this.tag, required this.count});

  final Tag tag;
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final repo = ref.read(tagsRepositoryProvider);
    final color = tag.color == null
        ? context.colors.outline
        : Color(tag.color!);
    return Opacity(
      opacity: tag.archived ? 0.6 : 1,
      child: ListTile(
        contentPadding: const EdgeInsets.only(
          left: Space.listInset,
          right: Space.xxs,
        ),
        leading: IconTile(icon: Icons.sell_outlined, color: color, size: 36),
        title: Row(
          children: [
            Flexible(
              child: Text('#${tag.name}', overflow: TextOverflow.ellipsis),
            ),
            if (tag.archived) ...[
              const SizedBox(width: Space.xs),
              StatusBadge(l.categoriesArchived),
            ],
          ],
        ),
        subtitle: Text(l.categoriesUsage(count)),
        onTap: () => showTagEditor(context, tag: tag),
        trailing: PopupMenuButton<String>(
          tooltip: l.categoriesMoreActions,
          onSelected: (v) async {
            switch (v) {
              case 'edit':
                await showTagEditor(context, tag: tag);
              case 'merge':
                await _merge(context, ref);
              case 'archive':
                await repo.setArchived(tag.id, archived: !tag.archived);
              case 'delete':
                await _delete(context, ref);
            }
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(value: 'edit', child: Text(l.commonEdit)),
            PopupMenuItem(value: 'merge', child: Text(l.categoriesMergeAction)),
            PopupMenuItem(
              value: 'archive',
              child: Text(
                tag.archived ? l.categoriesUnarchive : l.categoriesArchive,
              ),
            ),
            PopupMenuItem(value: 'delete', child: Text(l.commonDelete)),
          ],
        ),
      ),
    );
  }

  Future<void> _merge(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final others = [
      for (final t in ref.read(tagsProvider).value ?? const <Tag>[])
        if (t.id != tag.id && !t.archived) t,
    ];
    if (others.isEmpty) {
      showSnack(context, l.categoriesTagNoMergeTarget);
      return;
    }
    final target = await showAdaptiveSheet<Tag>(
      context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.xl,
              Space.lg,
              Space.xl,
              Space.xs,
            ),
            child: Text(
              l.categoriesTagMergeInto(tag.name),
              style: ctx.text.titleMedium,
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final t in others)
                  ListTile(
                    leading: Icon(
                      Icons.sell_outlined,
                      color: t.color == null ? null : Color(t.color!),
                    ),
                    title: Text('#${t.name}'),
                    onTap: () => Navigator.pop(ctx, t),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (target == null || !context.mounted) return;
    final ok = await confirmDialog(
      context,
      title: l.categoriesMergeTitle,
      message: l.categoriesTagMergeConfirm(tag.name, target.name),
      confirmLabel: l.categoriesMergeAction,
    );
    if (!ok) return;
    try {
      await withSafetyCopy(
        ref.read,
        SafetyReason.merge,
        () => ref.read(tagsRepositoryProvider).merge(tag.id, target.id),
      );
    } on SafetyCopyException catch (e) {
      if (context.mounted) {
        showSnack(context, l.backupSafetyFailed('${e.cause}'));
      }
      return;
    }
    if (context.mounted) {
      showSnack(context, l.categoriesMerged('#${tag.name}', '#${target.name}'));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final ok = await confirmDialog(
      context,
      title: l.commonDeleteConfirm('#${tag.name}'),
      message: count > 0 ? l.categoriesTagDeleteMessage(count) : null,
    );
    if (!ok) return;
    await ref.read(tagsRepositoryProvider).delete(tag.id);
    if (context.mounted) showSnack(context, l.categoriesTagDeleted);
  }
}

/// Create or edit a tag (name and colour).
Future<void> showTagEditor(BuildContext context, {Tag? tag}) =>
    showAdaptiveSheet<void>(context, builder: (_) => _TagEditor(tag: tag));

class _TagEditor extends ConsumerStatefulWidget {
  const _TagEditor({this.tag});

  final Tag? tag;

  @override
  ConsumerState<_TagEditor> createState() => _TagEditorState();
}

class _TagEditorState extends ConsumerState<_TagEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.tag?.name ?? '');
  late int? _color = widget.tag?.color;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = context.l10n;
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final repo = ref.read(tagsRepositoryProvider);
    try {
      if (widget.tag == null) {
        await repo.create(_name.text, color: _color);
      } else {
        await repo.update(widget.tag!.id, name: _name.text, color: _color);
      }
      if (mounted) Navigator.pop(context);
    } on TagNameException catch (e) {
      setState(
        () =>
            _error = e.taken ? l.categoriesTagTaken : l.categoriesNameRequired,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Space.xl,
          Space.lg,
          Space.xl,
          Space.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.tag == null ? l.categoriesTagNew : l.categoriesTagEdit,
              style: context.text.titleLarge,
            ),
            const SizedBox(height: Space.md),
            TextFormField(
              controller: _name,
              autofocus: true,
              maxLength: 40,
              decoration: InputDecoration(
                labelText: l.categoriesTagName,
                prefixText: '#',
                errorText: _error,
              ),
              validator: (v) => TagsRepository.normalize(v ?? '').isEmpty
                  ? l.categoriesNameRequired
                  : null,
              onFieldSubmitted: (_) => _save(),
            ),
            const SizedBox(height: Space.xs),
            Text(l.categoriesColor, style: context.text.bodyMedium),
            const SizedBox(height: Space.xxs),
            ColorSwatchPicker(
              value: _color,
              onChanged: (c) => setState(() => _color = c),
            ),
            const SizedBox(height: Space.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l.commonCancel),
                ),
                const SizedBox(width: Space.xs),
                FilledButton(onPressed: _save, child: Text(l.commonSave)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
