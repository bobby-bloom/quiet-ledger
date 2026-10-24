import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/breakpoints.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/features/reports/domain/report_models.dart';
import 'package:personal_finance/features/reports/presentation/report_export.dart';
import 'package:personal_finance/features/reports/presentation/report_providers.dart';
import 'package:personal_finance/features/reports/presentation/report_views.dart';
import 'package:personal_finance/features/reports/presentation/widgets/report_filter_bar.dart';
import 'package:personal_finance/features/reports/presentation/widgets/report_table_view.dart';

/// `/reports/:type`: filter bar, chart and data table of one report. On
/// expanded windows the chart and the table sit side by side.
class ReportDetailScreen extends ConsumerWidget {
  const ReportDetailScreen({required this.type, super.key});

  final ReportType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final kind = ref.watch(reportViewProvider(type).select((s) => s.kind));
    final range = ref.watch(reportViewProvider(type).select((s) => s.range));
    final title = reportTitle(context, type, kind: kind);
    final content = watchReportContent(context, ref, type);
    final size = WindowSize.of(context);
    final gutter = size.isCompact ? Space.phoneGutter : Space.desktopGutter;
    final data = content.value;

    final filters = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReportFilterBar(type: type),
        if (type != ReportType.netWorth) ...[
          const SizedBox(height: Space.xs),
          ReportOptionsBar(type: type),
        ],
      ],
    );

    Widget chartCard(ReportContent c) => SectionCard(
      padding: const EdgeInsets.all(Space.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (c.header != null) ...[
            c.header!,
            const SizedBox(height: Space.md),
          ],
          c.chart,
        ],
      ),
    );

    Widget tableCard(ReportContent c) => SectionCard(
      title: l.reportsData,
      child: c.table.rows.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.lg),
              child: Text(
                l.reportsNoData,
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            )
          : ReportTableView(
              table: c.table,
              onDrill: c.onDrill,
              drillTooltip: c.drillTooltip,
            ),
    );

    Widget body;
    if (data == null) {
      body = ListView(
        padding: EdgeInsets.all(gutter),
        children: [
          filters,
          const SizedBox(height: Space.md),
          AsyncView<ReportContent>(
            value: content,
            data: (_) => const SizedBox.shrink(),
            loading: const Padding(
              padding: EdgeInsets.all(Space.xxl),
              child: Center(child: CircularProgressIndicator.adaptive()),
            ),
          ),
        ],
      );
    } else if (size.isExpanded) {
      body = Padding(
        padding: EdgeInsets.fromLTRB(gutter, Space.md, gutter, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            filters,
            const SizedBox(height: Space.md),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: data.table.columns.length >= 5 ? 1 : 3,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: Space.xl),
                      child: chartCard(data),
                    ),
                  ),
                  const SizedBox(width: Space.lg),
                  Expanded(
                    flex: data.table.columns.length >= 5 ? 1 : 2,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: Space.xl),
                      child: tableCard(data),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      body = ListView(
        padding: EdgeInsets.fromLTRB(gutter, Space.md, gutter, Space.xxl),
        children: [
          filters,
          const SizedBox(height: Space.md),
          chartCard(data),
          const SizedBox(height: Space.md),
          tableCard(data),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          Builder(
            builder: (btnContext) => IconButton(
              tooltip: l.reportsExportCsv,
              icon: const Icon(Icons.file_download_outlined),
              onPressed: data == null
                  ? null
                  : () => exportReportCsv(
                      btnContext,
                      ref,
                      type: type,
                      range: range,
                      table: data.table,
                    ),
            ),
          ),
        ],
      ),
      body: body,
    );
  }
}
