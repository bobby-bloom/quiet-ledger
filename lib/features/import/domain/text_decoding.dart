import 'dart:convert';
import 'dart:typed_data';

import 'package:enough_convert/latin.dart';
import 'package:enough_convert/windows.dart';
import 'package:personal_finance/features/import/domain/raw_sheet.dart';

/// Result of decoding text bytes.
typedef DecodedText = ({String text, TextEncoding encoding, bool hadBom});

/// Decodes [bytes] with [encoding], or detects the encoding when it is
/// [TextEncoding.auto]:
///
/// * a BOM decides (UTF-8, UTF-16 LE/BE);
/// * UTF-16 without BOM is recognised by many zero bytes;
/// * valid UTF-8 is UTF-8;
/// * otherwise Windows-1252 when bytes 0x80–0x9F occur (they are control
///   characters in ISO-8859-x), ISO-8859-15 when 0xA4 occurs (the euro
///   sign there), else Windows-1252 (a superset of ISO-8859-1's printable
///   range).
DecodedText decodeText(
  Uint8List bytes, {
  TextEncoding encoding = TextEncoding.auto,
}) {
  var hadBom = false;
  var start = 0;
  var enc = encoding;
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    hadBom = true;
    start = 3;
    if (enc == TextEncoding.auto) enc = TextEncoding.utf8;
  } else if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    hadBom = true;
    start = 2;
    if (enc == TextEncoding.auto) enc = TextEncoding.utf16le;
  } else if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
    hadBom = true;
    start = 2;
    if (enc == TextEncoding.auto) enc = TextEncoding.utf16be;
  }
  final body = Uint8List.sublistView(bytes, start);
  if (enc == TextEncoding.auto) enc = detectEncoding(body);
  return (text: _decode(body, enc), encoding: enc, hadBom: hadBom);
}

/// Guesses the encoding of BOM-less [bytes].
TextEncoding detectEncoding(Uint8List bytes) {
  final n = bytes.length < 4096 ? bytes.length : 4096;
  if (n >= 4) {
    var evenZeros = 0;
    var oddZeros = 0;
    for (var i = 0; i < n; i++) {
      if (bytes[i] == 0) i.isEven ? evenZeros++ : oddZeros++;
    }
    if (oddZeros > n / 4 && evenZeros < n / 20) return TextEncoding.utf16le;
    if (evenZeros > n / 4 && oddZeros < n / 20) return TextEncoding.utf16be;
  }
  var ascii = true;
  for (final b in bytes) {
    if (b >= 0x80) {
      ascii = false;
      break;
    }
  }
  if (ascii) return TextEncoding.utf8;
  try {
    const Utf8Decoder().convert(bytes);
    return TextEncoding.utf8;
  } on FormatException {
    // Not UTF-8: fall through to the single-byte encodings.
  }
  var c1 = false;
  var euro = false;
  for (final b in bytes) {
    if (b >= 0x80 && b <= 0x9F) c1 = true;
    if (b == 0xA4) euro = true;
  }
  if (c1) return TextEncoding.windows1252;
  if (euro) return TextEncoding.latin9;
  return TextEncoding.windows1252;
}

String _decode(Uint8List bytes, TextEncoding enc) {
  switch (enc) {
    case TextEncoding.auto:
    case TextEncoding.utf8:
      return const Utf8Decoder(allowMalformed: true).convert(bytes);
    case TextEncoding.utf16le:
    case TextEncoding.utf16be:
      final le = enc == TextEncoding.utf16le;
      final units = <int>[];
      for (var i = 0; i + 1 < bytes.length; i += 2) {
        units.add(
          le ? bytes[i] | (bytes[i + 1] << 8) : (bytes[i] << 8) | bytes[i + 1],
        );
      }
      return String.fromCharCodes(units);
    case TextEncoding.windows1252:
      return const Windows1252Codec(allowInvalid: true).decode(bytes);
    case TextEncoding.latin1:
      return const Latin1Decoder(allowInvalid: true).convert(bytes);
    case TextEncoding.latin9:
      return const Latin15Codec(allowInvalid: true).decode(bytes);
  }
}
