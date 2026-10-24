import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/core/calendar/budget_period.dart';
import 'package:personal_finance/core/csv/csv_writer.dart';
import 'package:personal_finance/core/csv/file_output.dart';
import 'package:personal_finance/core/platform/capabilities.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/reports/domain/report_models.dart';
import 'package:personal_finance/features/reports/domain/report_table.dart';

String _iso(DateTime d) =>
    '${d.year}${d.month.toString().padLeft(2, '0')}'
    '${d.day.toString().padLeft(2, '0')}';

/// File name of a report export, e.g. `report-spending-20260301-20260331.csv`.
String reportFileName(ReportType type, DateRange range, CsvOptions o) =>
    'report-${type.slug}-${_iso(range.start)}-${_iso(range.last)}'
    '.${o.fileExtension}';

/// CSV options from Settings › Import / export.
CsvOptions reportCsvOptions(WidgetRef ref) => CsvOptions.fromSettings(
  ref.read(settingsProvider),
  locale: ref.read(formatLocaleProvider),
);

/// Encodes [table] with the user's CSV settings and saves/shares it.
Future<void> exportReportCsv(
  BuildContext context,
  WidgetRef ref, {
  required ReportType type,
  required DateRange range,
  required ReportTable table,
}) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final box = context.findRenderObject() as RenderBox?;
  final origin = box == null || !box.hasSize
      ? null
      : box.localToGlobal(Offset.zero) & box.size;
  final options = reportCsvOptions(ref);
  try {
    final result = await saveOrShareBytes(
      bytes: reportTableCsvBytes(table, options),
      fileName: reportFileName(type, range, options),
      mimeType: options.mimeType,
      dialogTitle: l.reportsExportCsv,
      capabilities: ref.read(platformCapabilitiesProvider),
      sharePositionOrigin: origin,
    );
    if (result.ok) {
      messenger?.showSnackBar(SnackBar(content: Text(l.reportsExported)));
    }
  } on Object catch (e) {
    messenger?.showSnackBar(
      SnackBar(content: Text(l.reportsExportFailed(e.toString()))),
    );
  }
}
