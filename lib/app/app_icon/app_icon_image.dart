import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:personal_finance/app/ui/app_mark.dart';

/// How the mark is placed on a square icon canvas.
enum AppIconShape {
  /// Rounded square filling the canvas (desktop windows, web, Windows).
  rounded,

  /// Opaque square filling the canvas; the platform applies its own mask
  /// (iOS, Android legacy launcher icons, maskable web icons).
  square,

  /// macOS: rounded square on the 824/1024 grid, transparent margin.
  macos,

  /// The mark alone on transparent (Android adaptive foreground,
  /// monochrome and notification icons).
  markOnly,
}

/// Renders the app icon at [size] px: the mark in [foreground] on
/// [background] (ignored for [AppIconShape.markOnly], where [markScale]
/// enlarges the mark around the centre, e.g. for notification icons).
Future<ui.Image> renderAppIcon(
  int size, {
  required Color background,
  required Color foreground,
  AppIconShape shape = AppIconShape.rounded,
  double markScale = 1,
}) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final side = size.toDouble();
  switch (shape) {
    case AppIconShape.rounded:
      AppMarkPainter(
        color: foreground,
        background: background,
      ).paint(canvas, Size.square(side));
    case AppIconShape.square:
      AppMarkPainter(
        color: foreground,
        background: background,
        radiusFraction: 0,
      ).paint(canvas, Size.square(side));
    case AppIconShape.macos:
      // Big Sur grid: 824 px body centred on 1024, radius ~22.5 %.
      final inset = side * 100 / 1024;
      canvas.translate(inset, inset);
      AppMarkPainter(
        color: foreground,
        background: background,
        radiusFraction: 0.225,
      ).paint(canvas, Size.square(side - 2 * inset));
    case AppIconShape.markOnly:
      canvas
        ..translate(side / 2, side / 2)
        ..scale(markScale)
        ..translate(-side / 2, -side / 2);
      AppMarkPainter(color: foreground).paint(canvas, Size.square(side));
  }
  return recorder.endRecording().toImage(size, size);
}

/// [renderAppIcon] as PNG bytes.
Future<Uint8List> renderAppIconPng(
  int size, {
  required Color background,
  required Color foreground,
  AppIconShape shape = AppIconShape.rounded,
  double markScale = 1,
}) async {
  final image = await renderAppIcon(
    size,
    background: background,
    foreground: foreground,
    shape: shape,
    markScale: markScale,
  );
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

/// A Windows `.ico` with a rounded-square icon per size in [sizes]: 32-bit
/// bitmaps up to 64 px (what `LoadImage` reads everywhere), PNG above.
Future<Uint8List> renderAppIconIco({
  required Color background,
  required Color foreground,
  List<int> sizes = const [16, 24, 32, 48, 64, 256],
}) async {
  final entries = <(int, Uint8List)>[];
  for (final size in sizes) {
    final image = await renderAppIcon(
      size,
      background: background,
      foreground: foreground,
    );
    try {
      if (size > 64) {
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        entries.add((size, png!.buffer.asUint8List()));
      } else {
        final rgba = await image.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        );
        entries.add((size, icoBitmap(size, rgba!.buffer.asUint8List())));
      }
    } finally {
      image.dispose();
    }
  }
  return encodeIco(entries);
}

/// Wraps square images (`(size, data)`, data being PNG bytes or an
/// [icoBitmap]) in an ICO container.
Uint8List encodeIco(List<(int, Uint8List)> images) {
  const headerSize = 6;
  const entrySize = 16;
  final total =
      headerSize +
      entrySize * images.length +
      images.fold<int>(0, (sum, e) => sum + e.$2.length);
  final out = ByteData(total);
  out
    ..setUint16(0, 0, Endian.little) // reserved
    ..setUint16(2, 1, Endian.little) // type: icon
    ..setUint16(4, images.length, Endian.little);
  var offset = headerSize + entrySize * images.length;
  for (final (i, (size, data)) in images.indexed) {
    final e = headerSize + entrySize * i;
    out
      ..setUint8(e, size >= 256 ? 0 : size) // 0 means 256
      ..setUint8(e + 1, size >= 256 ? 0 : size)
      ..setUint8(e + 2, 0) // palette colours
      ..setUint8(e + 3, 0) // reserved
      ..setUint16(e + 4, 1, Endian.little) // colour planes
      ..setUint16(e + 6, 32, Endian.little) // bits per pixel
      ..setUint32(e + 8, data.length, Endian.little)
      ..setUint32(e + 12, offset, Endian.little);
    offset += data.length;
  }
  final bytes = out.buffer.asUint8List();
  offset = headerSize + entrySize * images.length;
  for (final (_, data) in images) {
    bytes.setRange(offset, offset + data.length, data);
    offset += data.length;
  }
  return bytes;
}

/// An ICO image entry as a 32-bit BGRA bitmap from straight-alpha RGBA
/// pixels: BITMAPINFOHEADER (height doubled for the mask), rows bottom-up,
/// then an all-clear AND mask (the alpha channel does the masking).
Uint8List icoBitmap(int size, Uint8List rgba) {
  assert(rgba.length == size * size * 4, 'expects $size×$size RGBA');
  const infoSize = 40;
  final maskRow = ((size + 31) ~/ 32) * 4;
  final out = ByteData(infoSize + size * size * 4 + maskRow * size);
  out
    ..setUint32(0, infoSize, Endian.little)
    ..setInt32(4, size, Endian.little)
    ..setInt32(8, size * 2, Endian.little)
    ..setUint16(12, 1, Endian.little) // planes
    ..setUint16(14, 32, Endian.little) // bits per pixel
    ..setUint32(16, 0, Endian.little) // BI_RGB
    ..setUint32(20, size * size * 4, Endian.little);
  var o = infoSize;
  for (var y = size - 1; y >= 0; y--) {
    for (var x = 0; x < size; x++) {
      final p = (y * size + x) * 4;
      out
        ..setUint8(o, rgba[p + 2])
        ..setUint8(o + 1, rgba[p + 1])
        ..setUint8(o + 2, rgba[p])
        ..setUint8(o + 3, rgba[p + 3]);
      o += 4;
    }
  }
  return out.buffer.asUint8List();
}
