import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';
import 'package:personal_finance/features/import/domain/csv_parser.dart';
import 'package:personal_finance/features/import/domain/raw_sheet.dart';
import 'package:personal_finance/features/import/domain/text_decoding.dart';
import 'package:personal_finance/features/import/domain/xlsx_reader.dart';

/// Overrides for reading delimited text. Null members are detected.
@immutable
class CsvReadOptions {
  const CsvReadOptions({
    this.encoding = TextEncoding.auto,
    this.delimiter,
    this.quote,
  });

  factory CsvReadOptions.fromJson(Map<String, Object?> j) => CsvReadOptions(
    encoding: TextEncoding.values.firstWhere(
      (e) => e.name == j['encoding'],
      orElse: () => TextEncoding.auto,
    ),
    delimiter: j['delimiter'] as String?,
    quote: j['quote'] as String?,
  );

  final TextEncoding encoding;
  final String? delimiter;
  final String? quote;

  Map<String, Object?> toJson() => {
    'encoding': encoding.name,
    'delimiter': ?delimiter,
    'quote': ?quote,
  };

  @override
  bool operator ==(Object other) =>
      other is CsvReadOptions &&
      other.encoding == encoding &&
      other.delimiter == delimiter &&
      other.quote == quote;

  @override
  int get hashCode => Object.hash(encoding, delimiter, quote);
}

/// sha256 of [bytes] as lower-case hex.
String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();

/// File name without directory and extension.
String baseName(String fileName) {
  final name = fileName.split(RegExp(r'[/\\]')).last;
  final dot = name.lastIndexOf('.');
  return dot > 0 ? name.substring(0, dot) : name;
}

String _extension(String fileName) {
  final name = fileName.split(RegExp(r'[/\\]')).last.toLowerCase();
  final dot = name.lastIndexOf('.');
  return dot >= 0 ? name.substring(dot + 1) : '';
}

/// Reads any supported file: .xlsx/.xlsm/.xls via excel_plus, everything
/// else that is text as CSV/TSV. Throws [ImportReadException] for .ods,
/// Numbers, encrypted workbooks, PDFs and damaged files.
RawWorkbook readImportFile(
  Uint8List bytes, {
  required String fileName,
  CsvReadOptions csv = const CsvReadOptions(),
}) {
  if (bytes.isEmpty) throw const ImportReadException(ImportReadError.empty);
  final hash = sha256Hex(bytes);
  final ext = _extension(fileName);
  if (ext == 'numbers') {
    throw const ImportReadException(ImportReadError.numbers);
  }
  if (_startsWith(bytes, const [0x50, 0x4B, 0x03, 0x04])) {
    return _readZip(bytes, fileName, hash);
  }
  if (_startsWith(bytes, const [
    0xD0,
    0xCF,
    0x11,
    0xE0,
    0xA1,
    0xB1,
    0x1A,
    0xE1,
  ])) {
    try {
      return readExcelWorkbook(
        bytes,
        fileName: fileName,
        fileHash: hash,
        legacyXls: true,
      );
    } on ImportReadException {
      // An OLE container that is not a BIFF workbook is almost always an
      // encrypted (password-protected) OOXML file.
      if (ext == 'xlsx' ||
          ext == 'xlsm' ||
          _containsUtf16(bytes, 'EncryptionInfo')) {
        throw const ImportReadException(ImportReadError.encrypted);
      }
      rethrow;
    }
  }
  if (_startsWith(bytes, const [0x25, 0x50, 0x44, 0x46])) {
    throw const ImportReadException(ImportReadError.notASpreadsheet);
  }
  if (ext == 'ods' || ext == 'xlsx' || ext == 'xls' || ext == 'xlsm') {
    throw const ImportReadException(ImportReadError.corrupt);
  }
  return readCsvBytes(bytes, fileName: fileName, fileHash: hash, options: csv);
}

/// Reads delimited text bytes.
RawWorkbook readCsvBytes(
  Uint8List bytes, {
  required String fileName,
  String? fileHash,
  CsvReadOptions options = const CsvReadOptions(),
}) {
  final decoded = decodeText(bytes, encoding: options.encoding);
  if (decoded.text.contains('\u0000')) {
    throw const ImportReadException(ImportReadError.notASpreadsheet);
  }
  final ext = _extension(fileName);
  final r = readDelimitedText(
    decoded.text,
    sheetName: baseName(fileName),
    delimiter:
        options.delimiter ?? (ext == 'tsv' || ext == 'tab' ? '\t' : null),
    quote: options.quote,
  );
  if (r.sheet.rows.every((row) => row.isEmpty)) {
    throw const ImportReadException(ImportReadError.empty);
  }
  return RawWorkbook(
    fileName: fileName,
    format: SourceFormat.csv,
    sheets: [r.sheet],
    fileHash: fileHash ?? sha256Hex(bytes),
    dialect: CsvDialect(
      delimiter: r.delimiter,
      quote: r.quote,
      encoding: decoded.encoding,
      lineEnding: r.lineEnding,
      hadBom: decoded.hadBom,
    ),
  );
}

/// Reads rows pasted from a spreadsheet (tab-separated). Falls back to
/// delimiter detection when the text has no tabs.
RawWorkbook readClipboardText(String text, {String name = 'Clipboard'}) {
  final hasTabs = text.contains('\t');
  final r = readDelimitedText(
    text,
    sheetName: name,
    delimiter: hasTabs ? '\t' : null,
  );
  if (r.sheet.rows.every((row) => row.isEmpty)) {
    throw const ImportReadException(ImportReadError.empty);
  }
  return RawWorkbook(
    fileName: name,
    format: SourceFormat.clipboard,
    sheets: [r.sheet],
    fileHash: sha256Hex(utf8.encode(text)),
    dialect: CsvDialect(
      delimiter: r.delimiter,
      quote: r.quote,
      lineEnding: r.lineEnding,
    ),
  );
}

RawWorkbook _readZip(Uint8List bytes, String fileName, String hash) {
  Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } on Object catch (e) {
    throw ImportReadException(ImportReadError.corrupt, detail: '$e');
  }
  final mimetype = archive.findFile('mimetype');
  if (mimetype != null) {
    final m = utf8.decode(mimetype.content, allowMalformed: true);
    if (m.contains('opendocument.spreadsheet')) {
      throw const ImportReadException(ImportReadError.ods);
    }
    throw const ImportReadException(ImportReadError.notASpreadsheet);
  }
  if (archive.findFile('Index/Document.iwa') != null) {
    throw const ImportReadException(ImportReadError.numbers);
  }
  if (archive.findFile('xl/workbook.xml') == null) {
    throw const ImportReadException(ImportReadError.notASpreadsheet);
  }
  return readExcelWorkbook(
    bytes,
    fileName: fileName,
    fileHash: hash,
    legacyXls: false,
  );
}

bool _startsWith(Uint8List bytes, List<int> magic) {
  if (bytes.length < magic.length) return false;
  for (var i = 0; i < magic.length; i++) {
    if (bytes[i] != magic[i]) return false;
  }
  return true;
}

bool _containsUtf16(Uint8List bytes, String s) {
  final pattern = <int>[
    for (final c in s.codeUnits) ...[c, 0],
  ];
  final limit = bytes.length - pattern.length;
  outer:
  for (var i = 0; i <= limit; i++) {
    for (var j = 0; j < pattern.length; j++) {
      if (bytes[i + j] != pattern[j]) continue outer;
    }
    return true;
  }
  return false;
}
