import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/amount_text.dart';
import 'package:personal_finance/features/reports/domain/report_table.dart';
import 'package:personal_finance/features/reports/presentation/report_format.dart';

/// Renders a [ReportTable]: hairline rows, numeric columns right-aligned
/// with tabular figures, horizontal scrolling when the columns do not fit.
/// Rows with a link open it (the transactions list); rows with a drill id
/// get a chevron that calls [onDrill].
class ReportTableView extends ConsumerWidget {
  const ReportTableView({
    required this.table,
    super.key,
    this.onDrill,
    this.drillTooltip,
  });

  final ReportTable table;
  final ValueChanged<String>? onDrill;
  final String? drillTooltip;

  static const _firstMin = 120.0;
  static const _numMin = 88.0;
  static const _numMax = 112.0;
  static const _drillWidth = 44.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ReportFormat.of(context, ref);
    final hasDrill = onDrill != null && table.rows.any((r) => r.drill != null);
    final otherCols = table.columns.length - 1;
    final fixed = _firstMin + (hasDrill ? _drillWidth : 0);
    return LayoutBuilder(
      builder: (context, box) {
        final numWidth = otherCols == 0
            ? _numMax
            : ((box.maxWidth - fixed) / otherCols).clamp(_numMin, _numMax);
        final width = math.max(fixed + otherCols * numWidth, box.maxWidth);
        final content = SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(context, hasDrill, numWidth),
              for (final r in table.rows)
                _row(context, fmt, r, hasDrill, numWidth),
            ],
          ),
        );
        if (width <= box.maxWidth) return content;
        return Scrollbar(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: content,
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context, bool hasDrill, double numWidth) {
    final style = context.text.labelMedium?.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    return Semantics(
      header: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 36),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: context.colors.outlineVariant),
          ),
        ),
        child: Row(
          children: [
            for (var i = 0; i < table.columns.length; i++)
              _cellBox(
                i,
                numWidth,
                Text(
                  table.columns[i].label,
                  style: style,
                  textAlign: table.columns[i].numeric
                      ? TextAlign.right
                      : TextAlign.left,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (hasDrill) const SizedBox(width: _drillWidth),
          ],
        ),
      ),
    );
  }

  Widget _cellBox(int i, double numWidth, Widget child) {
    final numeric = table.columns[i].numeric;
    final padded = Padding(
      padding: EdgeInsets.only(
        left: i == 0 ? 0 : Space.xs,
        top: Space.xs,
        bottom: Space.xs,
      ),
      child: Align(
        alignment: numeric ? Alignment.centerRight : Alignment.centerLeft,
        // Numbers never clip: they shrink when a column is too narrow.
        child: numeric && i > 0
            ? FittedBox(fit: BoxFit.scaleDown, child: child)
            : child,
      ),
    );
    if (i == 0) return Expanded(child: padded);
    return SizedBox(width: numWidth, child: padded);
  }

  Widget _row(
    BuildContext context,
    ReportFormat fmt,
    ReportRow r,
    bool hasDrill,
    double numWidth,
  ) {
    final base = (context.text.bodyMedium ?? const TextStyle()).copyWith(
      fontWeight: r.emphasis ? FontWeight.w700 : null,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    Widget cell(ReportCell c) => switch (c.kind) {
      CellKind.text => Text(
        c.text ?? '',
        style: base,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      CellKind.money => AmountText(
        c.number!,
        colored: false,
        explicitPlus: c.signed,
        style: base,
        textAlign: TextAlign.right,
      ),
      CellKind.count => Text('${c.number}', style: base),
      CellKind.percent => Text(
        c.number == null ? '–' : fmt.percent(c.number!, signed: c.signed),
        style: base,
      ),
      CellKind.date => Text(fmt.dates.short(c.date!), style: base),
    };
    final link = r.link;
    final row = Container(
      constraints: const BoxConstraints(minHeight: Space.minTouch),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: r.emphasis
                ? context.colors.outlineVariant
                : context.colors.surfaceContainerHigh,
          ),
        ),
      ),
      child: Row(
        children: [
          for (var i = 0; i < r.cells.length; i++)
            _cellBox(i, numWidth, cell(r.cells[i])),
          if (hasDrill)
            SizedBox(
              width: _drillWidth,
              child: r.drill == null
                  ? null
                  : IconButton(
                      tooltip: drillTooltip,
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => onDrill!(r.drill!),
                    ),
            ),
        ],
      ),
    );
    if (link == null) return row;
    return InkWell(onTap: () => context.go(link), child: row);
  }
}
