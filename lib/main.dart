import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/app.dart';
import 'package:personal_finance/app/bootstrap.dart';
import 'package:personal_finance/app/startup_tasks.dart';
import 'package:personal_finance/app/theme/app_theme.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initWindow();
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
    runApp(_BootErrorApp(error: e));
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

class _BootErrorApp extends StatelessWidget {
  const _BootErrorApp({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: const AppTheme().light(),
      darkTheme: const AppTheme().dark(),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'The database could not be opened.',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                SelectableText('$error', textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
