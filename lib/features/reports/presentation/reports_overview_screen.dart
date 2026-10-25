import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/breakpoints.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/features/reports/domain/report_models.dart';
import 'package:personal_finance/features/reports/presentation/report_format.dart';
import 'package:personal_finance/features/reports/presentation/report_views.dart';

/// `/reports`: one card per report with a small live preview. Grid on
/// medium/expanded windows, a single column on phones.
class ReportsOverviewScreen extends ConsumerWidget {
  const ReportsOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = WindowSize.of(context);
    final gutter = size.isCompact ? Space.phoneGutter : Space.desktopGutter;
    return Scaffold(
      appBar: PageAppBar(title: context.l10n.reportsTitle),
      body: LayoutBuilder(
        builder: (context, box) {
          final columns = box.maxWidth >= 1100
              ? 3
              : box.maxWidth >= 600
              ? 2
              : 1;
          return GridView.builder(
            padding: EdgeInsets.fromLTRB(gutter, Space.md, gutter, Space.xxl),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: Space.cardGap,
              crossAxisSpacing: Space.cardGap,
              mainAxisExtent: 236,
            ),
            itemCount: ReportType.values.length,
            itemBuilder: (context, i) => ReportCard(type: ReportType.values[i]),
          );
        },
      ),
    );
  }
}

/// A report card with title, period and a preview; opens the report.
class ReportCard extends ConsumerWidget {
  const ReportCard({required this.type, super.key});

  final ReportType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ReportFormat.of(context, ref);
    final content = watchReportContent(context, ref, type);
    final title = reportTitle(context, type);
    final range = reportRange(ref, type);
    final data = content.value;
    return Semantics(
      button: true,
      label: '$title, ${fmt.range(range)}. ${data?.summary ?? ''}',
      excludeSemantics: true,
      child: SectionCard(
        title: title,
        subtitle: fmt.range(range),
        onTap: () => context.push('/reports/${type.slug}'),
        padding: const EdgeInsets.fromLTRB(
          Space.cardPadding,
          Space.xxs,
          Space.cardPadding,
          Space.cardPadding,
        ),
        child: SizedBox(
          height: 168,
          child: data != null
              ? data.preview
              : content.hasError
              ? Center(
                  child: Icon(Icons.error_outline, color: context.colors.error),
                )
              : Center(
                  child: Icon(
                    reportIcon(type),
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
        ),
      ),
    );
  }
}
