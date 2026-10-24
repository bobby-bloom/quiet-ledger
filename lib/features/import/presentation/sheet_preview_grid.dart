import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/features/import/domain/import_config.dart';
import 'package:personal_finance/features/import/domain/raw_sheet.dart';
import 'package:personal_finance/features/import/domain/row_parser.dart';
import 'package:personal_finance/features/import/presentation/import_labels.dart';

/// What the preview shows.
enum PreviewMode {
  /// Every row with its class (title, header, sum row, ...).
  structure,

  /// Data rows only, columns labelled with their header.
  data,
}

/// Spreadsheet-like preview in IBM Plex Mono: column letters, row numbers,
/// skipped rows dimmed, unreadable cells in the error container colours.
/// Scrolls horizontally on narrow screens.
class SheetPreviewGrid extends StatelessWidget {
  const SheetPreviewGrid({
    required this.sheet,
    required this.config,
    super.key,
    this.parsed,
    this.mode = PreviewMode.data,
    this.maxRows = 60,
    this.headers,
  });

  final RawSheet sheet;
  final SheetConfig config;
  final ParsedSheet? parsed;
  final PreviewMode mode;
  final int maxRows;

  /// Column labels (data mode).
  final List<String>? headers;

  static const _rowHeight = 28.0;
  static const _numberWidth = 40.0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    final mono = context.mono;
    final cols = math.max(sheet.columnCount, 1);
    final classes = parsed?.classes;
    final issues = <(int, int), CellIssue>{
      for (final i in parsed?.issues ?? const <CellIssue>[])
        if (i.isError || !_quiet(i.kind)) (i.row, i.col): i,
    };

    final allRows = <int>[
      for (var r = 0; r < sheet.rowCount; r++)
        if (mode == PreviewMode.structure ||
            (classes != null &&
                r < classes.length &&
                (classes[r] == RowClass.data ||
                    classes[r] == RowClass.invalid)))
          r,
    ];
    final rows = allRows.take(maxRows).toList();

    // Column widths from content.
    final widths = List<double>.generate(cols, (c) {
      var chars = (headers != null && c < headers!.length)
          ? headers![c].length
          : 2;
      for (final r in rows.take(40)) {
        chars = math.max(chars, sheet.cell(r, c).display.length);
      }
      return (chars * 7.4 + 18).clamp(56, 240).toDouble();
    });
    final classWidth = mode == PreviewMode.structure ? 96.0 : 0.0;
    final totalWidth =
        _numberWidth + classWidth + widths.fold<double>(0, (a, b) => a + b);

    Widget headerCell(int c) {
      final mapped = config.targetOf(c);
      final label = headers != null && c < headers!.length ? headers![c] : '';
      return Container(
        width: widths[c],
        padding: const EdgeInsets.symmetric(horizontal: Space.xs),
        alignment: Alignment.centerLeft,
        child: Text(
          label.isEmpty ? columnLetter(c) : '${columnLetter(c)}  $label',
          style: mono.copyWith(
            fontWeight: FontWeight.w500,
            color: mapped == ColumnTarget.ignore
                ? colors.onSurfaceVariant
                : colors.onSurface,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      );
    }

    Widget cell(int r, int c) {
      final value = sheet.cell(r, c);
      final issue = issues[(r, c)];
      final target = config.targetOf(c);
      final numeric = value.kind == RawKind.number || _isNumericTarget(target);
      final rowClass = classes == null || r >= classes.length
          ? RowClass.data
          : classes[r];
      final dimmed =
          mode == PreviewMode.structure &&
          rowClass != RowClass.data &&
          rowClass != RowClass.invalid &&
          rowClass != RowClass.header;
      final bad = issue != null && issue.isError;
      Widget text = Text(
        value.display,
        style: mono.copyWith(
          color: bad
              ? colors.onErrorContainer
              : dimmed
              ? colors.onSurfaceVariant.withValues(alpha: 0.7)
              : colors.onSurface,
          fontWeight: rowClass == RowClass.header ? FontWeight.w500 : null,
          decoration: rowClass == RowClass.subtotal
              ? TextDecoration.lineThrough
              : null,
        ),
        textAlign: numeric ? TextAlign.right : TextAlign.left,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      );
      if (issue != null) {
        text = Tooltip(
          message: '${l.importIssueLabel(issue.kind)}: ${value.display}',
          child: text,
        );
      }
      return Container(
        width: widths[c],
        height: _rowHeight,
        padding: const EdgeInsets.symmetric(horizontal: Space.xs),
        alignment: numeric ? Alignment.centerRight : Alignment.centerLeft,
        decoration: bad
            ? BoxDecoration(
                color: colors.errorContainer,
                border: Border.all(color: colors.error, width: 1.5),
              )
            : issue != null
            ? BoxDecoration(color: context.finance.warningContainer)
            : null,
        child: text,
      );
    }

    Widget rowWidget(int r) {
      final rowClass = classes == null || r >= classes.length
          ? RowClass.data
          : classes[r];
      final isHeader = rowClass == RowClass.header;
      return Container(
        height: _rowHeight,
        decoration: BoxDecoration(
          color: isHeader ? colors.surfaceContainerHigh : null,
          border: Border(top: BorderSide(color: colors.surfaceContainer)),
        ),
        child: Row(
          children: [
            Container(
              width: _numberWidth,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: colors.surfaceContainerHigh),
                ),
              ),
              child: Text(
                '${r + 1}',
                style: mono.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
            if (mode == PreviewMode.structure)
              Container(
                width: classWidth,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.centerLeft,
                child: rowClass == RowClass.data
                    ? null
                    : Text(
                        l.importRowClassLabel(rowClass),
                        style: context.text.labelSmall?.copyWith(
                          color: rowClass == RowClass.invalid
                              ? colors.error
                              : colors.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
            for (var c = 0; c < cols; c++) cell(r, c),
          ],
        ),
      );
    }

    final grid = SizedBox(
      width: totalWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: _rowHeight + 4,
            child: Row(
              children: [
                const SizedBox(width: _numberWidth),
                if (mode == PreviewMode.structure) SizedBox(width: classWidth),
                for (var c = 0; c < cols; c++) headerCell(c),
              ],
            ),
          ),
          for (final r in rows) rowWidget(r),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceContainerLowest,
            border: Border.all(color: colors.surfaceContainerHighest),
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Radii.md),
            child: Scrollbar(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                primary: false,
                child: grid,
              ),
            ),
          ),
        ),
        if (allRows.length > rows.length)
          Padding(
            padding: const EdgeInsets.only(top: Space.xxs),
            child: Text(
              l.importPreviewMore(rows.length, allRows.length),
              style: context.text.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  static bool _quiet(IssueKind k) =>
      k == IssueKind.yearMismatch || k == IssueKind.badStatus;

  static bool _isNumericTarget(ColumnTarget t) =>
      t == ColumnTarget.amount ||
      t == ColumnTarget.debit ||
      t == ColumnTarget.credit ||
      t == ColumnTarget.balance;
}
