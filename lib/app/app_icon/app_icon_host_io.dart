import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:personal_finance/app/app_icon/app_icon_image.dart';
import 'package:window_manager/window_manager.dart';

const _dockChannel = MethodChannel('personal_finance/app_icon');

/// Linux and Windows: the window and taskbar icon, from a file in the
/// temporary folder (window_manager loads icons from files; an absolute
/// path replaces its asset folder). macOS: the Dock icon while the app
/// runs. The icon files themselves stay in the bundle's colour.
Future<void> applyHostIcon({
  required Color background,
  required Color foreground,
}) async {
  switch (defaultTargetPlatform) {
    case TargetPlatform.macOS:
      final png = await renderAppIconPng(
        1024,
        background: background,
        foreground: foreground,
        shape: AppIconShape.macos,
      );
      await _dockChannel.invokeMethod<void>('setDockIcon', {'png': png});
    case TargetPlatform.windows:
      final ico = await renderAppIconIco(
        background: background,
        foreground: foreground,
        sizes: const [16, 32, 48],
      );
      await windowManager.setIcon(await _write('window-icon.ico', ico));
    case TargetPlatform.linux:
      final png = await renderAppIconPng(
        256,
        background: background,
        foreground: foreground,
      );
      await windowManager.setIcon(await _write('window-icon.png', png));
    case TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.fuchsia:
      return;
  }
}

Future<String> _write(String name, Uint8List bytes) async {
  final dir = await getTemporaryDirectory();
  final file = File(p.join(dir.path, 'quiet-ledger-$name'));
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
