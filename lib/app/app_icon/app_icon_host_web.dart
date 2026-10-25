import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui';

import 'package:personal_finance/app/app_icon/app_icon_image.dart';

@JS('document.querySelector')
external _Link? _querySelector(String selectors);

extension type _Link._(JSObject _) implements JSObject {
  external String get href;
  external set href(String value);
}

/// Points the page's favicon at the icon in the current accent.
Future<void> applyHostIcon({
  required Color background,
  required Color foreground,
}) async {
  final link = _querySelector('link[rel="icon"]');
  if (link == null) return;
  final png = await renderAppIconPng(
    64,
    background: background,
    foreground: foreground,
  );
  link.href = 'data:image/png;base64,${base64Encode(png)}';
}
