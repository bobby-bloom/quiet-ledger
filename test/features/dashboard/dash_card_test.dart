import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/app/ui/amount_text.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/core/ledger/ledger_repository.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/dashboard/data/dashboard_layout.dart';
import 'package:personal_finance/features/dashboard/presentation/card_expansion.dart';
import 'package:personal_finance/features/dashboard/presentation/widget_registry.dart';
import 'package:personal_finance/features/dashboard/presentation/widgets/core_widgets.dart';
import 'package:personal_finance/features/dashboard/presentation/widgets/plan_widgets.dart';
import 'package:personal_finance/features/forecast/presentation/forecast_providers.dart';
import 'package:personal_finance/features/transactions/transactions.dart';

import '../../helpers/test_app.dart';

/// Renders [initial] like the dashboard does: options from the registry,
/// updates applied in place.
class _Board extends ConsumerStatefulWidget {
  const _Board(this.initial);

  final List<DashboardItem> initial;

  @override
  ConsumerState<_Board> createState() => _BoardState();
}

class _BoardState extends ConsumerState<_Board> {
  late List<DashboardItem> items = widget.initial;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            for (final (i, item) in items.indexed)
              buildDashboardWidget(
                context,
                item,
                compact: compact,
                options: widgetOptions(
                  context,
                  ref,
                  item,
                  (next) => setState(() => items = [...items]..[i] = next),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

void main() {
  late AppDatabase db;

  Future<void> seed() async {
    db = newTestDb();
    final w = SyncWriter(db, testClock(), 'd');
    final ledger = LedgerRepository(db, w);
    final checking = await w.insert(
      db.accounts,
      AccountsCompanion(
        name: const Value('Everyday checking'),
        type: const Value(AccountType.checking),
        openingBalanceMinor: const Value(100000),
        openingDate: Value(DateTime(2025)),
      ),
    );
    final today = dateOnly(DateTime.now());
    for (var i = 1; i <= 12; i++) {
      await ledger.create(
        TxnDraft(
          accountId: checking,
          amountMinor: -100 * i,
          date: today.subtract(Duration(days: i)),
          payee: 'Shop $i',
        ),
      );
    }
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> teardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    unawaited(db.close());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> pumpBoard(
    WidgetTester tester,
    List<DashboardItem> items, {
    Size size = const Size(1200, 1600),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(
        _Board(items),
        db: db,
        overrides: [
          forecastRunnerProvider.overrideWithValue(
            const ForecastRunner.inline(),
          ),
        ],
      ),
    );
    await settle(tester);
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(_Board)));

  Finder menuOf(String title) => find.descendant(
    of: find.ancestor(of: find.text(title), matching: find.byType(Card)),
    matching: find.byIcon(Icons.more_vert),
  );

  const accounts = DashboardItem(DashboardWidgetType.accounts);
  const recent = DashboardItem(DashboardWidgetType.recentTransactions);

  testWidgets('folding persists in the device-local setting', (tester) async {
    await tester.runAsync(seed);
    try {
      await pumpBoard(tester, const [accounts]);
      expect(find.text('Everyday checking'), findsOneWidget);
      expect(find.text('View all'), findsOneWidget);
      // The peek is shown while open.
      expect(find.textContaining('across 1 account'), findsOneWidget);

      await tester.tap(find.byTooltip('Collapse Accounts'));
      await settle(tester);
      expect(find.text('Everyday checking'), findsNothing);
      expect(find.text('View all'), findsNothing);
      expect(find.textContaining('across 1 account'), findsOneWidget);
      expect(
        containerOf(tester)
            .read(settingsProvider)
            .get(DashboardSettings.cardExpansion),
        '{"accounts":false}',
      );

      // A fresh app on this database starts folded.
      await tester.pumpWidget(const SizedBox());
      await pumpBoard(tester, const [accounts]);
      expect(find.byTooltip('Expand Accounts'), findsOneWidget);
      expect(find.text('Everyday checking'), findsNothing);

      await tester.tap(find.byTooltip('Expand Accounts'));
      await settle(tester);
      expect(find.text('Everyday checking'), findsOneWidget);
      expect(
        containerOf(tester)
            .read(cardExpansionProvider)
            .isOpen(DashboardWidgetType.accounts),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    } finally {
      await teardown(tester);
    }
  });

  testWidgets('net worth folds on wide screens only', (tester) async {
    await tester.runAsync(seed);
    try {
      const items = [DashboardItem(DashboardWidgetType.netWorth)];
      await pumpBoard(tester, items, size: const Size(390, 844));
      expect(find.byTooltip('Collapse Net worth'), findsNothing);
      expect(find.byType(NetWorthWidget), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await pumpBoard(tester, items);
      expect(find.byTooltip('Collapse Net worth'), findsOneWidget);
    } finally {
      await teardown(tester);
    }
  });

  testWidgets('a folded card offers its footer link first in ⋮', (
    tester,
  ) async {
    await tester.runAsync(seed);
    try {
      await pumpBoard(tester, const [recent]);
      await tester.tap(menuOf('Recent transactions'));
      await tester.pumpAndSettle();
      // Open: the link is in the footer, not in the menu.
      expect(find.text('View all'), findsOneWidget);
      expect(find.text('Rows'), findsOneWidget);
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Collapse Recent transactions'));
      await settle(tester);
      expect(find.text('View all'), findsNothing);
      await tester.tap(menuOf('Recent transactions'));
      await tester.pumpAndSettle();
      final link = find.text('View all');
      expect(link, findsOneWidget);
      expect(
        tester.getTopLeft(link).dy,
        lessThan(tester.getTopLeft(find.text('Rows')).dy),
      );
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();
    } finally {
      await teardown(tester);
    }
  });

  testWidgets('privacy mode masks a peek', (tester) async {
    await tester.runAsync(seed);
    try {
      await pumpBoard(tester, const [accounts]);
      await tester.tap(find.byTooltip('Collapse Accounts'));
      await settle(tester);
      final card = find.ancestor(
        of: find.text('Accounts'),
        matching: find.byType(Card),
      );
      final blurred = find.descendant(
        of: card,
        matching: find.byType(ImageFiltered),
      );
      expect(blurred, findsNothing);

      containerOf(tester).read(privacyModeProvider.notifier).hidden = true;
      await tester.pump();
      // Only the peek's total is left on the folded card, and it is masked.
      expect(blurred, findsOneWidget);
      expect(find.textContaining('across 1 account'), findsOneWidget);
    } finally {
      await teardown(tester);
    }
  });

  test('setAll and wouldChange; malformed JSON means all open', () async {
    final db = newTestDb();
    addTearDown(db.close);
    final c = testContainer(db);
    addTearDown(c.dispose);
    const all = DashboardWidgetType.values;
    final n = c.read(cardExpansionProvider.notifier);
    expect(n.isOpen(DashboardWidgetType.goals), isTrue);
    expect(n.wouldChange(all, true), isFalse);
    expect(n.wouldChange(all, false), isTrue);

    n.setOpen(DashboardWidgetType.goals, false);
    expect(n.isOpen(DashboardWidgetType.goals), isFalse);
    expect(n.wouldChange(all, true), isTrue);
    expect(n.wouldChange([DashboardWidgetType.goals], false), isFalse);

    n.setAll(all, false);
    expect(all.every((t) => !n.isOpen(t)), isTrue);
    expect(n.wouldChange(all, false), isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(
      CardExpansion.decode(
        c.read(settingsProvider).get(DashboardSettings.cardExpansion),
      ),
      c.read(cardExpansionProvider),
    );

    n.setAll(all, true);
    expect(n.wouldChange(all, true), isFalse);

    await c
        .read(settingsProvider.notifier)
        .set(DashboardSettings.cardExpansion, '{not json');
    expect(c.read(cardExpansionProvider).folded, isEmpty);
    expect(CardExpansion.decode('[1, 2]').folded, isEmpty);
    expect(DashboardSettings.cardExpansion.deviceLocal, isTrue);
    expect(DashboardSettings.cardExpansion.hidden, isTrue);
    expect(DashboardSettings.all, contains(DashboardSettings.cardExpansion));
  });

  testWidgets('Rows 10 on recent transactions shows ten rows', (tester) async {
    await tester.runAsync(seed);
    try {
      await pumpBoard(tester, const [recent]);
      expect(find.byType(TransactionTile), findsNWidgets(5));

      await tester.tap(menuOf('Recent transactions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('10'));
      await tester.pumpAndSettle();
      await settle(tester);
      expect(find.byType(TransactionTile), findsNWidgets(10));
      expect(
        tester
            .widget<RecentTransactionsWidget>(
              find.byType(RecentTransactionsWidget),
            )
            .limit,
        10,
      );
    } finally {
      await teardown(tester);
    }
  });

  testWidgets('list widgets keep their lengths; others have no Rows', (
    tester,
  ) async {
    await tester.runAsync(() async => db = newTestDb());
    try {
      await pumpBoard(tester, const []);
      final context = tester.element(find.byType(_Board));
      final ref = tester.state<_BoardState>(find.byType(_Board)).ref;

      int limitOf(DashboardWidgetType t) {
        final w = buildDashboardWidget(
          context,
          DashboardItem(t),
          compact: false,
          options: const [],
        );
        return switch (w) {
          final BudgetsWidget w => w.limit,
          final UpcomingBillsWidget w => w.limit,
          final GoalsWidget w => w.limit,
          final TopCategoriesWidget w => w.limit,
          final RecentTransactionsWidget w => w.limit,
          final AccountsWidget w => w.limit,
          _ => throw StateError('$t is not a list'),
        };
      }

      // Today's lengths stay the defaults.
      expect(limitOf(DashboardWidgetType.budgets), const BudgetsWidget().limit);
      expect(limitOf(DashboardWidgetType.budgets), 4);
      expect(limitOf(DashboardWidgetType.upcomingBills), 4);
      expect(limitOf(DashboardWidgetType.goals), 3);
      expect(limitOf(DashboardWidgetType.topCategories), 5);
      expect(limitOf(DashboardWidgetType.recentTransactions), 5);
      expect(limitOf(DashboardWidgetType.accounts), 8);
      expect(const AccountsWidget().limit, 8);

      List<String> rows(DashboardWidgetType t) => [
        for (final o in widgetOptions(context, ref, DashboardItem(t), (_) {}))
          if (o.group == 'Rows') o.label,
      ];
      expect(rows(DashboardWidgetType.budgets), ['3', '4', '5', '10']);
      expect(rows(DashboardWidgetType.upcomingBills), ['3', '4', '5', '10']);
      expect(rows(DashboardWidgetType.goals), ['3', '5', '10']);
      expect(rows(DashboardWidgetType.topCategories), ['3', '5', '10']);
      expect(rows(DashboardWidgetType.recentTransactions), ['3', '5', '10']);
      expect(rows(DashboardWidgetType.accounts), ['3', '5', '8', '10']);
      for (final t in [
        DashboardWidgetType.netWorth,
        DashboardWidgetType.monthSummary,
        DashboardWidgetType.forecast,
      ]) {
        expect(rows(t), isEmpty, reason: t.name);
        expect(rowChoices(t), isNull);
      }
      // The current value is the checked one; a stored limit wins.
      final checked = widgetOptions(
        context,
        ref,
        const DashboardItem(DashboardWidgetType.goals, options: {'limit': 10}),
        (_) {},
      ).where((o) => o.checked).map((o) => o.label);
      expect(checked, ['10']);
    } finally {
      await teardown(tester);
    }
  });
}
