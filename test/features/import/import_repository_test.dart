import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/ledger_repository.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/features/import/data/import_repository.dart';
import 'package:personal_finance/features/import/data/import_service.dart';
import 'package:personal_finance/features/import/data/profile_repository.dart';
import 'package:personal_finance/features/import/domain/import_analysis.dart';
import 'package:personal_finance/features/import/domain/import_config.dart';

import '../../helpers/test_app.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer c;

  setUp(() {
    db = newTestDb();
    c = testContainer(db);
  });

  tearDown(() async {
    c.dispose();
    await db.close();
  });

  test('profiles: save, export, import with a unique name, delete', () async {
    final repo = c.read(importProfileRepositoryProvider);
    const cfg = ImportConfig(transfers: TransferConfig(windowDays: 5));
    final id = await repo.save(name: 'Bank', config: cfg);
    final p = (await repo.byId(id))!;
    final json = ImportProfileRepository.exportJson(p);
    expect(
      jsonDecode(json),
      containsPair('format', ImportProfileRepository.formatId),
    );
    final id2 = await repo.importJson(json);
    final p2 = (await repo.byId(id2))!;
    expect(p2.name, 'Bank (2)');
    expect(ImportProfileRepository.configOf(p2).transfers.windowDays, 5);
    expect(
      () => ImportProfileRepository.parseExport('{"a":1}'),
      throwsFormatException,
    );
    await repo.rename(id2, 'Other');
    expect((await repo.byId(id2))!.name, 'Other');
    await repo.delete(id);
    expect(await repo.all(), hasLength(1));
  });

  test('undo keeps created categories that are used elsewhere', () async {
    final service = c.read(importServiceProvider);
    final repo = c.read(importRepositoryProvider);
    final ledger = c.read(ledgerRepositoryProvider);
    const name = 'statement_en.csv';
    final wb = await service.read(
      ImportSource.file(
        name,
        File('test/fixtures/import/$name').readAsBytesSync(),
      ),
    );
    final cfg = initialConfig([wb]);
    final ctx = await service.loadContext([wb]);
    final prep = await service.prepare(
      await service.analyse([wb], cfg, ctx),
      cfg,
      ctx,
    );
    final r = await service.commit(prep, workbooks: [wb], config: cfg);

    // The user books another transaction into an imported category.
    final cats = await (db.select(
      db.categories,
    )..where((x) => x.deletedAt.isNull())).get();
    final rent = cats.firstWhere((x) => x.name == 'Rent');
    final acc = (await db.select(db.accounts).get()).single;
    await ledger.create(
      TxnDraft(
        accountId: acc.id,
        amountMinor: -100,
        date: DateTime(2024, 4),
        categoryId: rent.id,
      ),
    );

    expect(await repo.undo(r.batchId), 7);
    final live = await (db.select(
      db.categories,
    )..where((x) => x.deletedAt.isNull())).get();
    expect(live.map((x) => x.name).toSet(), {'Housing', 'Rent'});
    // The account is still used by the manual transaction.
    expect(
      await (db.select(db.accounts)..where((x) => x.deletedAt.isNull())).get(),
      hasLength(1),
    );

    // History shows the undone batch.
    final history = await repo.watchHistory().first;
    expect(history.single.isUndone, isTrue);
    expect(history.single.liveCount, 0);
  });

  test(
    'previous batches are found by content hash for a renamed file',
    () async {
      final service = c.read(importServiceProvider);
      final repo = c.read(importRepositoryProvider);
      final bytes = File('test/fixtures/import/statement_en.csv')
          .readAsBytesSync();
      final wb = await service.read(ImportSource.file('march.csv', bytes));
      final cfg = initialConfig([wb]);
      final ctx = await service.loadContext([wb]);
      final prep = await service.prepare(
        await service.analyse([wb], cfg, ctx),
        cfg,
        ctx,
      );
      await service.commit(prep, workbooks: [wb], config: cfg);

      final renamed = await service.read(
        ImportSource.file('export (1).csv', bytes),
      );
      final prev = await repo.previousHashes(
        files: [
          ImportFileInfo(
            name: renamed.fileName,
            hash: renamed.fileHash,
            rows: 0,
          ),
        ],
      );
      expect(prev.values.fold<int>(0, (a, b) => a + b), 7);
      final cfg2 = initialConfig([renamed]);
      final ctx2 = await service.loadContext([renamed]);
      final a2 = await service.analyse([renamed], cfg2, ctx2);
      expect(a2.rows.every((r) => r.dup == DupStatus.alreadyImported), isTrue);
    },
  );
}
