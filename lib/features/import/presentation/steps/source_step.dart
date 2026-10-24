import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/csv/file_output.dart';
import 'package:personal_finance/features/import/data/profile_repository.dart';
import 'package:personal_finance/features/import/domain/csv_parser.dart';
import 'package:personal_finance/features/import/domain/raw_sheet.dart';
import 'package:personal_finance/features/import/domain/source_reader.dart';
import 'package:personal_finance/features/import/presentation/import_labels.dart';
import 'package:personal_finance/features/import/presentation/import_wizard_controller.dart';
import 'package:personal_finance/features/import/presentation/import_wizard_screen.dart';

/// Step 1: files or clipboard paste, profile selection.
class SourceStep extends ConsumerStatefulWidget {
  const SourceStep({super.key});

  @override
  ConsumerState<SourceStep> createState() => _SourceStepState();
}

class _SourceStepState extends ConsumerState<SourceStep> {
  final _paste = TextEditingController();

  @override
  void dispose() {
    _paste.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'xlsx',
        'xlsm',
        'xls',
        'csv',
        'tsv',
        'txt',
        'tab',
        'ods',
        'numbers',
      ],
    );
    if (files.isEmpty) return;
    final loaded = <(String, Uint8List)>[
      for (final f in files) (f.name, await f.readAsBytes()),
    ];
    await ref.read(importWizardProvider.notifier).addFiles(loaded);
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (!mounted) return;
    if (text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.importPasteEmpty)));
      return;
    }
    _paste.text = text;
    setState(() {});
  }

  Future<void> _loadProfileFile() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final file = await pickFileBytes(extensions: const ['json']);
    if (file == null) return;
    final ok = await ref
        .read(importWizardProvider.notifier)
        .importProfileFile(utf8.decode(file.bytes, allowMalformed: true));
    messenger.showSnackBar(
      SnackBar(
        content: Text(ok ? l.importProfileImported : l.importProfileInvalid),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = ref.watch(importWizardProvider);
    final c = ref.read(importWizardProvider.notifier);
    final profiles = ref.watch(importProfilesProvider).value ?? const [];

    return StepScaffold(
      intro: l.importSourceIntro,
      children: [
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: s.busy ? null : () => c.run(_pick),
              icon: const Icon(Icons.upload_file_outlined),
              label: Text(l.importPickFiles),
            ),
            Text(
              l.importPickFilesHint,
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        StepSection(l.importPasteTitle),
        SectionCard(
          padding: const EdgeInsets.all(Space.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.importPasteHint, style: context.text.bodySmall),
              const SizedBox(height: Space.xs),
              TextField(
                controller: _paste,
                minLines: 3,
                maxLines: 8,
                style: context.mono,
                decoration: InputDecoration(
                  labelText: l.importPasteField,
                  alignLabelWithHint: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: Space.xs),
              Wrap(
                spacing: Space.xs,
                alignment: WrapAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => c.run(_pasteFromClipboard),
                    icon: const Icon(Icons.content_paste),
                    label: Text(l.importPasteButton),
                  ),
                  FilledButton.tonal(
                    onPressed: _paste.text.trim().isEmpty || s.busy
                        ? null
                        : () => c.run(() async {
                            await c.addPaste(_paste.text);
                            _paste.clear();
                            if (mounted) setState(() {});
                          }),
                    child: Text(l.importPasteAdd),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (s.sources.isNotEmpty) ...[
          StepSection(l.importFilesTitle),
          for (var i = 0; i < s.sources.length; i++)
            _SourceTile(index: i, source: s.sources[i]),
        ],
        StepSection(l.importProfileUse),
        DropdownButtonFormField<String?>(
          initialValue: profiles.any((p) => p.id == s.profileId)
              ? s.profileId
              : null,
          isExpanded: true,
          decoration: InputDecoration(helperText: l.importProfileHint),
          items: [
            DropdownMenuItem(child: Text(l.importProfileNone)),
            for (final p in profiles)
              DropdownMenuItem(value: p.id, child: Text(p.name)),
          ],
          onChanged: s.busy ? null : (id) => c.run(() => c.useProfile(id)),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => c.run(_loadProfileFile),
            icon: const Icon(Icons.file_open_outlined),
            label: Text(l.importProfileLoadFile),
          ),
        ),
      ],
    );
  }
}

class _SourceTile extends ConsumerWidget {
  const _SourceTile({required this.index, required this.source});

  final int index;
  final LoadedSource source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = ref.read(importWizardProvider.notifier);
    final wb = source.workbook;
    final error = source.error;
    final colors = context.colors;
    String subtitle;
    if (error != null) {
      subtitle = l.importReadErrorLabel(error.error);
    } else if (wb!.dialect != null) {
      final rows = wb.sheets.fold<int>(0, (n, s) => n + s.rowCount);
      subtitle =
          '${l.importRows(rows)} · ${l.importFileCsvInfo(l.importEncodingLabel(wb.dialect!.encoding), l.importDelimiterLabel(wb.dialect!.delimiter))}';
    } else {
      final rows = wb.sheets.fold<int>(0, (n, s) => n + s.rowCount);
      subtitle =
          '${l.importFileSheets(wb.sheets.length)} · ${l.importRows(rows)}';
    }
    return Card(
      color: error != null ? colors.errorContainer : null,
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              error != null
                  ? Icons.error_outline
                  : source.isCsv
                  ? Icons.description_outlined
                  : Icons.table_chart_outlined,
              color: error != null ? colors.onErrorContainer : null,
            ),
            title: Text(
              source.source.name,
              style: error != null
                  ? TextStyle(color: colors.onErrorContainer)
                  : null,
            ),
            subtitle: Text(
              subtitle,
              style: error != null
                  ? TextStyle(color: colors.onErrorContainer)
                  : null,
            ),
            trailing: IconButton(
              tooltip: l.importRemoveFile,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => c.run(() => c.removeSource(index)),
            ),
          ),
          if (source.isCsv && source.source.bytes != null)
            _CsvOptions(index: index, source: source),
        ],
      ),
    );
  }
}

class _CsvOptions extends ConsumerWidget {
  const _CsvOptions({required this.index, required this.source});

  final int index;
  final LoadedSource source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = ref.read(importWizardProvider.notifier);
    final o = source.csv;
    void set(CsvReadOptions n) => c.run(() => c.setCsvOptions(index, n));
    return ExpansionTile(
      title: Text(l.importCsvOptions, style: context.text.labelLarge),
      childrenPadding: const EdgeInsets.fromLTRB(
        Space.md,
        0,
        Space.md,
        Space.md,
      ),
      children: [
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<TextEncoding>(
                initialValue: o.encoding,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.importEncoding),
                items: [
                  for (final e in TextEncoding.values)
                    DropdownMenuItem(
                      value: e,
                      child: Text(l.importEncodingLabel(e)),
                    ),
                ],
                onChanged: (e) => set(
                  CsvReadOptions(
                    encoding: e ?? TextEncoding.auto,
                    delimiter: o.delimiter,
                    quote: o.quote,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<String?>(
                initialValue: o.delimiter,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.importDelimiter),
                items: [
                  DropdownMenuItem(child: Text(l.importAuto)),
                  for (final d in csvDelimiters)
                    DropdownMenuItem(
                      value: d,
                      child: Text(l.importDelimiterLabel(d)),
                    ),
                ],
                onChanged: (d) => set(
                  CsvReadOptions(
                    encoding: o.encoding,
                    delimiter: d,
                    quote: o.quote,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<String?>(
                initialValue: o.quote,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.importQuote),
                items: [
                  DropdownMenuItem(child: Text(l.importAuto)),
                  const DropdownMenuItem(value: '"', child: Text('"')),
                  const DropdownMenuItem(value: "'", child: Text("'")),
                ],
                onChanged: (q) => set(
                  CsvReadOptions(
                    encoding: o.encoding,
                    delimiter: o.delimiter,
                    quote: q,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
