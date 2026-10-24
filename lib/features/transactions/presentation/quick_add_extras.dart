import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/app_icons.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/app/ui/pickers.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/ledger/lookups.dart';
import 'package:personal_finance/features/transactions/data/attachments_repository.dart';
import 'package:personal_finance/features/transactions/domain/calculator.dart';
import 'package:personal_finance/features/transactions/presentation/providers.dart';
import 'package:personal_finance/features/transactions/presentation/quick_add_widgets.dart';
import 'package:personal_finance/features/transactions/presentation/txn_labels.dart';

/// One editable split line (amount without sign, as typed).
class SplitLine {
  SplitLine({this.categoryId, String amount = ''})
    : amount = TextEditingController(text: amount);

  String? categoryId;
  final TextEditingController amount;

  int amountMinor(String decimalSeparator) =>
      AmountCalculator.tryEvaluate(
        amount.text,
        decimalSeparator: decimalSeparator,
      )?.abs() ??
      0;

  void dispose() => amount.dispose();
}

/// Split editor: category + amount per line and the remaining amount.
class SplitEditor extends ConsumerWidget {
  const SplitEditor({
    required this.lines,
    required this.totalMinor,
    required this.decimalSeparator,
    required this.onChanged,
    required this.onAdd,
    required this.onRemove,
    required this.onAssignRemaining,
    super.key,
    this.kind,
    this.error,
  });

  final List<SplitLine> lines;

  /// Absolute total of the transaction.
  final int totalMinor;
  final String decimalSeparator;
  final CategoryKind? kind;
  final VoidCallback onChanged;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final ValueChanged<int> onAssignRemaining;
  final String? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cs = context.colors;
    final fmt = ref.watch(moneyFormatterProvider);
    final categories = ref.watch(categoryMapProvider);
    final assigned = lines.fold(
      0,
      (a, s) => a + s.amountMinor(decimalSeparator),
    );
    final remaining = totalMinor - assigned;
    final Widget status;
    if (remaining == 0) {
      status = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 16, color: cs.primary),
          const SizedBox(width: 4),
          Text(
            l.txnFullyAssigned,
            style: context.text.labelMedium?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    } else {
      status = Text(
        remaining > 0
            ? l.txnRemaining(fmt.minor(remaining))
            : l.txnOverAssigned(fmt.minor(-remaining)),
        style: context.text.labelMedium?.copyWith(
          color: remaining > 0 ? cs.onSurfaceVariant : cs.error,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TxnSectionLabel(l.txnSplit, trailing: status),
        for (var i = 0; i < lines.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.xs),
            child: Row(
              children: [
                Expanded(
                  child: _SplitCategoryButton(
                    label: l.txnSplitLineCategory(i + 1),
                    category: categories[lines[i].categoryId],
                    all: categories,
                    onTap: () async {
                      final id = await showCategoryPicker(
                        context,
                        kind: kind,
                        selectedId: lines[i].categoryId,
                      );
                      if (id == null) return;
                      lines[i].categoryId = id.isEmpty ? null : id;
                      onChanged();
                    },
                  ),
                ),
                const SizedBox(width: Space.xs),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: lines[i].amount,
                    textAlign: TextAlign.end,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9.,+\-−×÷*/() ]'),
                      ),
                    ],
                    style: context.text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: '0${decimalSeparator}00',
                      suffixText: '€',
                      semanticCounterText: l.txnSplitLineAmount(i + 1),
                    ),
                    onChanged: (_) => onChanged(),
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: remaining > 0 && lines[i].amount.text.trim().isEmpty
                      ? IconButton(
                          tooltip: l.txnAssignRemaining,
                          icon: const Icon(Icons.download_done_outlined),
                          onPressed: () => onAssignRemaining(i),
                        )
                      : IconButton(
                          tooltip: l.txnRemoveSplit,
                          icon: const Icon(Icons.close),
                          onPressed: lines.length <= 1
                              ? null
                              : () => onRemove(i),
                        ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: Text(l.txnAddSplit),
            ),
            const Spacer(),
            if (remaining > 0)
              TextButton(
                onPressed: () => onAssignRemaining(lines.length - 1),
                child: Text(l.txnAssignRemaining),
              ),
          ],
        ),
        if (error != null)
          Text(
            error!,
            style: context.text.labelMedium?.copyWith(color: cs.error),
          ),
      ],
    );
  }
}

class _SplitCategoryButton extends StatelessWidget {
  const _SplitCategoryButton({
    required this.label,
    required this.category,
    required this.all,
    required this.onTap,
  });

  final String label;
  final Category? category;
  final Map<String, Category> all;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final c = category;
    final name = c == null
        ? context.l10n.txnChooseCategory
        : categoryPath(c, all);
    return Semantics(
      button: true,
      label: '$label: $name',
      excludeSemantics: true,
      child: Material(
        color: cs.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: cs.surfaceContainerHighest),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Icon(
                    c == null ? Icons.category_outlined : AppIcons.of(c.icon),
                    size: 18,
                    color: c?.color == null
                        ? cs.onSurfaceVariant
                        : Color(c!.color!),
                  ),
                  const SizedBox(width: Space.xs),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: c == null ? cs.onSurfaceVariant : cs.onSurface,
                      ),
                    ),
                  ),
                  Icon(Icons.expand_more, size: 18, color: cs.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Selected tags as removable chips plus an "Add tag" button.
class TagsEditor extends ConsumerWidget {
  const TagsEditor({
    required this.tagIds,
    required this.onChanged,
    super.key,
    this.error,
  });

  final List<String> tagIds;
  final ValueChanged<List<String>> onChanged;
  final String? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cs = context.colors;
    final tags = ref.watch(tagMapProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TxnSectionLabel(l.navTags),
        Wrap(
          spacing: Space.xs,
          runSpacing: Space.xs,
          children: [
            for (final id in tagIds)
              if (tags[id] != null)
                Container(
                  height: 32,
                  padding: const EdgeInsets.only(left: 10, right: 2),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainer,
                    borderRadius: BorderRadius.circular(Radii.sm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '#${tags[id]!.name}',
                        style: context.text.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          iconSize: 16,
                          tooltip: l.txnRemoveTag(tags[id]!.name),
                          icon: const Icon(Icons.close),
                          onPressed: () => onChanged([...tagIds]..remove(id)),
                        ),
                      ),
                    ],
                  ),
                ),
            SizedBox(
              height: 32,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Radii.sm),
                  ),
                  side: BorderSide(
                    color: error != null ? cs.error : cs.outline,
                  ),
                  foregroundColor: cs.onSurfaceVariant,
                  textStyle: context.text.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: () async {
                  final picked = await showTagPicker(
                    context,
                    selected: tagIds.toSet(),
                  );
                  if (picked != null) onChanged(picked.toList());
                },
                icon: const Icon(Icons.add, size: 16),
                label: Text(l.txnAddTag),
              ),
            ),
          ],
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              error!,
              style: context.text.labelMedium?.copyWith(color: cs.error),
            ),
          ),
      ],
    );
  }
}

/// Multi-select tag picker with search; typing a new name offers to create
/// the tag. Returns the selected ids, or null when dismissed.
Future<Set<String>?> showTagPicker(
  BuildContext context, {
  Set<String> selected = const {},
}) => showAdaptiveSheet<Set<String>>(
  context,
  builder: (_) => _TagPicker(selected: selected),
);

class _TagPicker extends ConsumerStatefulWidget {
  const _TagPicker({required this.selected});

  final Set<String> selected;

  @override
  ConsumerState<_TagPicker> createState() => _TagPickerState();
}

class _TagPickerState extends ConsumerState<_TagPicker> {
  late final Set<String> _selected = {...widget.selected};
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _create(String name) async {
    final db = ref.read(databaseProvider);
    final id = await ref
        .read(syncWriterProvider)
        .insert(db.tags, TagsCompanion(name: Value(name.trim())));
    setState(() {
      _selected.add(id);
      _query.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tags = ref.watch(activeTagsProvider).value ?? const <Tag>[];
    final q = _query.text.trim().toLowerCase();
    final shown = tags
        .where((t) => q.isEmpty || t.name.toLowerCase().contains(q))
        .toList();
    final exact = tags.any((t) => t.name.toLowerCase() == q);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _query,
            autofocus: true,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: l.txnSearchTags,
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(Radii.full)),
              ),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (v) async {
              if (v.trim().isNotEmpty && !exact) await _create(v);
            },
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              if (q.isNotEmpty && !exact)
                ListTile(
                  leading: const Icon(Icons.add),
                  title: Text(l.txnCreateTag(_query.text.trim())),
                  onTap: () => _create(_query.text),
                ),
              for (final t in shown)
                CheckboxListTile(
                  value: _selected.contains(t.id),
                  secondary: const Icon(Icons.sell_outlined),
                  title: Text('#${t.name}'),
                  onChanged: (v) => setState(
                    () => v ?? false
                        ? _selected.add(t.id)
                        : _selected.remove(t.id),
                  ),
                ),
              if (shown.isEmpty && q.isEmpty)
                EmptyState(message: l.commonEmpty, icon: Icons.sell_outlined),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l.commonCancel),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => Navigator.pop(context, _selected),
                child: Text(l.commonDone),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Decoded option list of a select/multi-select field.
List<String> customFieldOptions(CustomFieldDef d) {
  try {
    return [for (final o in jsonDecode(d.options) as List) '$o'];
  } on Object {
    return const [];
  }
}

/// Inputs for the custom fields of a transaction (appliesTo =
/// 'transaction').
class CustomFieldInputs extends ConsumerWidget {
  const CustomFieldInputs({
    required this.defs,
    required this.values,
    required this.onChanged,
    super.key,
  });

  final List<CustomFieldDef> defs;
  final Map<String, Object?> values;
  final void Function(String fieldId, Object? value) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dates = ref.watch(dateFormatsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final d in defs)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.xs),
            child: _input(context, d, dates),
          ),
      ],
    );
  }

  Widget _input(BuildContext context, CustomFieldDef d, DateFormats dates) {
    final l = context.l10n;
    final v = values[d.id];
    switch (d.type) {
      case CustomFieldType.text:
        return TextFormField(
          key: ValueKey('cf-${d.id}'),
          initialValue: v is String ? v : '',
          decoration: InputDecoration(labelText: d.name),
          onChanged: (s) => onChanged(d.id, s.trim().isEmpty ? null : s),
        );
      case CustomFieldType.number:
        return TextFormField(
          key: ValueKey('cf-${d.id}'),
          initialValue: v is num ? '$v' : '',
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          decoration: InputDecoration(labelText: d.name),
          onChanged: (s) =>
              onChanged(d.id, num.tryParse(s.trim().replaceAll(',', '.'))),
        );
      case CustomFieldType.date:
        final parsed = v is String ? DateTime.tryParse(v) : null;
        return TxnFieldButton(
          icon: Icons.event_outlined,
          label: d.name,
          value: parsed == null ? l.txnPickDate : dates.medium(parsed),
          placeholder: parsed == null,
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: parsed ?? DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime(2200),
            );
            if (picked != null) {
              onChanged(
                d.id,
                '${picked.year.toString().padLeft(4, '0')}-'
                '${picked.month.toString().padLeft(2, '0')}-'
                '${picked.day.toString().padLeft(2, '0')}',
              );
            }
          },
        );
      case CustomFieldType.select:
        final options = customFieldOptions(d);
        return DropdownButtonFormField<String>(
          key: ValueKey('cf-${d.id}'),
          initialValue: v is String && options.contains(v) ? v : null,
          decoration: InputDecoration(labelText: d.name),
          items: [
            DropdownMenuItem(child: Text(l.commonNone)),
            for (final o in options) DropdownMenuItem(value: o, child: Text(o)),
          ],
          onChanged: (s) => onChanged(d.id, s),
        );
      case CustomFieldType.multiselect:
        final options = customFieldOptions(d);
        final current = v is List ? v.map((e) => '$e').toSet() : <String>{};
        return InputDecorator(
          decoration: InputDecoration(labelText: d.name),
          child: Wrap(
            spacing: Space.xs,
            runSpacing: Space.xs,
            children: [
              for (final o in options)
                FilterChip(
                  label: Text(o),
                  selected: current.contains(o),
                  onSelected: (sel) {
                    final next = {...current};
                    sel ? next.add(o) : next.remove(o);
                    onChanged(
                      d.id,
                      next.isEmpty
                          ? null
                          : [
                              for (final x in options)
                                if (next.contains(x)) x,
                            ],
                    );
                  },
                ),
            ],
          ),
        );
      case CustomFieldType.boolean:
        return SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: Space.xxs),
          title: Text(d.name),
          value: v == true,
          onChanged: (b) => onChanged(d.id, b ? true : null),
        );
    }
  }
}

/// Picks receipt files (images/PDF). Returns an empty list when cancelled.
Future<List<PendingAttachment>> pickAttachments() async {
  final files = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const [
      'jpg',
      'jpeg',
      'png',
      'heic',
      'webp',
      'gif',
      'pdf',
    ],
  );
  return [
    for (final f in files)
      PendingAttachment(
        fileName: f.name,
        bytes: await f.readAsBytes(),
        sourcePath: f.path,
      ),
  ];
}

/// Attachment list in quick add: saved ones (edit mode) and new ones.
class AttachmentsEditor extends ConsumerWidget {
  const AttachmentsEditor({
    required this.pending,
    required this.removedIds,
    required this.onAdd,
    required this.onRemovePending,
    required this.onRemoveExisting,
    super.key,
    this.txnId,
  });

  final String? txnId;
  final List<PendingAttachment> pending;
  final Set<String> removedIds;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemovePending;
  final ValueChanged<String> onRemoveExisting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final existing = txnId == null
        ? const <Attachment>[]
        : (ref.watch(attachmentsForProvider(txnId!)).value ??
                  const <Attachment>[])
              .where((a) => !removedIds.contains(a.id))
              .toList();
    if (existing.isEmpty && pending.isEmpty) return const SizedBox.shrink();
    Widget row(String name, String sub, VoidCallback onRemove) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const IconTile(icon: Icons.receipt_long_outlined),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(sub),
      trailing: IconButton(
        tooltip: l.txnRemoveAttachment(name),
        icon: const Icon(Icons.close),
        onPressed: onRemove,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TxnSectionLabel(
          l.txnAttachments,
          trailing: IconButton(
            tooltip: l.txnAddAttachment,
            icon: const Icon(Icons.add),
            onPressed: onAdd,
          ),
        ),
        for (final a in existing)
          row(a.fileName, _size(a.sizeBytes), () => onRemoveExisting(a.id)),
        for (var i = 0; i < pending.length; i++)
          row(
            pending[i].fileName,
            '${_size(pending[i].bytes.length)} · ${l.txnAttachmentPending}',
            () => onRemovePending(i),
          ),
      ],
    );
  }
}

String _size(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Short label for a status choice.
String statusLabel(BuildContext context, TxnStatus s) =>
    TxnLabels.status(context.l10n, s);
