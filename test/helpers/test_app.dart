import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:personal_finance/app/theme/app_theme.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/sync/hlc.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

/// Opens a fresh in-memory database.
AppDatabase newTestDb() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(NativeDatabase.memory());
}

/// A deterministic clock for tests.
HlcClock testClock({String node = 'test-device', int start = 1700000000000}) {
  var t = start;
  return HlcClock(node, now: () => t++);
}

/// A [ProviderContainer] wired to [db].
ProviderContainer testContainer(
  AppDatabase db, {
  List<Override> overrides = const [],
}) {
  final c = ProviderContainer(
    overrides: [
      ...dbOverrides(db, 'test-device', clock: testClock()),
      ...overrides,
    ],
  );
  return c;
}

/// Wraps [child] in MaterialApp with theme and localizations for widget tests.
Widget testApp(
  Widget child, {
  required AppDatabase db,
  List<Override> overrides = const [],
  Locale locale = const Locale('en'),
  ThemeMode themeMode = ThemeMode.light,
}) {
  return ProviderScope(
    overrides: [
      ...dbOverrides(db, 'test-device', clock: testClock()),
      ...overrides,
    ],
    child: MaterialApp(
      theme: const AppTheme().light(),
      darkTheme: const AppTheme().dark(),
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    ),
  );
}
