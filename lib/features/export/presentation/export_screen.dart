import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/breakpoints.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/app/ui/pickers.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/csv/csv_writer.dart';
import 'package:personal_finance/core/csv/file_output.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/platform/capabilities.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/export/data/transaction_export.dart';
import 'package:personal_finance/features/export/domain/export_period.dart';
import 'package:personal_finance/features/export/domain/txn_export.dart';
import 'package:personal_finance/features/export/presentation/backup_health_banner.dart';
import 'package:personal_finance/features/export/presentation/csv_options_sheet.dart';
import 'package:personal_finance/features/export/presentation/export_labels.dart';
import 'package:personal_finance/features/export/presentation/restore_flow.dart';

/// Rows shown in the preview.
const _previewRows = 20;

/// Custom fields that apply to transactions (for columns).
final _txnFieldsProvider = FutureProvider.autoDispose<List<TxnExportField>>(
  (ref) => txnExportFields(ref.watch(databaseProvider)),
);

/// Settings › Import / export › Export (`/more/export`): transaction CSV
/// with options and preview, full backup, restore and the auto-backup
/// shortcut.
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  ExportPeriod _period = ExportPeriod.thisYear;
  DateTimeRange? _custom;
  Set<String>? _accounts;
  TxnExportLayout _layout = TxnExportLayout.flat;
  CsvOptions? _options;
  bool _busy = false;
  Future<_Preview>? _preview;
  Object? _previewKey;

  CsvOptions _defaults() => CsvOptions.fromSettings(
    ref.read(settingsProvider),
    locale: ref.read(formatLocaleProvider),
  );

  CsvOptions get _opts => _options ??= _defaults();

  TxnExportQuery get _query {
    final r = exportPeriodRange(
      _period,
      DateTime.now(),
      customStart: _custom?.start,
      customEnd: _custom?.end,
    );
    return TxnExportQuery(start: r.start, end: r.end, accountIds: _accounts);
  }

  Future<_Preview> _loadPreview(
    TxnExportQuery query,
    CsvOptions options,
    TxnExportLabels labels,
  ) async {
    final db = ref.read(databaseProvider);
    final fields = await txnExportFields(db);
    final rows = await loadTxnExportRows(db, query.withLimit(_previewRows));
    final cols = CsvWriter.selectColumns(
      txnExportColumns(labels, customFields: fields),
      options.columns,
    );
    final writer = CsvWriter(options);
    return _Preview(
      headers: [for (final c in cols) c.header],
      rows: [
        for (final r in rows.take(_previewRows))
          [for (final c in cols) writer.formatValue(c.value(r))],
      ],
    );
  }

  /// Recomputes the preview when inputs changed.
  Future<_Preview> _previewFor(TxnExportLabels labels) {
    final key = (_query, _opts, labels.headers[TxnColumnKeys.date]);
    if (_preview == null || key != _previewKey) {
      _previewKey = key;
      _preview = _loadPreview(_query, _opts, labels);
    }
    return _preview!;
  }

  Rect? _originOf(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportCsv(BuildContext buttonContext) => _run(() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final origin = _originOf(buttonContext);
    try {
      final file = await exportTransactions(
        ref.read(databaseProvider),
        query: _query,
        options: _opts,
        labels: txnExportLabels(l),
        layout: _layout,
      );
      final r = await saveOrShareBytes(
        bytes: file.bytes,
        fileName: file.fileName,
        mimeType: file.mimeType,
        capabilities: ref.read(platformCapabilitiesProvider),
        sharePositionOrigin: origin,
      );
      final msg = switch (r.outcome) {
        SaveOutcome.saved =>
          r.location == null ? l.exportSavedShort : l.exportSaved(r.location!),
        SaveOutcome.shared => l.exportShared,
        SaveOutcome.downloaded => l.exportDownloaded,
        SaveOutcome.cancelled => null,
      };
      if (msg != null) {
        messenger.showSnackBar(
          SnackBar(content: Text('$msg · ${l.exportRows(file.rowCount)}')),
        );
      }
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.exportFailed('$e'))));
    }
  });

  Future<void> _editOptions(List<TxnExportField> fields) async {
    final labels = txnExportLabels(context.l10n);
    final cols = txnExportColumns(labels, customFields: fields);
    final r = await showCsvOptionsSheet(
      context,
      initial: _opts,
      defaults: _defaults(),
      columns: [for (final c in cols) (key: c.key, header: c.header)],
    );
    if (r != null && mounted) setState(() => _options = r);
  }

  Future<void> _pickPeriod(ExportPeriod p) async {
    if (p != ExportPeriod.custom) {
      setState(() => _period = p);
      return;
    }
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1990),
      lastDate: DateTime(now.year + 10),
      initialDateRange:
          _custom ??
          DateTimeRange(start: DateTime(now.year, now.month), end: now),
    );
    if (r != null && mounted) {
      setState(() {
        _custom = r;
        _period = ExportPeriod.custom;
      });
    }
  }

  Future<void> _pickAccounts() async {
    final r = await showAccountMultiPicker(
      context,
      selected: _accounts ?? const {},
    );
    if (r == null || !mounted) return;
    setState(() => _accounts = r.isEmpty ? null : r);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final size = WindowSize.of(context);
    final labels = txnExportLabels(l);
    final fields = ref.watch(_txnFieldsProvider).value ?? const [];
    final caps = ref.watch(platformCapabilitiesProvider);
    final gutter = size.isCompact ? Space.phoneGutter : Space.desktopGutter;

    final txnCard = _TxnCard(
      period: _period,
      custom: _custom,
      accounts: _accounts,
      layout: _layout,
      options: _opts,
      columnTotal: TxnColumnKeys.fixed.length + fields.length + 1,
      busy: _busy,
      onPeriod: _pickPeriod,
      onAccounts: _pickAccounts,
      onAllAccounts: () => setState(() => _accounts = null),
      onLayout: (v) => setState(() => _layout = v),
      onOptions: () => _editOptions(fields),
      onExport: _exportCsv,
    );
    final preview = _PreviewCard(preview: _previewFor(labels));
    final backup = _BackupCard(
      busy: _busy,
      onBackup: (ctx) => _run(() async {
        await createBackup(context, ref, origin: _originOf(ctx));
      }),
      onRestore: (ctx) => _run(() async {
        await startRestore(context, ref, origin: _originOf(ctx));
        // Data may have been replaced: reload fields and preview.
        ref.invalidate(_txnFieldsProvider);
        _preview = null;
      }),
    );
    final auto = caps.chooseFolder ? const _AutoExportCard() : null;
    final banner = BackupHealthBanner(
      onBackUp: () => _run(() async {
        await createBackup(context, ref);
      }),
    );

    final Widget body;
    if (size.isExpanded) {
      final columns = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                txnCard,
                const SizedBox(height: Space.md),
                backup,
                if (auto != null) ...[const SizedBox(height: Space.md), auto],
              ],
            ),
          ),
          const SizedBox(width: Space.xl),
          Expanded(flex: 6, child: preview),
        ],
      );
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [banner, columns],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          banner,
          txnCard,
          const SizedBox(height: Space.md),
          preview,
          const SizedBox(height: Space.md),
          backup,
          if (auto != null) ...[const SizedBox(height: Space.md), auto],
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.exportTitle)),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(gutter, Space.xs, gutter, Space.xxl),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}

class _Preview {
  const _Preview({required this.headers, required this.rows});
  final List<String> headers;
  final List<List<String>> rows;
}

/// Section title + muted description inside a card.
class _CardIntro extends StatelessWidget {
  const _CardIntro({required this.description});
  final String description;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.sm),
    child: Text(
      description,
      style: context.text.bodyMedium?.copyWith(
        color: context.colors.onSurfaceVariant,
      ),
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Space.sm, bottom: Space.xs),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: context.text.labelLarge?.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
      ),
    ),
  );
}

class _TxnCard extends ConsumerWidget {
  const _TxnCard({
    required this.period,
    required this.custom,
    required this.accounts,
    required this.layout,
    required this.options,
    required this.columnTotal,
    required this.busy,
    required this.onPeriod,
    required this.onAccounts,
    required this.onAllAccounts,
    required this.onLayout,
    required this.onOptions,
    required this.onExport,
  });

  final ExportPeriod period;
  final DateTimeRange? custom;
  final Set<String>? accounts;
  final TxnExportLayout layout;
  final CsvOptions options;
  final int columnTotal;
  final bool busy;
  final ValueChanged<ExportPeriod> onPeriod;
  final VoidCallback onAccounts;
  final VoidCallback onAllAccounts;
  final ValueChanged<TxnExportLayout> onLayout;
  final VoidCallback onOptions;
  final void Function(BuildContext buttonContext) onExport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final dates = ref.watch(dateFormatsProvider);
    String periodLabel(ExportPeriod p) => switch (p) {
      ExportPeriod.thisMonth => l.exportPeriodThisMonth,
      ExportPeriod.lastMonth => l.exportPeriodLastMonth,
      ExportPeriod.thisYear => l.exportPeriodThisYear,
      ExportPeriod.lastYear => l.exportPeriodLastYear,
      ExportPeriod.last12Months => l.exportPeriodLast12Months,
      ExportPeriod.all => l.exportPeriodAll,
      ExportPeriod.custom =>
        custom == null
            ? l.exportPeriodCustom
            : l.exportPeriodRange(
                dates.short(custom!.start),
                dates.short(custom!.end),
              ),
    };
    final selectedColumns = options.columns?.length ?? columnTotal;
    final optionSummary = [
      delimiterLabel(l, options.delimiter),
      encodingLabel(l, options.encoding),
      options.dateFormat,
      decimalLabel(l, options.decimalSeparator),
      l.exportColumnsSummary(
        selectedColumns.clamp(0, columnTotal),
        columnTotal,
      ),
    ].join(' · ');

    return SectionCard(
      title: l.exportTxnTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardIntro(description: l.exportTxnDesc),
          _FieldLabel(l.exportPeriod),
          Wrap(
            spacing: Space.xs,
            runSpacing: Space.xs,
            children: [
              for (final p in ExportPeriod.values)
                ChoiceChip(
                  label: Text(periodLabel(p)),
                  selected: p == period,
                  onSelected: busy ? null : (_) => onPeriod(p),
                ),
            ],
          ),
          _FieldLabel(l.exportAccounts),
          Wrap(
            spacing: Space.xs,
            runSpacing: Space.xs,
            children: [
              ChoiceChip(
                label: Text(l.exportAccountsAll),
                selected: accounts == null,
                onSelected: busy ? null : (_) => onAllAccounts(),
              ),
              ChoiceChip(
                avatar: const Icon(Icons.account_balance_wallet_outlined),
                label: Text(
                  accounts == null
                      ? l.exportAccounts
                      : l.exportAccountsSelected(accounts!.length),
                ),
                selected: accounts != null,
                onSelected: busy ? null : (_) => onAccounts(),
              ),
            ],
          ),
          _FieldLabel(l.exportFiles),
          SegmentedButton<TxnExportLayout>(
            segments: [
              ButtonSegment(
                value: TxnExportLayout.flat,
                icon: const Icon(Icons.description_outlined),
                label: Text(l.exportLayoutFlat),
              ),
              ButtonSegment(
                value: TxnExportLayout.perAccount,
                icon: const Icon(Icons.folder_zip_outlined),
                label: Text(l.exportLayoutPerAccount),
              ),
            ],
            selected: {layout},
            onSelectionChanged: busy ? null : (s) => onLayout(s.first),
          ),
          if (layout == TxnExportLayout.perAccount)
            Padding(
              padding: const EdgeInsets.only(top: Space.xxs),
              child: Text(
                l.exportLayoutPerAccountHint,
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: Space.sm),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.tune),
            title: Text(l.exportOptions),
            subtitle: Text(optionSummary),
            trailing: const Icon(Icons.chevron_right),
            onTap: busy ? null : onOptions,
          ),
          const SizedBox(height: Space.xs),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Builder(
              builder: (btn) => FilledButton.icon(
                onPressed: busy ? null : () => onExport(btn),
                icon: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.file_download_outlined),
                label: Text(
                  layout == TxnExportLayout.flat ? l.exportRun : l.exportRunZip,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.preview});
  final Future<_Preview> preview;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return FutureBuilder<_Preview>(
      future: preview,
      builder: (context, snap) {
        final data = snap.data;
        Widget child;
        if (snap.hasError) {
          child = Padding(
            padding: const EdgeInsets.all(Space.md),
            child: Text(
              l.commonError('${snap.error}'),
              style: TextStyle(color: context.colors.error),
            ),
          );
        } else if (data == null) {
          child = const Padding(
            padding: EdgeInsets.all(Space.xl),
            child: Center(child: CircularProgressIndicator.adaptive()),
          );
        } else if (data.rows.isEmpty) {
          child = EmptyState(
            icon: Icons.table_rows_outlined,
            message: l.exportPreviewEmpty,
          );
        } else {
          final cell = context.mono;
          child = Scrollbar(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              primary: false,
              child: DataTable(
                headingRowHeight: 36,
                dataRowMinHeight: 32,
                dataRowMaxHeight: 36,
                horizontalMargin: Space.xs,
                columnSpacing: Space.lg,
                columns: [
                  for (final h in data.headers)
                    DataColumn(label: Text(h, style: context.text.labelMedium)),
                ],
                rows: [
                  for (final r in data.rows)
                    DataRow(
                      cells: [
                        for (final c in r)
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 220),
                              child: Text(
                                c,
                                style: cell,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          );
        }
        return SectionCard(
          title: l.exportPreview,
          subtitle: data == null || data.rows.isEmpty
              ? null
              : l.exportPreviewHint(data.rows.length),
          child: Semantics(
            container: true,
            label: l.exportPreview,
            child: child,
          ),
        );
      },
    );
  }
}

class _BackupCard extends StatelessWidget {
  const _BackupCard({
    required this.busy,
    required this.onBackup,
    required this.onRestore,
  });

  final bool busy;
  final void Function(BuildContext buttonContext) onBackup;
  final void Function(BuildContext buttonContext) onRestore;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SectionCard(
      title: l.exportBackupTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardIntro(description: l.exportBackupDesc),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: Space.xs,
            runSpacing: Space.xs,
            children: [
              TextButton.icon(
                onPressed: busy
                    ? null
                    : () => context.push('/more/export/safety'),
                icon: const Icon(Icons.shield_outlined),
                label: Text(l.backupSafetyTitle),
              ),
              Builder(
                builder: (btn) => OutlinedButton.icon(
                  onPressed: busy ? null : () => onRestore(btn),
                  icon: const Icon(Icons.settings_backup_restore),
                  label: Text(l.exportRestoreRun),
                ),
              ),
              Builder(
                builder: (btn) => FilledButton.tonalIcon(
                  onPressed: busy ? null : () => onBackup(btn),
                  icon: const Icon(Icons.archive_outlined),
                  label: Text(l.exportBackupRun),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AutoExportCard extends ConsumerWidget {
  const _AutoExportCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(settingsProvider);
    final schedule = s.get(ImportExportSettings.autoExport);
    final folder = s.get(ImportExportSettings.autoExportFolder);
    final keep = s.get(ImportExportSettings.autoExportKeep);
    final last = DateTime.tryParse(
      s.get(ImportExportSettings.lastAutoExport) ?? '',
    );
    final dates = ref.watch(dateFormatsProvider);
    final lines = [
      if (schedule == AutoExportSchedule.off)
        scheduleLabel(l, schedule)
      else
        '${scheduleLabel(l, schedule)} · ${l.exportAutoKeepValue(keep)}',
      if (folder == null || folder.isEmpty) l.exportAutoNoFolder else folder,
      if (last == null)
        l.exportAutoNever
      else
        l.exportAutoLast(
          '${dates.medium(last.toLocal())} ${dates.time(last.toLocal())}',
        ),
    ];
    return SectionCard(
      title: l.exportAutoTitle,
      padding: const EdgeInsets.fromLTRB(
        Space.cardPadding,
        Space.xxs,
        Space.xxs,
        Space.xs,
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.schedule_outlined),
        title: Text(lines.first),
        subtitle: Text(lines.skip(1).join('\n')),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/more/export/folder'),
      ),
    );
  }
}
