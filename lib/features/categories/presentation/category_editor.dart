import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/pickers.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/lookups.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/budgets/data/budget_period_provider.dart';
import 'package:personal_finance/features/categories/data/categories_repository.dart';
import 'package:personal_finance/features/categories/domain/drafts.dart';
import 'package:personal_finance/features/categories/presentation/appearance_pickers.dart';
import 'package:personal_finance/features/export/data/safety_copies.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

/// Opens the category editor (sheet on phones, dialog otherwise). Pass
/// [category] to edit, or [kind]/[parentId] for a new one. Returns the id
/// of the saved category. Merge and delete started from the editor run
/// after it closes.
Future<String?> showCategoryEditor(
  BuildContext context,
  WidgetRef ref, {
  Category? category,
  CategoryKind kind = CategoryKind.expense,
  String? parentId,
}) async {
  final result = await showAdaptiveSheet<String>(
    context,
    maxWidth: 560,
    builder: (_) =>
        _CategoryEditor(category: category, kind: kind, parentId: parentId),
  );
  if (!context.mounted || category == null) return result;
  if (result == _mergeResult) {
    await mergeCategoryFlow(context, ref, category);
    return null;
  }
  if (result == _deleteResult) {
    await deleteCategoryFlow(context, ref, category);
    return null;
  }
  return result;
}

const _mergeResult = '\u0000merge';
const _deleteResult = '\u0000delete';

String categoryErrorText(AppLocalizations l, CategoryError e) => switch (e) {
  CategoryError.invalidParent => l.categoriesInvalidParent,
  CategoryError.hasChildren => l.categoriesHasChildrenError,
  CategoryError.inUse => l.categoriesInUseError,
  CategoryError.invalidMergeTarget => l.categoriesMergeInvalid,
  CategoryError.mergeWouldNest => l.categoriesMergeNest,
  CategoryError.notFound => l.categoriesNotFound,
};

class _CategoryEditor extends ConsumerStatefulWidget {
  const _CategoryEditor({required this.kind, this.category, this.parentId});

  final Category? category;
  final CategoryKind kind;
  final String? parentId;

  @override
  ConsumerState<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends ConsumerState<_CategoryEditor> {
  final _formKey = GlobalKey<FormState>();
  late CategoryDraft _d;
  late final TextEditingController _name;
  late final TextEditingController _threshold;
  bool _saving = false;

  bool get _isNew => widget.category == null;

  @override
  void initState() {
    super.initState();
    final c = widget.category;
    if (c != null) {
      _d = CategoryDraft.fromCategory(c);
    } else {
      final parent = widget.parentId == null
          ? null
          : ref.read(categoryMapProvider)[widget.parentId];
      _d = CategoryDraft(
        name: '',
        kind: parent?.kind ?? widget.kind,
        parentId: widget.parentId,
        icon: parent?.icon ?? 'other',
        color: parent?.color,
      );
    }
    _name = TextEditingController(text: _d.name);
    _threshold = TextEditingController(
      text: _d.warnThresholdOverride?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _threshold.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = context.l10n;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final draft = _d.copyWith(name: _name.text);
    setState(() => _saving = true);
    final repo = ref.read(categoriesRepositoryProvider);
    try {
      String id;
      if (_isNew) {
        id = await repo.create(draft);
      } else {
        id = widget.category!.id;
        await repo.update(id, draft);
      }
      if (mounted) Navigator.pop(context, id);
    } on CategoryException catch (e) {
      if (mounted) showSnack(context, categoryErrorText(l, e.error));
    } on Exception catch (e) {
      if (mounted) showSnack(context, l.commonError(e.toString()));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final all = ref.watch(categoriesProvider).value ?? const <Category>[];
    final settings = ref.watch(settingsProvider);
    final budgetsOn = settings.moduleEnabled(AppModule.budgets);
    final selfId = widget.category?.id;
    final hasChildren =
        selfId != null && all.any((c) => c.parentId == selfId && !c.archived);
    final parents = [
      for (final c in all)
        if (c.parentId == null &&
            c.id != selfId &&
            c.kind == _d.kind &&
            (!c.archived || c.id == _d.parentId))
          c,
    ];
    final color = _d.color == null ? null : Color(_d.color!);
    final globalRollover = settings.get(BudgetSettings.defaultRollover);
    final globalWarn = settings.get(BudgetSettings.warnThreshold);

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.xl, Space.lg, Space.xs, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _isNew
                        ? (_d.parentId == null
                              ? l.categoriesNew
                              : l.categoriesNewSub)
                        : l.categoriesEdit,
                    style: context.text.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: l.commonClose,
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(
                Space.xl,
                Space.xs,
                Space.xl,
                Space.md,
              ),
              children: [
                TextFormField(
                  controller: _name,
                  autofocus: _isNew,
                  maxLength: 60,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(labelText: l.categoriesName),
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? l.categoriesNameRequired
                      : null,
                  onFieldSubmitted: (_) => _save(),
                ),
                if (_d.parentId == null) ...[
                  const SizedBox(height: Space.xs),
                  SegmentedButton<CategoryKind>(
                    segments: [
                      ButtonSegment(
                        value: CategoryKind.expense,
                        label: Text(l.typeExpense),
                      ),
                      ButtonSegment(
                        value: CategoryKind.income,
                        label: Text(l.typeIncome),
                      ),
                    ],
                    selected: {_d.kind},
                    onSelectionChanged: (s) => setState(
                      () => _d = _d.copyWith(kind: s.first, parentId: null),
                    ),
                  ),
                ],
                const SizedBox(height: Space.md),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _d.parentId ?? '',
                  decoration: InputDecoration(
                    labelText: l.categoriesParent,
                    helperText: hasChildren ? l.categoriesParentLocked : null,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: '',
                      child: Text(l.categoriesTopLevel),
                    ),
                    for (final p in parents)
                      DropdownMenuItem(value: p.id, child: Text(p.name)),
                  ],
                  onChanged: hasChildren
                      ? null
                      : (v) => setState(
                          () => _d = _d.copyWith(
                            parentId: v == null || v.isEmpty ? null : v,
                          ),
                        ),
                ),
                const SizedBox(height: Space.sm),
                IconPickerTile(
                  value: _d.icon,
                  color: color,
                  onChanged: (k) => setState(() => _d = _d.copyWith(icon: k)),
                ),
                Text(l.categoriesColor, style: context.text.bodyMedium),
                const SizedBox(height: Space.xxs),
                ColorSwatchPicker(
                  value: _d.color,
                  onChanged: (c) => setState(() => _d = _d.copyWith(color: c)),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.categoriesFavourite),
                  subtitle: Text(l.categoriesFavouriteDesc),
                  value: _d.favourite,
                  onChanged: (v) =>
                      setState(() => _d = _d.copyWith(favourite: v)),
                ),
                if (budgetsOn && _d.kind == CategoryKind.expense) ...[
                  FormSectionLabel(l.categoriesBudgetSection),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _d.rolloverOverride?.name ?? '',
                    decoration: InputDecoration(
                      labelText: l.categoriesRollover,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: '',
                        child: Text(
                          l.categoriesUseDefault(
                            rolloverLabel(l, globalRollover),
                          ),
                        ),
                      ),
                      for (final m in RolloverMode.values)
                        DropdownMenuItem(
                          value: m.name,
                          child: Text(rolloverLabel(l, m)),
                        ),
                    ],
                    onChanged: (v) => setState(
                      () =>
                          _d = _d.copyWith(rolloverOverride: parseRollover(v)),
                    ),
                  ),
                  const SizedBox(height: Space.sm),
                  TextFormField(
                    controller: _threshold,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: l.categoriesWarnThreshold,
                      hintText: l.categoriesUseDefault('$globalWarn %'),
                      helperText: l.categoriesWarnThresholdHint,
                      suffixText: '%',
                    ),
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty) return null;
                      final n = int.tryParse(t);
                      if (n == null || n < 1 || n > 100) {
                        return l.categoriesThresholdInvalid;
                      }
                      return null;
                    },
                    onChanged: (v) => setState(
                      () => _d = _d.copyWith(
                        warnThresholdOverride: int.tryParse(v.trim()),
                      ),
                    ),
                  ),
                ],
                if (!_isNew)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.categoriesArchived),
                    subtitle: Text(l.categoriesArchivedDesc),
                    value: _d.archived,
                    onChanged: (v) =>
                        setState(() => _d = _d.copyWith(archived: v)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.xl, Space.lg),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    children: [
                      if (!_isNew) ...[
                        TextButton(
                          onPressed: () => Navigator.pop(context, _mergeResult),
                          child: Text(l.categoriesMergeAction),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: context.colors.error,
                          ),
                          onPressed: () =>
                              Navigator.pop(context, _deleteResult),
                          child: Text(l.commonDelete),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: Space.xs),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(l.commonSave),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Picks a target and merges [source] into it after confirmation.
Future<void> mergeCategoryFlow(
  BuildContext context,
  WidgetRef ref,
  Category source,
) async {
  final l = context.l10n;
  final targetId = await showCategoryPicker(context, kind: source.kind);
  if (targetId == null || targetId.isEmpty || !context.mounted) return;
  final target = ref.read(categoryMapProvider)[targetId];
  if (target == null) return;
  if (target.id == source.id) {
    showSnack(context, l.categoriesMergeInvalid);
    return;
  }
  final ok = await confirmDialog(
    context,
    title: l.categoriesMergeTitle,
    message: l.categoriesMergeConfirm(source.name, target.name),
    confirmLabel: l.categoriesMergeAction,
  );
  if (!ok || !context.mounted) return;
  try {
    await withSafetyCopy(
      ref.read,
      SafetyReason.merge,
      () => ref
          .read(categoriesRepositoryProvider)
          .merge(
            source.id,
            target.id,
            periods: ref.read(budgetPeriodsProvider),
          ),
    );
    if (context.mounted) {
      showSnack(context, l.categoriesMerged(source.name, target.name));
    }
  } on CategoryException catch (e) {
    if (context.mounted) showSnack(context, categoryErrorText(l, e.error));
  } on SafetyCopyException catch (e) {
    if (context.mounted) showSnack(context, l.backupSafetyFailed('${e.cause}'));
  }
}

/// Deletes [c] when unused; otherwise explains and offers archive/merge.
Future<void> deleteCategoryFlow(
  BuildContext context,
  WidgetRef ref,
  Category c,
) async {
  final l = context.l10n;
  final repo = ref.read(categoriesRepositoryProvider);
  final usage = await repo.usage(c.id);
  if (!context.mounted) return;
  if (usage.children > 0) {
    showSnack(context, l.categoriesDeleteHasChildren(c.name));
    return;
  }
  if (usage.inUse) {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.categoriesInUseTitle),
        content: Text(
          l.categoriesDeleteInUse(
            c.name,
            usage.transactions + usage.splits,
            usage.budgets,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.commonCancel),
          ),
          if (!c.archived)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'archive'),
              child: Text(l.categoriesArchive),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'merge'),
            child: Text(l.categoriesMergeAction),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    if (choice == 'archive') {
      await repo.setArchived(c.id, archived: true);
    } else if (choice == 'merge') {
      await mergeCategoryFlow(context, ref, c);
    }
    return;
  }
  if (ref.read(settingsProvider).get(EntrySettings.confirmDelete)) {
    final ok = await confirmDialog(
      context,
      title: l.commonDeleteConfirm(c.name),
    );
    if (!ok) return;
  }
  try {
    await repo.delete(c.id);
  } on CategoryException catch (e) {
    if (context.mounted) showSnack(context, categoryErrorText(l, e.error));
    return;
  }
  if (context.mounted) {
    showSnack(
      context,
      l.categoriesDeleted,
      action: SnackBarAction(
        label: l.commonUndo,
        onPressed: () => repo.restore(c.id),
      ),
    );
  }
}
