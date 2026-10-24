import 'dart:async';

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
import 'package:personal_finance/features/accounts/domain/account_grouping.dart';
import 'package:personal_finance/features/categories/data/custom_fields_repository.dart';
import 'package:personal_finance/features/categories/domain/drafts.dart';
import 'package:personal_finance/features/categories/presentation/appearance_pickers.dart';
import 'package:personal_finance/features/categories/presentation/module_notice.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

String customFieldTypeLabel(AppLocalizations l, CustomFieldType t) =>
    switch (t) {
      CustomFieldType.text => l.categoriesFieldTypeText,
      CustomFieldType.number => l.categoriesFieldTypeNumber,
      CustomFieldType.date => l.categoriesFieldTypeDate,
      CustomFieldType.select => l.categoriesFieldTypeSelect,
      CustomFieldType.multiselect => l.categoriesFieldTypeMultiselect,
      CustomFieldType.boolean => l.categoriesFieldTypeBoolean,
    };

IconData customFieldTypeIcon(CustomFieldType t) => switch (t) {
  CustomFieldType.text => Icons.short_text,
  CustomFieldType.number => Icons.pin_outlined,
  CustomFieldType.date => Icons.event_outlined,
  CustomFieldType.select => Icons.radio_button_checked,
  CustomFieldType.multiselect => Icons.checklist,
  CustomFieldType.boolean => Icons.check_box_outlined,
};

/// `/more/custom-fields`: definitions of user-defined fields.
class CustomFieldsScreen extends ConsumerStatefulWidget {
  const CustomFieldsScreen({super.key});

  @override
  ConsumerState<CustomFieldsScreen> createState() => _CustomFieldsScreenState();
}

class _CustomFieldsScreenState extends ConsumerState<CustomFieldsScreen> {
  List<String>? _order;
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final enabled = ref.watch(
      settingsProvider.select((s) => s.moduleEnabled(AppModule.customFields)),
    );
    final async = ref.watch(customFieldDefsProvider);
    final defs = async.value ?? const <CustomFieldDef>[];
    final counts = ref.watch(customFieldValueCountsProvider).value ?? const {};
    final hasArchived = defs.any((d) => d.archived);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.categoriesFieldsTitle, style: context.text.titleLarge),
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
              tooltip: l.categoriesFieldAdd,
              icon: const Icon(Icons.add),
              onPressed: () => showCustomFieldEditor(context),
            ),
          ],
        ],
      ),
      body: !enabled
          ? ModuleDisabledNotice(moduleName: l.setModCustomFields)
          : AsyncView(
              value: async,
              data: (_) {
                if (defs.isEmpty) {
                  return EmptyState(
                    icon: Icons.tune,
                    message: l.categoriesFieldsEmpty,
                    actionLabel: l.categoriesFieldAdd,
                    onAction: () => showCustomFieldEditor(context),
                  );
                }
                final visible = [
                  for (final d in defs)
                    if (_showArchived || !d.archived) d,
                ];
                final byId = {for (final d in visible) d.id: d};
                final ids = [for (final d in visible) d.id];
                if (_order == null ||
                    _order!.length != ids.length ||
                    !_order!.every(byId.containsKey)) {
                  _order = ids;
                }
                final order = _order!;
                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: ReorderableListView.builder(
                      padding: const EdgeInsets.only(bottom: Space.xxxl * 2),
                      itemCount: order.length,
                      onReorderItem: (from, to) async {
                        final next = moveItem(order, from, to);
                        setState(() => _order = next);
                        await ref
                            .read(customFieldsRepositoryProvider)
                            .reorder(next);
                      },
                      itemBuilder: (context, i) {
                        final d = byId[order[i]]!;
                        return _FieldRow(
                          key: ValueKey(d.id),
                          def: d,
                          valueCount: counts[d.id] ?? 0,
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

class _FieldRow extends ConsumerWidget {
  const _FieldRow({required this.def, required this.valueCount, super.key});

  final CustomFieldDef def;
  final int valueCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final repo = ref.read(customFieldsRepositoryProvider);
    final options = decodeOptions(def.options);
    final target = def.appliesTo == CustomFieldTarget.account.name
        ? l.categoriesFieldAccounts
        : l.categoriesFieldTransactions;
    final subtitle = [
      customFieldTypeLabel(l, def.type),
      target,
      if (typeHasOptions(def.type))
        l.categoriesFieldOptionCount(options.length),
      l.categoriesFieldValues(valueCount),
    ].join(' · ');
    return Opacity(
      opacity: def.archived ? 0.6 : 1,
      child: ListTile(
        contentPadding: const EdgeInsets.only(
          left: Space.listInset,
          right: Space.xxxl,
        ),
        leading: IconTile(icon: customFieldTypeIcon(def.type), size: 36),
        title: Row(
          children: [
            Flexible(child: Text(def.name, overflow: TextOverflow.ellipsis)),
            if (def.archived) ...[
              const SizedBox(width: Space.xs),
              StatusBadge(l.categoriesArchived),
            ],
          ],
        ),
        subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        onTap: () => showCustomFieldEditor(context, def: def),
        trailing: PopupMenuButton<String>(
          tooltip: l.categoriesMoreActions,
          onSelected: (v) async {
            switch (v) {
              case 'edit':
                await showCustomFieldEditor(context, def: def);
              case 'archive':
                await repo.setArchived(def.id, archived: !def.archived);
              case 'delete':
                final ok = await confirmDialog(
                  context,
                  title: l.commonDeleteConfirm(def.name),
                  message: valueCount > 0
                      ? l.categoriesFieldDeleteMessage(valueCount)
                      : null,
                );
                if (ok) {
                  await repo.delete(def.id);
                  if (context.mounted) {
                    showSnack(context, l.categoriesFieldDeleted);
                  }
                }
            }
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(value: 'edit', child: Text(l.commonEdit)),
            PopupMenuItem(
              value: 'archive',
              child: Text(
                def.archived ? l.categoriesUnarchive : l.categoriesArchive,
              ),
            ),
            PopupMenuItem(value: 'delete', child: Text(l.commonDelete)),
          ],
        ),
      ),
    );
  }
}

/// Create or edit a custom field definition.
Future<void> showCustomFieldEditor(
  BuildContext context, {
  CustomFieldDef? def,
}) => showAdaptiveSheet<void>(
  context,
  maxWidth: 560,
  builder: (_) => _FieldEditor(def: def),
);

class _FieldEditor extends ConsumerStatefulWidget {
  const _FieldEditor({this.def});

  final CustomFieldDef? def;

  @override
  ConsumerState<_FieldEditor> createState() => _FieldEditorState();
}

class _FieldEditorState extends ConsumerState<_FieldEditor> {
  final _formKey = GlobalKey<FormState>();
  late CustomFieldDraft _d = widget.def == null
      ? const CustomFieldDraft(name: '', type: CustomFieldType.text)
      : CustomFieldDraft.fromDef(widget.def!);
  late final _name = TextEditingController(text: _d.name);
  final _option = TextEditingController();
  bool _typeLocked = false;
  String? _optionsError;

  @override
  void initState() {
    super.initState();
    final def = widget.def;
    if (def != null) {
      unawaited(
        ref.read(customFieldsRepositoryProvider).valueCount(def.id).then((n) {
          if (mounted && n > 0) setState(() => _typeLocked = true);
        }),
      );
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _option.dispose();
    super.dispose();
  }

  void _addOption() {
    final t = _option.text.trim();
    if (t.isEmpty) return;
    if (_d.options.any((o) => o.toLowerCase() == t.toLowerCase())) {
      _option.clear();
      return;
    }
    setState(() {
      _d = _d.copyWith(options: [..._d.options, t]);
      _optionsError = null;
    });
    _option.clear();
  }

  Future<void> _save() async {
    final l = context.l10n;
    if (_option.text.trim().isNotEmpty) _addOption();
    final valid = _formKey.currentState?.validate() ?? false;
    final draft = _d.copyWith(name: _name.text);
    if (draft.hasOptions && draft.cleanOptions.isEmpty) {
      setState(() => _optionsError = l.categoriesFieldOptionsRequired);
      return;
    }
    if (!valid) return;
    final repo = ref.read(customFieldsRepositoryProvider);
    try {
      if (widget.def == null) {
        await repo.create(draft);
      } else {
        await repo.update(widget.def!.id, draft);
      }
      if (mounted) Navigator.pop(context);
    } on CustomFieldTypeLockedException {
      if (mounted) showSnack(context, l.categoriesFieldTypeLocked);
    } on Exception catch (e) {
      if (mounted) showSnack(context, l.commonError(e.toString()));
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
              widget.def == null ? l.categoriesFieldNew : l.categoriesFieldEdit,
              style: context.text.titleLarge,
            ),
            const SizedBox(height: Space.md),
            TextFormField(
              controller: _name,
              autofocus: widget.def == null,
              maxLength: 60,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l.categoriesFieldName),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? l.categoriesNameRequired : null,
            ),
            const SizedBox(height: Space.xs),
            DropdownButtonFormField<CustomFieldType>(
              isExpanded: true,
              initialValue: _d.type,
              decoration: InputDecoration(
                labelText: l.categoriesFieldType,
                helperText: _typeLocked ? l.categoriesFieldTypeLocked : null,
              ),
              items: [
                for (final t in CustomFieldType.values)
                  DropdownMenuItem(
                    value: t,
                    child: Row(
                      children: [
                        Icon(customFieldTypeIcon(t), size: 20),
                        const SizedBox(width: Space.sm),
                        Text(customFieldTypeLabel(l, t)),
                      ],
                    ),
                  ),
              ],
              onChanged: _typeLocked
                  ? null
                  : (t) {
                      if (t != null) setState(() => _d = _d.copyWith(type: t));
                    },
            ),
            const SizedBox(height: Space.md),
            Text(l.categoriesFieldAppliesTo, style: context.text.bodyMedium),
            const SizedBox(height: Space.xs),
            SegmentedButton<CustomFieldTarget>(
              segments: [
                ButtonSegment(
                  value: CustomFieldTarget.transaction,
                  label: Text(l.categoriesFieldTransactions),
                ),
                ButtonSegment(
                  value: CustomFieldTarget.account,
                  label: Text(l.categoriesFieldAccounts),
                ),
              ],
              selected: {_d.appliesTo},
              onSelectionChanged: (s) =>
                  setState(() => _d = _d.copyWith(appliesTo: s.first)),
            ),
            if (_d.hasOptions) ...[
              FormSectionLabel(l.categoriesFieldOptions),
              if (_d.options.isNotEmpty)
                Wrap(
                  spacing: Space.xs,
                  runSpacing: Space.xs,
                  children: [
                    for (final o in _d.options)
                      InputChip(
                        label: Text(o),
                        onDeleted: () => setState(
                          () => _d = _d.copyWith(
                            options: [
                              for (final x in _d.options)
                                if (x != o) x,
                            ],
                          ),
                        ),
                        deleteButtonTooltipMessage: l.commonDelete,
                      ),
                  ],
                ),
              const SizedBox(height: Space.xs),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _option,
                      decoration: InputDecoration(
                        labelText: l.categoriesFieldOptionHint,
                        errorText: _optionsError,
                      ),
                      onSubmitted: (_) => _addOption(),
                    ),
                  ),
                  IconButton(
                    tooltip: l.categoriesFieldAddOption,
                    icon: const Icon(Icons.add),
                    onPressed: _addOption,
                  ),
                ],
              ),
            ],
            if (widget.def != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.categoriesArchived),
                subtitle: Text(l.categoriesFieldArchivedDesc),
                value: _d.archived,
                onChanged: (v) => setState(() => _d = _d.copyWith(archived: v)),
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
