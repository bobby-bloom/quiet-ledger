// Renders key screens with demo data to PNG files for visual review.
//
//   flutter test tool/screenshots/screenshots_test.dart
//
// Output: build/screenshots/*.png. Not part of the regular test suite.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/app/app.dart';
import 'package:personal_finance/app/router.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/core/ledger/ledger_repository.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/categories/domain/default_categories.dart';
import 'package:personal_finance/features/forecast/presentation/forecast_providers.dart';
import 'package:personal_finance/features/security/data/secret_store.dart';

import '../../test/helpers/test_app.dart';

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(
        Future.value(ByteData.sublistView(File(f).readAsBytesSync())),
      );
    }
    await loader.load();
  }

  final flutterRoot = File(Platform.resolvedExecutable)
      .parent
      .parent
      .parent
      .parent
      .parent
      .parent
      .path;
  await load('Manrope', ['assets/fonts/Manrope.ttf']);
  await load('IBMPlexMono', [
    'assets/fonts/IBMPlexMono-Regular.ttf',
    'assets/fonts/IBMPlexMono-Medium.ttf',
  ]);
  final icons = [
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    '${Platform.environment['FLUTTER_ROOT'] ?? ''}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ].firstWhere((p) => File(p).existsSync());
  await load('MaterialIcons', [icons]);
}

/// Seeds a realistic German household ledger for the last 4 months.
Future<void> _seed(AppDatabase db, {required bool dark}) async {
  final w = SyncWriter(db, testClock(), 'demo');
  Future<void> setting(String key, Object value) => w.insert(
    db.settings,
    SettingsCompanion(
      key: Value(key),
      value: Value(jsonEncode(value)),
      scope: const Value('global'),
    ),
    id: 'global|$key',
  );
  await setting(GeneralSettings.onboardingDone.key, true);
  await setting(GeneralSettings.language.key, 'en');
  await setting(AppearanceSettings.themeMode.key, dark ? 'dark' : 'light');
  final ledger = LedgerRepository(db, w);
  await seedDefaultCategories(w, db, DefaultCategorySet.en);
  final cats = {
    for (final c in await db.select(db.categories).get()) c.name: c.id,
  };
  String cat(String name) => cats[name] ?? cats.values.first;

  Future<String> account(
    String name,
    AccountType t,
    int opening,
    String icon, {
    int? threshold,
  }) => w.insert(
    db.accounts,
    AccountsCompanion(
      name: Value(name),
      type: Value(t),
      openingBalanceMinor: Value(opening),
      openingDate: Value(DateTime(2026, 6)),
      icon: Value(icon),
      lowBalanceThresholdMinor: Value(threshold),
    ),
  );
  final checking = await account(
    'Everyday checking',
    AccountType.checking,
    182000,
    'bank',
    threshold: 50000,
  );
  final bills = await account(
    'Bills account',
    AccountType.checking,
    120000,
    'bank',
  );
  final savings = await account(
    'Holiday savings',
    AccountType.savings,
    640000,
    'savings',
  );
  final card = await account(
    'Visa card',
    AccountType.creditCard,
    -21000,
    'card',
  );
  final wallet = await account('Wallet', AccountType.cash, 8500, 'cash');
  await setting(EntrySettings.defaultAccountId.key, checking);

  final now = DateTime.now();
  final start = DateTime(now.year, now.month - 3);
  final groceries = cat('Groceries');
  final eating = cats['Restaurants & cafés'] ?? cats['Eating out'] ?? groceries;
  final shopping = cats['Shopping'] ?? groceries;
  final transport = cats['Public transport'] ?? cats['Transport'] ?? groceries;
  final salary = cats['Salary'] ?? groceries;
  final rent = cats['Rent'] ?? groceries;
  var seed = 7;
  int rnd(int max) => (seed = (seed * 1103515245 + 12345) & 0x7fffffff) % max;
  for (
    var d = start;
    !d.isAfter(now);
    d = DateTime(d.year, d.month, d.day + 1)
  ) {
    if (d.day == 1) {
      await ledger.create(
        TxnDraft(
          accountId: checking,
          amountMinor: 342000,
          date: d,
          type: TxnType.income,
          payee: 'Acme GmbH',
          categoryId: salary,
        ),
      );
      await ledger.create(
        TxnDraft(
          accountId: bills,
          amountMinor: -98000,
          date: d,
          payee: 'Hausverwaltung Kraus',
          categoryId: rent,
        ),
      );
      await ledger.create(
        TxnDraft(
          accountId: checking,
          amountMinor: -15000,
          date: d,
          type: TxnType.transfer,
          transferAccountId: savings,
          payee: 'To holiday savings',
        ),
      );
    }
    if (rnd(3) == 0) {
      await ledger.create(
        TxnDraft(
          accountId: checking,
          amountMinor: -(1500 + rnd(6000)),
          date: d,
          payee: ['Corner Grocer', 'Rewe', 'Edeka', 'Aldi Süd'][rnd(4)],
          categoryId: groceries,
        ),
      );
    }
    if (rnd(5) == 0) {
      await ledger.create(
        TxnDraft(
          accountId: wallet,
          amountMinor: -(400 + rnd(2600)),
          date: d,
          payee: ['Daily Bakery', 'Café Lotte', 'Pizzeria Roma'][rnd(3)],
          categoryId: eating,
        ),
      );
    }
    if (rnd(9) == 0) {
      await ledger.create(
        TxnDraft(
          accountId: card,
          amountMinor: -(1999 + rnd(9000)),
          date: d,
          payee: ['Online Store', 'Bookshop', 'Sport Scheck'][rnd(3)],
          categoryId: shopping,
          status: d.isAfter(now.subtract(const Duration(days: 3)))
              ? TxnStatus.pending
              : TxnStatus.cleared,
        ),
      );
    }
    if (d.weekday == DateTime.monday) {
      await ledger.create(
        TxnDraft(
          accountId: checking,
          amountMinor: -2490,
          date: d,
          payee: 'MVG',
          categoryId: transport,
        ),
      );
    }
  }
  Future<void> rule(
    String name,
    String rrule,
    String account,
    int amount,
    String category,
    PostingMode mode,
  ) => w.insert(
    db.recurringRules,
    RecurringRulesCompanion(
      name: Value(name),
      rrule: Value(rrule),
      startDate: Value(DateTime(now.year, now.month - 3)),
      template: Value(
        jsonEncode(
          TxnDraft(
            accountId: account,
            amountMinor: amount,
            date: now,
            payee: name,
            categoryId: category,
          ).toJson(),
        ),
      ),
      postingMode: Value(mode),
      weekendShift: const Value('previous'),
      lastPostedDate: Value(DateTime(now.year, now.month, now.day - 1)),
    ),
  );
  await rule(
    'Rent',
    'FREQ=MONTHLY;BYMONTHDAY=1',
    bills,
    -98000,
    rent,
    PostingMode.remindConfirm,
  );
  await rule(
    'Mobile plan',
    'FREQ=MONTHLY;BYMONTHDAY=28',
    checking,
    -1999,
    cats['Phone & internet'] ?? shopping,
    PostingMode.autoPost,
  );
  await rule(
    'Car insurance',
    'FREQ=MONTHLY;BYMONTHDAY=3',
    bills,
    -4620,
    cats['Insurance'] ?? shopping,
    PostingMode.autoPost,
  );
  await rule(
    'Salary',
    'FREQ=MONTHLY;BYMONTHDAY=1',
    checking,
    342000,
    salary,
    PostingMode.autoPost,
  );
  final period = DateTime(now.year, now.month);
  for (final (c, amount) in [
    (groceries, 40000),
    (eating, 15000),
    (shopping, 16000),
    (transport, 12000),
  ]) {
    await w.insert(
      db.budgets,
      BudgetsCompanion(
        categoryId: Value(c),
        periodStart: Value(period),
        amountMinor: Value(amount),
      ),
    );
  }
  await w.insert(
    db.goals,
    GoalsCompanion(
      name: const Value('Summer trip'),
      targetMinor: const Value(1200000),
      targetDate: Value(DateTime(now.year + 1, 6)),
      accountId: Value(savings),
      contributionMinor: const Value(15000),
    ),
  );
  await w.insert(
    db.goals,
    const GoalsCompanion(
      name: Value('Emergency fund'),
      targetMinor: Value(1000000),
      savedMinor: Value(420000),
      priority: Value(1),
    ),
  );
}

void main() {
  final out = Directory('build/screenshots')..createSync(recursive: true);
  final key = GlobalKey();

  Future<void> settle(WidgetTester tester, [int rounds = 10]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> shoot(WidgetTester tester, String name) async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    });
    File('${out.path}/$name.png').writeAsBytesSync(bytes!);
  }

  final shots = <(String, Size, ThemeMode, List<String>)>[
    (
      'phone',
      const Size(390, 844),
      ThemeMode.light,
      [
        '/home',
        '/transactions',
        '/plan',
        '/forecast',
        '/accounts',
        '/more/settings',
      ],
    ),
    ('phone_dark', const Size(390, 844), ThemeMode.dark, ['/home']),
    (
      'desktop',
      const Size(1440, 940),
      ThemeMode.light,
      [
        '/home',
        '/transactions',
        '/plan',
        '/forecast',
        '/reports/spending',
        '/more/import',
      ],
    ),
  ];

  for (final (label, size, mode, paths) in shots) {
    testWidgets('screens $label', (tester) async {
      await tester.runAsync(_loadFonts);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final db = newTestDb();
      await tester.runAsync(() => _seed(db, dark: mode == ThemeMode.dark));
      final initial = await tester.runAsync(() => loadSettings(db));
      final container = ProviderContainer(
        overrides: [
          ...dbOverrides(db, 'demo', clock: testClock()),
          initialSettingsProvider.overrideWithValue(initial!),
          forecastRunnerProvider.overrideWithValue(
            const ForecastRunner.inline(),
          ),
          secretStoreProvider.overrideWithValue(MemorySecretStore()),
        ],
      );
      try {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: RepaintBoundary(key: key, child: const PersonalFinanceApp()),
          ),
        );
        await settle(tester);
        final router = container.read(routerProvider);
        for (final p in paths) {
          router.go(p);
          await settle(tester, 14);
          await shoot(
            tester,
            '${label}_${p.replaceAll('/', '_').replaceFirst('_', '')}',
          );
        }
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
        container.dispose();
        unawaited(db.close());
        await tester.pump(const Duration(seconds: 1));
      }
    });
  }
}
