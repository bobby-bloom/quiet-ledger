import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel_plus/excel_plus.dart';
import 'package:personal_finance/features/import/domain/date_parser.dart';
import 'package:personal_finance/features/import/domain/raw_sheet.dart';

/// Reads an .xlsx / .xlsm / .xls workbook with excel_plus.
///
/// * Formula cells are read by their cached value (the result the
///   spreadsheet app saved). Formulas without a cached value read as empty
///   and are counted in [RawWorkbook.formulasWithoutValue].
/// * Numeric cells with a date format arrive as dates; formula results with
///   a date format are converted from their serial (1900 or 1904 system).
/// * Merged ranges are kept so headers can be propagated.
RawWorkbook readExcelWorkbook(
  Uint8List bytes, {
  required String fileName,
  required String fileHash,
  required bool legacyXls,
}) {
  final Excel excel;
  try {
    excel = Excel.decodeBytes(bytes);
  } on ExcelException catch (e) {
    throw ImportReadException(ImportReadError.corrupt, detail: e.message);
  } on FormatException catch (e) {
    throw ImportReadException(ImportReadError.corrupt, detail: e.message);
  } on Object catch (e) {
    // excel_plus may also throw errors on damaged files.
    throw ImportReadException(ImportReadError.corrupt, detail: '$e');
  }
  final date1904 = !legacyXls && _isDate1904(bytes);
  var noValue = 0;
  final sheets = <RawSheet>[];
  for (final entry in excel.tables.entries) {
    final sheet = entry.value;
    final rows = <List<RawCell>>[];
    for (final row in sheet.rows) {
      final cells = <RawCell>[];
      for (final data in row) {
        final (cell, missing) = _convert(data, date1904);
        if (missing) noValue++;
        cells.add(cell);
      }
      var end = cells.length;
      while (end > 0 && cells[end - 1].isEmpty) {
        end--;
      }
      rows.add(end == cells.length ? cells : cells.sublist(0, end));
    }
    while (rows.isNotEmpty && rows.last.isEmpty) {
      rows.removeLast();
    }
    final merges = <MergedRange>[];
    for (final ref in sheet.spannedItems) {
      final parts = ref.split(':');
      if (parts.length != 2) continue;
      final a = parseCellRef(parts[0]);
      final b = parseCellRef(parts[1]);
      if (a == null || b == null) continue;
      merges.add(MergedRange(a.$1, a.$2, b.$1, b.$2));
    }
    sheets.add(
      RawSheet(
        name: entry.key,
        rows: rows,
        merges: merges,
        hidden: sheet.visibility != SheetVisibility.visible,
      ),
    );
  }
  return RawWorkbook(
    fileName: fileName,
    format: legacyXls ? SourceFormat.xls : SourceFormat.xlsx,
    sheets: sheets,
    fileHash: fileHash,
    date1904: date1904,
    formulasWithoutValue: noValue,
  );
}

(RawCell, bool) _convert(Data? data, bool date1904) {
  final v = data?.value;
  if (v == null) return (RawCell.empty, false);
  switch (v) {
    case TextCellValue():
      return (RawCell.text(v.value.toString()), false);
    case IntCellValue():
      return (RawCell.number(v.value.toString()), false);
    case DoubleCellValue():
      return (RawCell.number(_double(v.value)), false);
    case DateCellValue():
      return (RawCell.date(DateTime(v.year, v.month, v.day)), false);
    case DateTimeCellValue():
      return (RawCell.date(DateTime(v.year, v.month, v.day)), false);
    case TimeCellValue():
      return (RawCell.text(v.toString()), false);
    case BoolCellValue():
      return (RawCell.boolean(v.value), false);
    case CellErrorValue():
      return (RawCell.error(v.value), false);
    case FormulaCellValue():
      final cached = v.cachedValue;
      if (cached == null || cached.isEmpty) return (RawCell.empty, true);
      if (cached.startsWith('#')) return (RawCell.error(cached), false);
      final n = num.tryParse(cached);
      if (n != null) {
        final fmt = data!.cellStyle?.numberFormat;
        if (fmt is DateTimeNumFormat) {
          final d = excelSerialToDate(n, date1904: date1904);
          if (d != null) return (RawCell.date(d), false);
        }
        return (RawCell.number(_double(n)), false);
      }
      final iso = DateTime.tryParse(cached);
      if (iso != null && RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(cached)) {
        return (RawCell.date(DateTime(iso.year, iso.month, iso.day)), false);
      }
      return (RawCell.text(cached), false);
  }
}

/// Canonical decimal text of a number: integers without `.0`, otherwise
/// Dart's shortest round-trip representation (`41.2`, not
/// `41.200000000000003`).
String _double(num v) {
  if (v is int) return v.toString();
  if (v == v.truncateToDouble() && v.abs() < 1e15) return v.toInt().toString();
  return v.toString();
}

/// Whether the workbook uses the 1904 date system (`<workbookPr
/// date1904="1"/>` in xl/workbook.xml).
bool _isDate1904(Uint8List bytes) {
  try {
    final archive = ZipDecoder().decodeBytes(bytes);
    final wb = archive.findFile('xl/workbook.xml');
    if (wb == null) return false;
    final xml = utf8.decode(wb.content, allowMalformed: true);
    return RegExp(r'date1904\s*=\s*"(1|true)"').hasMatch(xml);
  } on Object {
    return false;
  }
}
