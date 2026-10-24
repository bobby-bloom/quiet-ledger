import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/app.dart';
import 'package:personal_finance/app/boot_error.dart';
import 'package:personal_finance/app/bootstrap.dart';
import 'package:personal_finance/app/startup_tasks.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initWindow();
  await _start();
}

Future<void> _start() async {
  try {
    final boot = await bootstrap();
    final container = ProviderContainer(overrides: boot.overrides);
    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const PersonalFinanceApp(),
      ),
    );
    // Post due recurring entries, auto-export, purge tombstones...
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => startupTasks.runAll(container),
    );
  } on Object catch (e, st) {
    debugPrint('Bootstrap failed: $e\n$st');
    runApp(
      BootErrorApp(
        error: e,
        onRetry: _start,
        onStartFresh: startWithEmptyDatabase,
      ),
    );
  }
}

bool get _isDesktop =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows);

Future<void> _initWindow() async {
  if (!_isDesktop) return;
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      size: Size(1280, 860),
      minimumSize: Size(360, 600),
      title: 'Quiet Ledger',
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );
}
