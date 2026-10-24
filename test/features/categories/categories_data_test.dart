import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/core/ledger/ledger_repository.dart';
import 'package:personal_finance/core/ledger/lookups.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/features/categories/data/categories_repository.dart';
import 'package:personal_finance/features/categories/data/custom_fields_repository.dart';
import 'package:personal_finance/features/categories/data/tags_repository.dart';
import 'package:personal_finance/features/categories/domain/default_categories.dart';
import 'package:personal_finance/features/categories/domain/drafts.dart';

import '../../helpers/test_app.dart';

void main() {
  late AppDatabase db;
  late SyncWriter writer;
  late LedgerRepository ledger;
  late CategoriesRepository cats;
  late String account;

  setUp(() async {
    db = newTestDb();
    writer = SyncWriter(db, testClock(), 'dev-1');
    ledger = LedgerRepository(db, writer);
    cats = CategoriesRepository(db, writer, ledger);
    account = await writer.insert(
      db.accounts,
      AccountsCompanion(
        name: const Value('Checking'),
        type: const Value(AccountType.checking),
        openingDate: Value(DateTime(2026)),
      ),
    );
  });

  tearDown(() => db.close());

  Future<List<Category>> live() =>
      (db.select(db.categories)..where((c) => c.deletedAt.isNull())).get();

  Future<String> cat(
    String name, {
    String? parent,
    CategoryKind kind = CategoryKind.expense,
  }) => cats.create(CategoryDraft(name: name, kind: kind, parentId: parent));

  group('default categories', () {
    test('seeding is idempotent and builds two levels', () async {
      await seedDefaultCategories(writer, db, DefaultCategorySet.de);
      final first = await live();
      expect(first.length, greaterThan(30));
      await seedDefaultCategories(writer, db, DefaultCategorySet.en);
      expect((await live()).length, first.length);

      final byName = {for (final c in first) c.name: c};
      final wohnen = byName['Wohnen']!;
      expect(wohnen.parentId, isNull);
      expect(byName['Miete']!.parentId, wohnen.id);
      expect(byName['Miete']!.color, wohnen.color);
      expect(byName['Gehalt']!.kind, CategoryKind.income);
      expect(first.every((c) => c.icon != null && c.color != null), isTrue);
      final tree = categoryTree(first, kind: CategoryKind.expense);
      expect(tree.first.$1.name, 'Lebensmittel');
      expect(tree.every((e) => e.$1.parentId == null), isTrue);
    });

    test('English set', () async {
      await seedDefaultCategories(writer, db, DefaultCategorySet.en);
      final names = (await live()).map((c) => c.name).toSet();
      expect(names, containsAll(['Groceries', 'Rent', 'Salary']));
    });
  });

  group('CategoriesRepository', () {
    test('subcategory takes the parent kind; no third level', () async {
      final income = await cat('Work', kind: CategoryKind.income);
      final child = await cat('Bonus', parent: income);
      final c = (await cats.byId(child))!;
      expect(c.kind, CategoryKind.income);
      await expectLater(
        cat('Deeper', parent: child),
        throwsA(isA<CategoryException>()),
      );
    });

    test('reorder sets sibling order', () async {
      final a = await cat('A');
      final b = await cat('B');
      final c = await cat('C');
      await cats.reorder([c, a, b]);
      final order = {for (final x in await live()) x.id: x.sortOrder};
      expect(order, {c: 0, a: 1, b: 2});
    });

    test('archiving a parent archives children', () async {
      final p = await cat('P');
      final ch = await cat('C', parent: p);
      await cats.setArchived(p, archived: true);
      expect((await cats.byId(ch))!.archived, isTrue);
      await cats.setArchived(ch, archived: false);
      expect((await cats.byId(p))!.archived, isFalse);
    });

    test('delete is refused when used or with children', () async {
      final p = await cat('P');
      await cat('C', parent: p);
      final used = await cat('Used');
      await ledger.create(
        TxnDraft(
          accountId: account,
          amountMinor: -100,
          date: DateTime(2026, 2),
          categoryId: used,
        ),
      );
      await expectLater(cats.delete(p), throwsA(isA<CategoryException>()));
      await expectLater(cats.delete(used), throwsA(isA<CategoryException>()));
      final free = await cat('Free');
      await cats.delete(free);
      expect((await live()).any((c) => c.id == free), isFalse);
    });

    test('merge moves transactions, splits, budgets and children', () async {
      final source = await cat('Food');
      final sourceChild = await cat('Snacks', parent: source);
      final target = await cat('Groceries');
      final other = await cat('Household');
      final t1 = await ledger.create(
        TxnDraft(
          accountId: account,
          amountMinor: -500,
          date: DateTime(2026, 2),
          categoryId: source,
        ),
      );
      final split = await ledger.create(
        TxnDraft(
          accountId: account,
          amountMinor: -1000,
          date: DateTime(2026, 2),
          splits: [
            SplitDraft(amountMinor: -600, categoryId: source),
            SplitDraft(amountMinor: -400, categoryId: other),
          ],
        ),
      );
      Future<String> budget(String c, DateTime p, int amount) => writer.insert(
        db.budgets,
        BudgetsCompanion(
          categoryId: Value(c),
          periodStart: Value(p),
          amountMinor: Value(amount),
        ),
      );
      await budget(source, DateTime(2026, 2), 10000);
      await budget(target, DateTime(2026, 2), 20000);
      final march = await budget(source, DateTime(2026, 3), 5000);
      final ruleId = await writer.insert(
        db.rules,
        RulesCompanion(
          name: const Value('r'),
          conditions: const Value('[]'),
          actions: Value(jsonEncode({'categoryId': source})),
        ),
      );

      await cats.merge(source, target);

      expect((await ledger.txnById(t1))!.categoryId, target);
      final splits = await ledger.splitsFor(split);
      expect(splits.map((s) => s.categoryId), [target, other]);
      final budgets = await (db.select(
        db.budgets,
      )..where((b) => b.deletedAt.isNull())).get();
      expect(budgets, hasLength(2));
      final feb = budgets.firstWhere((b) => b.periodStart == DateTime(2026, 2));
      expect(feb.categoryId, target);
      expect(feb.amountMinor, 30000);
      expect(budgets.firstWhere((b) => b.id == march).categoryId, target);
      expect((await cats.byId(sourceChild))!.parentId, target);
      expect(await cats.byId(source), isNull);
      final rule = await (db.select(
        db.rules,
      )..where((r) => r.id.equals(ruleId))).getSingle();
      expect(jsonDecode(rule.actions), {'categoryId': target});
    });

    test('merge validation', () async {
      final a = await cat('A');
      final aChild = await cat('A1', parent: a);
      final b = await cat('B');
      final bChild = await cat('B1', parent: b);
      final income = await cat('I', kind: CategoryKind.income);
      Future<void> fails(String s, String t) =>
          expectLater(cats.merge(s, t), throwsA(isA<CategoryException>()));
      await fails(a, a);
      await fails(a, income);
      await fails(a, aChild);
      await fails(a, bChild);
      // A leaf can be merged into a subcategory.
      await cats.merge(aChild, bChild);
      expect(await cats.byId(aChild), isNull);
    });
  });

  group('TagsRepository', () {
    late TagsRepository tags;
    setUp(() => tags = TagsRepository(db, writer));

    test('names are unique and normalised', () async {
      final id = await tags.create('#Vacation ');
      final t = await (db.select(
        db.tags,
      )..where((x) => x.id.equals(id))).getSingle();
      expect(t.name, 'Vacation');
      await expectLater(
        tags.create('vacation'),
        throwsA(isA<TagNameException>()),
      );
      expect(await tags.ensure('VACATION'), id);
    });

    test('merge re-points links without duplicates', () async {
      final a = await tags.create('a');
      final b = await tags.create('b');
      final t1 = await ledger.create(
        TxnDraft(
          accountId: account,
          amountMinor: -1,
          date: DateTime(2026),
          tagIds: [a, b],
        ),
      );
      final t2 = await ledger.create(
        TxnDraft(
          accountId: account,
          amountMinor: -1,
          date: DateTime(2026),
          tagIds: [a],
        ),
      );
      await tags.merge(a, b);
      expect(await ledger.tagIdsFor(t1), [b]);
      expect(await ledger.tagIdsFor(t2), [b]);
      final live = await (db.select(
        db.tags,
      )..where((x) => x.deletedAt.isNull())).get();
      expect(live.map((t) => t.id), [b]);
    });

    test('delete removes links', () async {
      final a = await tags.create('a');
      final t1 = await ledger.create(
        TxnDraft(
          accountId: account,
          amountMinor: -1,
          date: DateTime(2026),
          tagIds: [a],
        ),
      );
      await tags.delete(a);
      expect(await ledger.tagIdsFor(t1), isEmpty);
    });
  });

  group('CustomFieldsRepository', () {
    late CustomFieldsRepository fields;
    setUp(() => fields = CustomFieldsRepository(db, writer));

    test('options are cleaned; select needs options', () async {
      expect(
        () => fields.create(
          const CustomFieldDraft(name: 'Kind', type: CustomFieldType.select),
        ),
        throwsArgumentError,
      );
      final id = await fields.create(
        const CustomFieldDraft(
          name: ' Kind ',
          type: CustomFieldType.select,
          options: ['a', ' b', '', 'A'],
        ),
      );
      final d = await (db.select(
        db.customFieldDefs,
      )..where((x) => x.id.equals(id))).getSingle();
      expect(d.name, 'Kind');
      expect(decodeOptions(d.options), ['a', 'b']);
      expect(d.appliesTo, 'transaction');
    });

    test('type is locked once values exist; delete removes values', () async {
      final id = await fields.create(
        const CustomFieldDraft(name: 'Ref', type: CustomFieldType.text),
      );
      final second = await fields.create(
        const CustomFieldDraft(
          name: 'Flag',
          type: CustomFieldType.boolean,
          appliesTo: CustomFieldTarget.account,
        ),
      );
      await ledger.create(
        TxnDraft(
          accountId: account,
          amountMinor: -1,
          date: DateTime(2026),
          customFields: {id: 'R-1'},
        ),
      );
      expect(await fields.valueCount(id), 1);
      await expectLater(
        fields.update(
          id,
          const CustomFieldDraft(name: 'Ref', type: CustomFieldType.number),
        ),
        throwsA(isA<CustomFieldTypeLockedException>()),
      );
      await fields.reorder([second, id]);
      final defs = await (db.select(
        db.customFieldDefs,
      )..orderBy([(d) => OrderingTerm(expression: d.sortOrder)])).get();
      expect(defs.map((d) => d.id), [second, id]);
      await fields.delete(id);
      expect(await fields.valueCount(id), 0);
    });
  });
}
