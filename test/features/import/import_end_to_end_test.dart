import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/ledger/ledger_repository.dart';
import 'package:personal_finance/features/import/data/import_repository.dart';
import 'package:personal_finance/features/import/data/import_service.dart';
import 'package:personal_finance/features/import/data/profile_repository.dart';
import 'package:personal_finance/features/import/domain/import_analysis.dart';
import 'package:personal_finance/features/import/domain/import_config.dart';
import 'package:personal_finance/features/import/domain/raw_sheet.dart';
import 'package:personal_finance/features/rules/data/rule_repository.dart';
import 'package:personal_finance/features/rules/domain/rule_model.dart';

import '../../helpers/test_app.dart';

const fixtures = 'test/fixtures/import';

// Closing balances of the fixture sheets (last running-balance cell).
const giroClosing = 3464494; // 34.644,94
const sparClosing = 813745; // 8.137,45
const csvClosing = 623898; // 6.238,98

Future<RawWorkbook> load(ImportService s, String name) =>
    s.read(ImportSource.file(name, File('$fixtures/$name').readAsBytesSync()));

/// Girokonto log + Sparkonto export, with the log's fixed account named
/// "Girokonto".
ImportConfig householdConfig(List<RawWorkbook> wbs) {
  final cfg = initialConfig(wbs);
  return cfg.copyWith(
    sheets: [
      for (final s in cfg.sheets)
        if (s.fileName == 'haushaltsbuch.xlsx')
          s.copyWith(fixedAccount: 'Girokonto')
        else
          s,
    ],
  );
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late ImportService service;
  late LedgerRepository ledger;

  setUp(() {
    db = newTestDb();
    container = testContainer(db);
    service = container.read(importServiceProvider);
    ledger = container.read(ledgerRepositoryProvider);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<Map<String, int>> balancesByName() async {
    final balances = await ledger.balances();
    final accounts = await (db.select(
      db.accounts,
    )..where((a) => a.deletedAt.isNull())).get();
    return {for (final a in accounts) a.name: balances[a.id]!};
  }

  Future<int> liveTxnCount() async {
    final rows = await (db.select(
      db.transactions,
    )..where((t) => t.deletedAt.isNull())).get();
    return rows.length;
  }

  test(
    'household xlsx files → commit → balances equal the sheets, '
    'transfers merged, undo restores, re-import detects duplicates',
    () async {
      final wbs = [
        await load(service, 'haushaltsbuch.xlsx'),
        await load(service, 'sparkonto_sh.xlsx'),
      ];
      final cfg = householdConfig(wbs);
      final ctx = await service.loadContext(wbs);
      final analysis = await service.analyse(wbs, cfg, ctx);

      // 166 log rows + 20 savings rows; 18 monthly transfers of 200 and one
      // of 500 back.
      expect(analysis.rows, hasLength(186));
      expect(analysis.invalidRowCount, 0);
      expect(analysis.transfers, hasLength(19));
      for (final b in analysis.balances) {
        expect(b.mismatches, isEmpty, reason: b.groupKey);
      }

      final prep = await service.prepare(analysis, cfg, ctx);
      expect(prep.summary.transfers, 19);
      expect(prep.summary.transactions, 186 - 19);
      final giro = prep.summary.accounts.firstWhere(
        (a) => a.name == 'Girokonto',
      );
      final spar = prep.summary.accounts.firstWhere(
        (a) => a.name == 'Sparkonto',
      );
      expect(giro.startMinor, 123456);
      expect(giro.resultingMinor, giroClosing);
      expect(giro.matchesSheet, isTrue);
      expect(spar.startMinor, 500000);
      expect(spar.resultingMinor, sparClosing);
      expect(spar.matchesSheet, isTrue);

      final result = await service.commit(prep, workbooks: wbs, config: cfg);
      expect(await balancesByName(), {
        'Girokonto': giroClosing,
        'Sparkonto': sparClosing,
      });
      // Transfers are two linked legs.
      final transfers =
          await (db.select(db.transactions)..where(
                (t) => t.deletedAt.isNull() & t.transferPeerId.isNotNull(),
              ))
              .get();
      expect(transfers, hasLength(38));
      // The "Umbuchung" category was only used by merged rows: not created.
      final cats = await (db.select(
        db.categories,
      )..where((c) => c.deletedAt.isNull())).get();
      expect(cats.map((c) => c.name), isNot(contains('Umbuchung')));
      expect(
        cats.map((c) => c.name),
        containsAll(['Lebensmittel', 'Supermarkt', 'Bäckerei']),
      );
      final supermarkt = cats.firstWhere((c) => c.name == 'Supermarkt');
      expect(
        cats.firstWhere((c) => c.id == supermarkt.parentId).name,
        'Lebensmittel',
      );

      // Batch row.
      final batch = (await container
          .read(importRepositoryProvider)
          .batch(result.batchId))!;
      expect(batch.batch.rowCount, 167);
      expect(batch.batch.fileName, 'haushaltsbuch.xlsx, sparkonto_sh.xlsx');
      // A merged transfer counts for the file of its outgoing row.
      expect(batch.files.map((f) => f.rows), [165, 2]);
      expect(batch.liveCount, 167 + 19);
      // Every row carries its source reference and hash.
      final rows = await (db.select(
        db.transactions,
      )..where((t) => t.deletedAt.isNull())).get();
      expect(rows.every((r) => r.importBatchId == result.batchId), isTrue);
      expect(
        rows.every((r) => r.importRowRef != null && r.dedupeHash != null),
        isTrue,
      );
      final rewe = rows.firstWhere(
        (r) => r.payee == 'REWE Markt' && r.date == DateTime(2023, 1, 5),
      );
      expect(rewe.amountMinor, -(4567 + 111));
      expect(rewe.importRowRef, 'haushaltsbuch.xlsx|2023|8');

      // Re-import of the same files: everything is already imported.
      final ctx2 = await service.loadContext(wbs);
      final again = await service.analyse(wbs, cfg, ctx2);
      expect(
        again.rows.every((r) => r.dup == DupStatus.alreadyImported),
        isTrue,
      );
      final prep2 = await service.prepare(again, cfg, ctx2);
      expect(prep2.summary.transactions, 0);
      expect(prep2.summary.alreadyImported, 186);

      // Without incremental mode they are reported as duplicates of existing
      // transactions and skipped by default.
      final cfg3 = cfg.copyWith(incremental: false);
      final again3 = await service.analyse(wbs, cfg3, ctx2);
      expect(again3.rows.every((r) => r.dup == DupStatus.existing), isTrue);
      expect(
        (await service.prepare(again3, cfg3, ctx2)).summary.transactions,
        0,
      );

      // Undo removes all rows and the created (now unused) accounts and
      // categories.
      final deleted = await container
          .read(importRepositoryProvider)
          .undo(result.batchId);
      expect(deleted, 186);
      expect(await liveTxnCount(), 0);
      expect(await balancesByName(), isEmpty);
      final liveCats = await (db.select(
        db.categories,
      )..where((c) => c.deletedAt.isNull())).get();
      expect(liveCats, isEmpty);
      final undone = (await container
          .read(importRepositoryProvider)
          .batch(result.batchId))!;
      expect(undone.isUndone, isTrue);

      // After undo the files count as new again.
      final ctx4 = await service.loadContext(wbs);
      final fresh = await service.analyse(wbs, cfg, ctx4);
      expect(fresh.rows.every((r) => r.dup == DupStatus.unique), isTrue);
    },
  );

  test(
    'into existing accounts: balances add up, profile saved and reused',
    () async {
      final writer = container.read(syncWriterProvider);
      final giroId = await writer.insert(
        db.accounts,
        AccountsCompanion(
          name: const Value('Girokonto'),
          type: const Value(AccountType.checking),
          openingBalanceMinor: const Value(200000),
          openingDate: Value(DateTime(2023, 12, 31)),
        ),
      );
      final wb = await load(service, 'umsaetze_win1252.csv');
      var cfg = initialConfig([wb]);
      final sheet = cfg.sheets.single;
      cfg = cfg.withSheet(sheet.copyWith(fixedAccount: 'Girokonto'));
      final ctx = await service.loadContext([wb]);
      final analysis = await service.analyse([wb], cfg, ctx);
      // The existing account is matched by name.
      expect(analysis.accountTargets['girokonto']!.existingId, giroId);
      final report = analysis.balances.single;
      expect(report.descending, isTrue);
      expect(report.openingMinor, 200000);
      expect(report.closingMinor, csvClosing);

      final prep = await service.prepare(analysis, cfg, ctx);
      final result = await service.commit(
        prep,
        workbooks: [wb],
        config: cfg,
        saveProfileAs: 'Sparkasse CSV',
      );
      expect((await ledger.balances())[giroId], csvClosing);

      final profiles = await container
          .read(importProfileRepositoryProvider)
          .all();
      expect(profiles.single.name, 'Sparkasse CSV');
      final batch = (await container
          .read(importRepositoryProvider)
          .batch(result.batchId))!;
      expect(batch.batch.profileId, profiles.single.id);

      // One-click re-import with the profile: same mapping, nothing new.
      final profileCfg = ImportProfileRepository.configOf(profiles.single);
      final reCfg = initialConfig([wb], profile: profileCfg);
      expect(reCfg.sheets.single.fixedAccount, 'Girokonto');
      expect(reCfg.accounts['girokonto']?.existingId, giroId);
      final ctx2 = await service.loadContext([
        wb,
      ], profileId: profiles.single.id);
      final re = await service.analyse([wb], reCfg, ctx2);
      expect(re.rows.every((r) => r.dup == DupStatus.alreadyImported), isTrue);

      // Undo keeps the pre-existing account.
      await container.read(importRepositoryProvider).undo(result.batchId);
      expect((await ledger.balances())[giroId], 200000);
    },
  );

  test('rules categorise imported rows without category', () async {
    final writer = container.read(syncWriterProvider);
    final gehalt = await writer.insert(
      db.categories,
      const CategoriesCompanion(
        name: Value('Gehalt'),
        kind: Value(CategoryKind.income),
      ),
    );
    await container
        .read(ruleRepositoryProvider)
        .save(
          RuleDef(
            name: 'Gehalt',
            conditions: const RuleConditions(
              items: [
                TextCondition(field: RuleTextField.payee, value: 'arbeitgeber'),
              ],
            ),
            actions: RuleActions(categoryId: gehalt),
          ),
        );
    final wb = await load(service, 'umsaetze_win1252.csv');
    final cfg = initialConfig([wb]);
    final ctx = await service.loadContext([wb]);
    final analysis = await service.analyse([wb], cfg, ctx);
    final prep = await service.prepare(analysis, cfg, ctx);
    expect(prep.categorisedByRules, 2);
    await service.commit(prep, workbooks: [wb], config: cfg);
    final rows = await (db.select(
      db.transactions,
    )..where((t) => t.categoryId.equals(gehalt))).get();
    expect(rows.map((r) => r.amountMinor), [325000, 325000]);

    // Without rules nothing is categorised.
    final noRules = cfg.copyWith(
      applyRules: false,
      incremental: false,
      duplicates: DuplicatePolicy.import,
    );
    final ctx2 = await service.loadContext([wb]);
    final a2 = await service.analyse([wb], noRules, ctx2);
    final p2 = await service.prepare(a2, noRules, ctx2);
    expect(p2.categorisedByRules, 0);
    expect(p2.summary.transactions, 8);
  });
}
