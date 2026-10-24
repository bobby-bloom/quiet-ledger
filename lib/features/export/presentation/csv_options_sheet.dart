import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/pickers.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/csv/csv_writer.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/export/domain/export_settings.dart';
import 'package:personal_finance/features/export/presentation/export_labels.dart';

/// A selectable column (key + header) for the options sheet.
typedef ColumnChoice = ({String key, String header});

/// Edits [initial] (delimiter, encoding, date format, decimal separator,
/// header row, column selection/order, presets). Returns the new options or
/// null when cancelled. [defaults] are the options from Settings.
Future<CsvOptions?> showCsvOptionsSheet(
  BuildContext context, {
  required CsvOptions initial,
  required CsvOptions defaults,
  required List<ColumnChoice> columns,
}) => showAdaptiveSheet<CsvOptions>(
  context,
  maxWidth: 560,
  builder: (_) =>
      CsvOptionsSheet(initial: initial, defaults: defaults, columns: columns),
);

class CsvOptionsSheet extends ConsumerStatefulWidget {
  const CsvOptionsSheet({
    required this.initial,
    required this.defaults,
    required this.columns,
    super.key,
  });

  final CsvOptions initial;
  final CsvOptions defaults;
  final List<ColumnChoice> columns;

  @override
  ConsumerState<CsvOptionsSheet> createState() => _CsvOptionsSheetState();
}

class _CsvOptionsSheetState extends ConsumerState<CsvOptionsSheet> {
  late CsvOptions _opts;
  late List<String> _order;
  late Set<String> _selected;

  List<String> get _allKeys => [for (final c in widget.columns) c.key];

  @override
  void initState() {
    super.initState();
    _load(widget.initial);
  }

  void _load(CsvOptions o) {
    _opts = o;
    final all = _allKeys;
    final chosen = o.columns?.where(all.contains).toList() ?? all;
    _selected = chosen.toSet();
    _order = [...chosen, ...all.where((k) => !_selected.contains(k))];
  }

  CsvOptions _result() {
    final selectedInOrder = [
      for (final k in _order)
        if (_selected.contains(k)) k,
    ];
    final isDefault =
        selectedInOrder.length == _allKeys.length &&
        List.generate(
          _allKeys.length,
          (i) => _allKeys[i] == selectedInOrder[i],
        ).every((x) => x);
    return isDefault
        ? _opts.copyWith(clearColumns: true)
        : _opts.copyWith(columns: selectedInOrder);
  }

  Future<void> _savePreset() async {
    final l = context.l10n;
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.exportPresetSave),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l.exportPresetName),
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
    );
    controller.dispose();
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty || !mounted) return;
    final presets = ref.read(settingsProvider).get(ExportSettings.csvPresets);
    await ref
        .read(settingsProvider.notifier)
        .set(
          ExportSettings.csvPresets,
          upsertPreset(presets, CsvPreset(trimmed, _result())),
        );
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(l.exportPresetSaved(trimmed))));
  }

  Future<void> _deletePreset(CsvPreset p) async {
    final l = context.l10n;
    final ok = await confirmDialog(
      context,
      title: l.exportPresetDelete(p.name),
    );
    if (!ok || !mounted) return;
    final presets = ref.read(settingsProvider).get(ExportSettings.csvPresets);
    await ref
        .read(settingsProvider.notifier)
        .set(ExportSettings.csvPresets, removePreset(presets, p.name));
  }

  void _applyPreset(CsvPreset p) {
    setState(() => _load(p.options.copyWith(locale: widget.initial.locale)));
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(context.l10n.exportPresetApplied(p.name))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final presets = ref.watch(
      settingsProvider.select((s) => s.get(ExportSettings.csvPresets)),
    );
    final height = MediaQuery.sizeOf(context).height;
    final valid = _selected.isNotEmpty;

    Widget section(String title, Widget child) => Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.listInset,
        Space.md,
        Space.listInset,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: context.text.titleSmall),
          ),
          const SizedBox(height: Space.xs),
          child,
        ],
      ),
    );

    Widget chips<T>(
      List<T> values,
      T selected,
      String Function(T) label,
      ValueChanged<T> onSelected,
    ) => Wrap(
      spacing: Space.xs,
      runSpacing: Space.xs,
      children: [
        for (final v in values)
          ChoiceChip(
            label: Text(label(v)),
            selected: v == selected,
            onSelected: (_) => setState(() => onSelected(v)),
          ),
      ],
    );

    final headers = {for (final c in widget.columns) c.key: c.header};

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: math.min(height * 0.9, 720)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.listInset,
              Space.md,
              Space.xs,
              Space.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(l.exportOptions, style: context.text.titleLarge),
                ),
                IconButton(
                  tooltip: l.commonClose,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: Space.md),
              children: [
                section(
                  l.exportPresets,
                  Wrap(
                    spacing: Space.xs,
                    runSpacing: Space.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (presets.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: Space.xs),
                          child: Text(
                            l.exportPresetsEmpty,
                            style: context.text.bodySmall?.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      for (final p in presets)
                        InputChip(
                          label: Text(p.name),
                          onPressed: () => _applyPreset(p),
                          onDeleted: () => _deletePreset(p),
                          deleteButtonTooltipMessage: l.exportPresetDelete(
                            p.name,
                          ),
                        ),
                      ActionChip(
                        avatar: const Icon(Icons.bookmark_add_outlined),
                        label: Text(l.exportPresetSave),
                        onPressed: valid ? _savePreset : null,
                      ),
                    ],
                  ),
                ),
                section(
                  ImportExportSettings.csvDelimiter.label(l),
                  chips(
                    CsvDelimiter.values,
                    _opts.delimiter,
                    (v) => delimiterLabel(l, v),
                    (v) => _opts = _opts.copyWith(delimiter: v),
                  ),
                ),
                section(
                  ImportExportSettings.csvEncoding.label(l),
                  chips(
                    CsvEncoding.values,
                    _opts.encoding,
                    (v) => encodingLabel(l, v),
                    (v) => _opts = _opts.copyWith(encoding: v),
                  ),
                ),
                section(
                  ImportExportSettings.csvDateFormat.label(l),
                  chips(
                    {...csvDateFormats(), _opts.dateFormat}.toList(),
                    _opts.dateFormat,
                    (v) => v,
                    (v) => _opts = _opts.copyWith(dateFormat: v),
                  ),
                ),
                section(
                  ImportExportSettings.csvDecimalSeparator.label(l),
                  chips(
                    DecimalSeparator.values,
                    _opts.decimalSeparator,
                    (v) => decimalLabel(l, v),
                    (v) => _opts = _opts.copyWith(decimalSeparator: v),
                  ),
                ),
                const SizedBox(height: Space.xs),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: Space.listInset,
                  ),
                  title: Text(l.exportHeaderRow),
                  value: _opts.header,
                  onChanged: (v) =>
                      setState(() => _opts = _opts.copyWith(header: v)),
                ),
                section(
                  l.exportColumns,
                  Text(
                    valid ? l.exportColumnsHint : l.exportColumnsMin,
                    style: context.text.bodySmall?.copyWith(
                      color: valid
                          ? context.colors.onSurfaceVariant
                          : context.colors.error,
                    ),
                  ),
                ),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: _order.length,
                  onReorderItem: (from, to) => setState(() {
                    final k = _order.removeAt(from);
                    _order.insert(to, k);
                  }),
                  itemBuilder: (context, i) {
                    final key = _order[i];
                    return CheckboxListTile(
                      key: ValueKey(key),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: const EdgeInsets.only(
                        left: Space.xs,
                        right: Space.xs,
                      ),
                      value: _selected.contains(key),
                      title: Text(headers[key] ?? key),
                      onChanged: (v) => setState(() {
                        if (v ?? false) {
                          _selected.add(key);
                        } else {
                          _selected.remove(key);
                        }
                      }),
                      secondary: ReorderableDragStartListener(
                        index: i,
                        child: const SizedBox(
                          width: Space.minTouch,
                          height: Space.minTouch,
                          child: Icon(Icons.drag_handle),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(Space.sm),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: Space.xs,
              runSpacing: Space.xs,
              children: [
                TextButton(
                  onPressed: () => setState(
                    () => _load(
                      widget.defaults.copyWith(locale: widget.initial.locale),
                    ),
                  ),
                  child: Text(l.exportUseDefaults),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l.commonCancel),
                ),
                FilledButton(
                  onPressed: valid
                      ? () => Navigator.pop(context, _result())
                      : null,
                  child: Text(l.exportApply),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
