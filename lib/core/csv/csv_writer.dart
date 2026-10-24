import 'dart:convert';
import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:enough_convert/enough_convert.dart';
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';

// Reusable CSV writer (PLAN.md §2.6). Used by the transaction export, the
// backup bundle and per-report CSV exports.
//
// Typical use from a feature:
//
// ```dart
// final options = CsvOptions.fromSettings(
//   ref.read(settingsProvider),
//   locale: ref.read(formatLocaleProvider),
// );
// final bytes = CsvWriter(options).encodeTable(
//   ['Category', 'Amount'],
//   [for (final r in rows) [r.name, CsvAmount(r.totalMinor)]],
// );
// await saveOrShareBytes(bytes: bytes, fileName: 'report.csv');
// ```
//
// Or with named, selectable columns ([CsvColumn]): `writer.encode(columns,
// rows)` honours [CsvOptions.columns] (selection and order) and
// [CsvOptions.header].
//
// Cell values are formatted by type: `null` → empty, [String] as is, [int],
// [double]/[Decimal] with the decimal separator, [CsvAmount] (minor units)
// as a fixed-point number, [DateTime] with [CsvOptions.dateFormat],
// [CsvDateTime] with date format + `HH:mm:ss`, [bool] as `true`/`false`,
// [Iterable] joined with `, `. Anything else uses `toString()`.

/// An amount in minor units written as a plain fixed-point number
/// (`-1234.50` / `-1234,50`): no grouping, no currency symbol, ASCII minus.
@immutable
class CsvAmount {
  const CsvAmount(this.minor, {this.scale = 2});
  final int minor;

  /// Number of decimals (2 for EUR).
  final int scale;

  String format(String decimalSeparator) {
    final negative = minor < 0;
    final digits = minor.abs().toString().padLeft(scale + 1, '0');
    final intPart = digits.substring(0, digits.length - scale);
    final frac = digits.substring(digits.length - scale);
    final body = scale == 0 ? intPart : '$intPart$decimalSeparator$frac';
    return negative ? '-$body' : body;
  }

  @override
  bool operator ==(Object other) =>
      other is CsvAmount && other.minor == minor && other.scale == scale;

  @override
  int get hashCode => Object.hash(minor, scale);

  @override
  String toString() => format('.');
}

/// A timestamp cell: the date part uses [CsvOptions.dateFormat], followed by
/// ` HH:mm:ss`.
@immutable
class CsvDateTime {
  const CsvDateTime(this.value);
  final DateTime value;
}

/// One named column for [CsvWriter.encode]. [key] is stable (stored in
/// presets), [header] is the (localized) header text.
@immutable
class CsvColumn<R> {
  const CsvColumn(this.key, this.header, this.value);
  final String key;
  final String header;
  final Object? Function(R row) value;
}

/// All options of a CSV file. Immutable; persisted in presets via
/// `toJson`/`CsvOptions.fromJson`.
@immutable
class CsvOptions {
  const CsvOptions({
    this.delimiter = CsvDelimiter.semicolon,
    this.encoding = CsvEncoding.utf8Bom,
    this.dateFormat = 'yyyy-MM-dd',
    this.decimalSeparator = DecimalSeparator.locale,
    this.locale = 'en_US',
    this.header = true,
    this.columns,
    this.lineEnding = '\r\n',
    this.quoteAll = false,
    this.distinguishNull = false,
  });

  /// Options from Settings › Import / export. [locale] (BCP-47 with `_`)
  /// resolves [DecimalSeparator.locale]; pass `ref.read(formatLocaleProvider)`.
  factory CsvOptions.fromSettings(
    SettingsSnapshot settings, {
    String locale = 'en_US',
  }) => CsvOptions(
    delimiter: settings.get(ImportExportSettings.csvDelimiter),
    encoding: settings.get(ImportExportSettings.csvEncoding),
    dateFormat: settings.get(ImportExportSettings.csvDateFormat),
    decimalSeparator: settings.get(ImportExportSettings.csvDecimalSeparator),
    locale: locale,
  );

  factory CsvOptions.fromJson(Map<String, Object?> j) {
    const d = CsvOptions();
    T byName<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.where((e) => e.name == name).firstOrNull ?? fallback;
    final cols = j['columns'];
    return CsvOptions(
      delimiter: byName(CsvDelimiter.values, j['delimiter'], d.delimiter),
      encoding: byName(CsvEncoding.values, j['encoding'], d.encoding),
      dateFormat: j['dateFormat'] as String? ?? d.dateFormat,
      decimalSeparator: byName(
        DecimalSeparator.values,
        j['decimalSeparator'],
        d.decimalSeparator,
      ),
      locale: j['locale'] as String? ?? d.locale,
      header: j['header'] as bool? ?? d.header,
      columns: cols is List ? cols.whereType<String>().toList() : null,
    );
  }

  /// Plain RFC 4180 CSV used by the backup bundle: comma, UTF-8 without BOM,
  /// CRLF, `null` written as an unquoted empty field and empty strings as
  /// `""` so both survive a round trip.
  static const bundle = CsvOptions(
    delimiter: CsvDelimiter.comma,
    encoding: CsvEncoding.utf8,
    decimalSeparator: DecimalSeparator.point,
    distinguishNull: true,
  );

  final CsvDelimiter delimiter;
  final CsvEncoding encoding;

  /// intl `DateFormat` pattern for date cells.
  final String dateFormat;
  final DecimalSeparator decimalSeparator;

  /// Locale for [DecimalSeparator.locale] (e.g. `de_DE`).
  final String locale;

  /// Write a header row.
  final bool header;

  /// Selected column keys in output order; `null` = all columns in their
  /// default order. Unknown keys are ignored.
  final List<String>? columns;
  final String lineEnding;

  /// Quote every field, not only those that need it.
  final bool quoteAll;

  /// Write empty strings as `""` so that an unquoted empty field means null.
  final bool distinguishNull;

  /// The field delimiter character.
  String get delimiterChar => switch (delimiter) {
    CsvDelimiter.comma => ',',
    CsvDelimiter.semicolon => ';',
    CsvDelimiter.tab => '\t',
    CsvDelimiter.pipe => '|',
  };

  /// The decimal separator character, resolved from [locale] if needed.
  String get decimalChar => switch (decimalSeparator) {
    DecimalSeparator.comma => ',',
    DecimalSeparator.point => '.',
    DecimalSeparator.locale => localeDecimalSeparator(locale),
  };

  /// File extension matching the delimiter (`tsv` for tab).
  String get fileExtension => delimiter == CsvDelimiter.tab ? 'tsv' : 'csv';

  String get mimeType =>
      delimiter == CsvDelimiter.tab ? 'text/tab-separated-values' : 'text/csv';

  Map<String, Object?> toJson() => {
    'delimiter': delimiter.name,
    'encoding': encoding.name,
    'dateFormat': dateFormat,
    'decimalSeparator': decimalSeparator.name,
    'header': header,
    if (columns != null) 'columns': columns,
  };

  CsvOptions copyWith({
    CsvDelimiter? delimiter,
    CsvEncoding? encoding,
    String? dateFormat,
    DecimalSeparator? decimalSeparator,
    String? locale,
    bool? header,
    List<String>? columns,
    bool clearColumns = false,
    String? lineEnding,
    bool? quoteAll,
    bool? distinguishNull,
  }) => CsvOptions(
    delimiter: delimiter ?? this.delimiter,
    encoding: encoding ?? this.encoding,
    dateFormat: dateFormat ?? this.dateFormat,
    decimalSeparator: decimalSeparator ?? this.decimalSeparator,
    locale: locale ?? this.locale,
    header: header ?? this.header,
    columns: clearColumns ? null : (columns ?? this.columns),
    lineEnding: lineEnding ?? this.lineEnding,
    quoteAll: quoteAll ?? this.quoteAll,
    distinguishNull: distinguishNull ?? this.distinguishNull,
  );

  @override
  bool operator ==(Object other) =>
      other is CsvOptions &&
      other.delimiter == delimiter &&
      other.encoding == encoding &&
      other.dateFormat == dateFormat &&
      other.decimalSeparator == decimalSeparator &&
      other.locale == locale &&
      other.header == header &&
      _listEq(other.columns, columns) &&
      other.lineEnding == lineEnding &&
      other.quoteAll == quoteAll &&
      other.distinguishNull == distinguishNull;

  @override
  int get hashCode => Object.hash(
    delimiter,
    encoding,
    dateFormat,
    decimalSeparator,
    locale,
    header,
    columns == null ? null : Object.hashAll(columns!),
    lineEnding,
    quoteAll,
    distinguishNull,
  );

  static bool _listEq(List<String>? a, List<String>? b) {
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Decimal separator of [locale] (`,` for de_DE, `.` for en_US).
String localeDecimalSeparator(String locale) {
  try {
    return NumberFormat.decimalPattern(locale).symbols.DECIMAL_SEP;
  } on Object {
    final lang = locale.split(RegExp('[_-]')).first.toLowerCase();
    const commaLanguages = {
      'de',
      'fr',
      'es',
      'it',
      'nl',
      'pt',
      'pl',
      'cs',
      'da',
      'fi',
      'nb',
      'sv',
      'tr',
      'ru',
    };
    return commaLanguages.contains(lang) ? ',' : '.';
  }
}

/// Encodes rows as CSV text and bytes according to [options].
class CsvWriter {
  CsvWriter(this.options)
    : _delimiter = options.delimiterChar,
      _decimal = options.decimalChar,
      _date = _dateFormat(options.dateFormat, options.locale);

  final CsvOptions options;
  final String _delimiter;
  final String _decimal;
  final DateFormat _date;

  static DateFormat _dateFormat(String pattern, String locale) {
    try {
      return DateFormat(pattern, locale);
    } on Object {
      // Locale data not initialised (e.g. in isolates): numeric patterns
      // format the same in every locale.
      return DateFormat(pattern, 'en_US');
    }
  }

  /// Text of one cell (unquoted).
  String formatValue(Object? value) => switch (value) {
    null => '',
    final String s => s,
    final CsvAmount a => a.format(_decimal),
    final int i => i.toString(),
    final double d => _number(d.toString()),
    final Decimal d => _number(d.toString()),
    final DateTime d => _date.format(d),
    final CsvDateTime d =>
      '${_date.format(d.value)} ${DateFormat('HH:mm:ss').format(d.value)}',
    final bool b => b.toString(),
    final Iterable<Object?> list => list.map(formatValue).join(', '),
    _ => value.toString(),
  };

  String _number(String s) => _decimal == '.' ? s : s.replaceAll('.', _decimal);

  /// One field, quoted when needed (delimiter, quote, line break, leading or
  /// trailing whitespace) with embedded quotes doubled.
  String field(Object? value) {
    final text = formatValue(value);
    final mustQuote =
        options.quoteAll ||
        (options.distinguishNull && value != null && text.isEmpty) ||
        text.contains(_delimiter) ||
        text.contains('"') ||
        text.contains('\n') ||
        text.contains('\r') ||
        (text.isNotEmpty && (text.trim().length != text.length));
    if (!mustQuote) return text;
    return '"${text.replaceAll('"', '""')}"';
  }

  /// One line without the line ending.
  String line(Iterable<Object?> cells) => cells.map(field).join(_delimiter);

  /// CSV text of [rows] (each row a list of cell values), every line
  /// terminated by [CsvOptions.lineEnding].
  String encodeRowsToString(Iterable<Iterable<Object?>> rows) {
    final b = StringBuffer();
    for (final r in rows) {
      b
        ..write(line(r))
        ..write(options.lineEnding);
    }
    return b.toString();
  }

  /// Encodes a table given as a header and positional rows. The header is
  /// skipped when [CsvOptions.header] is false. [CsvOptions.columns] is
  /// ignored here (use [encode] for selectable columns).
  Uint8List encodeTable(List<String> header, Iterable<Iterable<Object?>> rows) {
    final text = encodeRowsToString([if (options.header) header, ...rows]);
    return encodeText(text, options.encoding);
  }

  /// Encodes [rows] with named [columns], honouring the column selection and
  /// order in [CsvOptions.columns] and the header option.
  Uint8List encode<R>(List<CsvColumn<R>> columns, Iterable<R> rows) {
    final cols = selectColumns(columns, options.columns);
    return encodeTable([
      for (final c in cols) c.header,
    ], rows.map((r) => [for (final c in cols) c.value(r)]));
  }

  /// Applies a selection/order of column keys. `null` keeps all columns.
  static List<CsvColumn<R>> selectColumns<R>(
    List<CsvColumn<R>> columns,
    List<String>? keys,
  ) {
    if (keys == null) return columns;
    final byKey = {for (final c in columns) c.key: c};
    return [
      for (final k in keys)
        if (byKey[k] != null) byKey[k]!,
    ];
  }

  /// Encodes [text] with [encoding]. Characters that Windows-1252 /
  /// ISO-8859-15 cannot represent become `?`.
  static Uint8List encodeText(String text, CsvEncoding encoding) =>
      switch (encoding) {
        CsvEncoding.utf8 => Uint8List.fromList(utf8.encode(text)),
        CsvEncoding.utf8Bom => Uint8List.fromList([
          0xEF,
          0xBB,
          0xBF,
          ...utf8.encode(text),
        ]),
        CsvEncoding.windows1252 => Uint8List.fromList(
          const Windows1252Codec(allowInvalid: true).encode(text),
        ),
        CsvEncoding.iso8859_15 => Uint8List.fromList(
          const Latin15Codec(allowInvalid: true).encode(text),
        ),
      };
}
