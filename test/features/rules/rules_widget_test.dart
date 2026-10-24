import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/features/rules/data/rule_repository.dart';
import 'package:personal_finance/features/rules/domain/rule_model.dart';
import 'package:personal_finance/features/rules/presentation/rule_editor_screen.dart';
import 'package:personal_finance/features/rules/presentation/rules_list_screen.dart';

import '../../helpers/test_app.dart';
import '../import/widget_test_utils.dart';

void main() {
  testWidgets('list shows rules in priority order with their summary', (
    tester,
  ) async {
    final db = (await tester.runAsync(() async => newTestDb()))!;
    await tester.pumpWidget(testApp(const RulesListScreen(), db: db));
    await settle(tester);
    expect(find.textContaining('No rules yet'), findsOneWidget);
    final c = ProviderScope.containerOf(
      tester.element(find.byType(RulesListScreen)),
    );
    await drive(tester, () async {
      final cat = await c
          .read(syncWriterProvider)
          .insert(
            db.categories,
            const CategoriesCompanion(
              name: Value('Groceries'),
              kind: Value(CategoryKind.expense),
            ),
          );
      final repo = c.read(ruleRepositoryProvider);
      await repo.save(
        RuleDef(
          name: 'Supermarket',
          conditions: const RuleConditions(
            items: [TextCondition(field: RuleTextField.payee, value: 'REWE')],
          ),
          actions: RuleActions(categoryId: cat),
        ),
      );
      await repo.save(
        const RuleDef(
          name: 'Fuel',
          enabled: false,
          conditions: RuleConditions(items: [TextCondition(value: 'Aral')]),
          actions: RuleActions(payee: 'Aral'),
        ),
      );
    }());
    await settle(tester);
    expect(find.text('Supermarket'), findsOneWidget);
    expect(find.text('Payee contains “REWE” → Groceries'), findsOneWidget);
    final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(switches.map((s) => s.value), [true, false]);
    await disposeDb(tester, db);
  });

  testWidgets('editor pre-filled from a transaction, live test, save', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = (await tester.runAsync(() async => newTestDb()))!;
    await tester.pumpWidget(
      testApp(
        RuleEditorScreen(
          from: TxnDraft(
            accountId: 'a',
            amountMinor: -4200,
            date: DateTime(2024),
            payee: 'Aral Tankstelle',
            note: 'Tanken',
          ),
        ),
        db: db,
      ),
    );
    await settle(tester);
    expect(find.widgetWithText(TextField, 'Aral Tankstelle'), findsWidgets);
    // The test card is pre-filled with the transaction: the rule matches but
    // has no action yet.
    expect(
      find.text('Matches, but the fields are already set'),
      findsOneWidget,
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Rename payee to'),
      'Aral',
    );
    await settle(tester);
    expect(find.text('Matches – would set:'), findsOneWidget);
    expect(find.text('Rename payee to: Aral'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Payee').last,
      'Shell',
    );
    await settle(tester);
    expect(find.text("Doesn't match"), findsOneWidget);

    final c = ProviderScope.containerOf(
      tester.element(find.byType(RuleEditorScreen)),
    );
    await tester.tap(find.text('Save'));
    await settle(tester);
    final saved = await drive(tester, c.read(ruleRepositoryProvider).all());
    expect(saved.single.name, 'Aral Tankstelle');
    expect(saved.single.actions.payee, 'Aral');
    await disposeDb(tester, db);
  });
}
