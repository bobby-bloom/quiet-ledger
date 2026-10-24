import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/app/theme/app_theme.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/settings/settings_routes.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

import '../../helpers/test_app.dart';
import '../security/security_test_utils.dart';

/// Lets DB futures and stream queries complete inside a widget test.
Future<void> settle(WidgetTester tester, [int rounds = 8]) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> tearDownApp(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 10));
  await tester.runAsync(db.close);
}

void setWindow(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Reads the settings straight from the DB (what a restart would see).
Future<SettingsSnapshot> storedSettings(
  WidgetTester tester,
  AppDatabase db,
) async => (await tester.runAsync(() => loadSettings(db)))!;

/// The settings routes in a router, for navigation tests.
Widget settingsRouterApp(
  AppDatabase db, {
  String initial = '/more/settings',
  Locale locale = const Locale('en'),
  List<Override> overrides = const [],
}) {
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      ...settingsRoutes,
      GoRoute(
        path: '/plan/recurring',
        builder: (_, _) => const Scaffold(body: Text('recurring list')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      ...dbOverrides(db, 'test-device', clock: testClock()),
      ...securityOverrides(),
      ...overrides,
    ],
    child: MaterialApp.router(
      routerConfig: router,
      theme: const AppTheme().light(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    ),
  );
}
