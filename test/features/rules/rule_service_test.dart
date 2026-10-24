import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/ledger/ledger_repository.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/features/rules/data/db_rule_service.dart';
import 'package:personal_finance/features/rules/data/rule_repository.dart';
import 'package:personal_finance/features/rules/domain/rule_model.dart';
import 'package:personal_finance/features/rules/domain/rule_service.dart';
import 'package:personal_finance/features/rules/presentation/rule_editor_screen.dart';

import '../../helpers/test_app.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer c;
  late RuleRepository repo;
  late RuleService service;
  late LedgerRepository ledger;
  late String giro;
  late String groceries;
  late String fuel;

  setUp(() async {
    db = newTestDb();
    c = testContainer(db);
    repo = c.read(ruleRepositoryProvider);
    service = c.read(ruleServiceProvider);
    ledger = c.read(ledgerRepositoryProvider);
    final w = c.read(syncWriterProvider);
    giro = await w.insert(
      db.accounts,
      AccountsCompanion(
        name: const Value('Giro'),
        type: const Value(AccountType.checking),
        openingDate: Value(DateTime(2024)),
      ),
    );
    groceries = await w.insert(
      db.categories,
      const CategoriesCompanion(
        name: Value('Groceries'),
        kind: Value(CategoryKind.expense),
      ),
    );
    fuel = await w.insert(
      db.categories,
      const CategoriesCompanion(
        name: Value('Fuel'),
        kind: Value(CategoryKind.expense),
      ),
    );
  });

  tearDown(() async {
    c.dispose();
    await db.close();
  });

  TxnDraft d(String payee, {String? category}) => TxnDraft(
    accountId: giro,
    amountMinor: -1000,
    date: DateTime(2024, 3),
    payee: payee,
    categoryId: category,
  );

  test('provider returns the DB implementation', () {
    expect(service, isA<DbRuleService>());
  });

  test('repository: save appends, reorder, enable, delete', () async {
    final a = await repo.save(
      RuleDef(
        name: 'A',
        conditions: const RuleConditions(items: [TextCondition(value: 'rewe')]),
        actions: RuleActions(categoryId: groceries),
      ),
    );
    final b = await repo.save(
      RuleDef(
        name: 'B',
        conditions: const RuleConditions(items: [TextCondition(value: 'aral')]),
        actions: RuleActions(categoryId: fuel),
      ),
    );
    expect([for (final r in await repo.all()) r.id], [a, b]);
    expect((await repo.byId(b))!.priority, 1);
    await repo.reorder([b, a]);
    expect([for (final r in await repo.all()) r.name], ['B', 'A']);
    await repo.setEnabled(a, enabled: false);
    expect((await repo.byId(a))!.enabled, isFalse);
    final edited = (await repo.byId(b))!.copyWith(name: 'B2');
    await repo.save(edited);
    expect((await repo.byId(b))!.name, 'B2');
    await repo.delete(a);
    expect(await repo.byId(a), isNull);
    expect(await repo.watchAll().first, hasLength(1));
  });

  test(
    'entry fills empty fields; import only touches rows without category',
    () async {
      await repo.save(
        RuleDef(
          name: 'R',
          conditions: const RuleConditions(
            items: [TextCondition(value: 'rewe')],
          ),
          actions: RuleActions(categoryId: groceries, payee: 'REWE'),
        ),
      );
      await repo.save(
        RuleDef(
          name: 'Import only',
          applyOnEntry: false,
          conditions: const RuleConditions(
            items: [TextCondition(value: 'aral')],
          ),
          actions: RuleActions(categoryId: fuel),
        ),
      );

      expect(
        (await service.apply(
          d('rewe 123'),
          trigger: RuleTrigger.entry,
        )).categoryId,
        groceries,
      );
      expect(
        (await service.apply(d('aral'), trigger: RuleTrigger.entry)).categoryId,
        isNull,
      );
      expect(
        (await service.apply(
          d('aral'),
          trigger: RuleTrigger.import,
        )).categoryId,
        fuel,
      );

      final out = await service.applyAll([
        d('rewe 1'),
        d('rewe 2', category: fuel),
      ], trigger: RuleTrigger.import);
      expect(out[0].categoryId, groceries);
      expect(out[0].payee, 'REWE');
      // Already categorised: untouched on import (also not renamed).
      expect(out[1].categoryId, fuel);
      expect(out[1].payee, 'rewe 2');
    },
  );

  test('re-run: preview counts, apply only uncategorised, then all', () async {
    final t1 = await ledger.create(d('REWE Markt'));
    final t2 = await ledger.create(d('REWE City', category: fuel));
    await ledger.create(d('Bäcker'));
    expect((await service.previewRerun()).changedCount, 0);
    await repo.save(
      RuleDef(
        name: 'R',
        conditions: const RuleConditions(items: [TextCondition(value: 'rewe')]),
        actions: RuleActions(categoryId: groceries),
      ),
    );

    final p = await service.previewRerun();
    expect(p.scanned, 2);
    expect(p.changedCount, 1);
    expect(p.changes.single.txnId, t1);
    expect(await service.rerunRules(), 1);
    expect((await ledger.txnById(t1))!.categoryId, groceries);
    expect((await ledger.txnById(t2))!.categoryId, fuel);

    final all = await service.previewRerun(onlyUncategorised: false);
    expect(all.scanned, 3);
    expect(all.changedCount, 1);
    expect(await service.rerunRules(onlyUncategorised: false), 1);
    expect((await ledger.txnById(t2))!.categoryId, groceries);
    expect(await service.rerunRules(onlyUncategorised: false), 0);
  });

  test('re-run keeps tags and custom fields, skips transfers', () async {
    final w = c.read(syncWriterProvider);
    final tag = await w.insert(db.tags, const TagsCompanion(name: Value('t')));
    final spar = await w.insert(
      db.accounts,
      AccountsCompanion(
        name: const Value('Spar'),
        type: const Value(AccountType.savings),
        openingDate: Value(DateTime(2024)),
      ),
    );
    final id = await ledger.create(d('rewe').copyWith(tagIds: [tag]));
    await ledger.create(
      TxnDraft(
        accountId: giro,
        transferAccountId: spar,
        amountMinor: -100,
        date: DateTime(2024),
        type: TxnType.transfer,
        payee: 'rewe',
      ),
    );
    await repo.save(
      RuleDef(
        name: 'R',
        conditions: const RuleConditions(items: [TextCondition(value: 'rewe')]),
        actions: RuleActions(categoryId: groceries),
      ),
    );
    expect(await service.rerunRules(), 1);
    expect(await ledger.tagIdsFor(id), [tag]);
  });

  test('rule from a transaction', () {
    final r = ruleFromDraft(
      d('Aral Tankstelle', category: fuel).copyWith(tagIds: ['x']),
    );
    expect(r.name, 'Aral Tankstelle');
    expect(
      r.conditions.items.single,
      const TextCondition(field: RuleTextField.payee, value: 'Aral Tankstelle'),
    );
    expect(r.actions.categoryId, fuel);
    expect(r.actions.addTagIds, ['x']);
    final n = ruleFromDraft(
      TxnDraft(
        accountId: giro,
        amountMinor: 1,
        date: DateTime(2024),
        note: 'Miete',
      ),
    );
    expect(
      n.conditions.items.single,
      const TextCondition(field: RuleTextField.note, value: 'Miete'),
    );
    expect(
      DbRuleService.test(r, d('ARAL TANKSTELLE 12')).draft.categoryId,
      fuel,
    );
  });
}
