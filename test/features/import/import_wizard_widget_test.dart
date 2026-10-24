import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/features/import/data/import_repository.dart';
import 'package:personal_finance/features/import/data/import_service.dart';
import 'package:personal_finance/features/import/data/profile_repository.dart';
import 'package:personal_finance/features/import/domain/raw_sheet.dart';
import 'package:personal_finance/features/import/presentation/import_history_screen.dart';
import 'package:personal_finance/features/import/presentation/import_wizard_controller.dart';
import 'package:personal_finance/features/import/presentation/import_wizard_screen.dart';
import 'package:personal_finance/features/rules/domain/rule_service.dart';

import '../../helpers/test_app.dart';
import 'widget_test_utils.dart';

const dir = 'test/fixtures/import';

final inlineService = importServiceProvider.overrideWith(
  (ref) => InlineImportService(
    ref.watch(importRepositoryProvider),
    ref.watch(importProfileRepositoryProvider),
    ref.watch(ruleServiceProvider),
  ),
);

void main() {
  for (final (label, size) in [
    ('phone', const Size(390, 844)),
    ('desktop', const Size(1400, 900)),
  ]) {
    testWidgets('wizard: every step renders and the import commits ($label)', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final db = (await tester.runAsync(() async => newTestDb()))!;
      await tester.pumpWidget(
        testApp(const ImportWizardScreen(), db: db, overrides: [inlineService]),
      );
      await settle(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ImportWizardScreen)),
      );
      final c = container.read(importWizardProvider.notifier);
      expect(find.text('Choose files'), findsOneWidget);

      final names = ['haushaltsbuch.xlsx', 'sparkonto_sh.xlsx', 'kalender.ods'];
      final files = [
        for (final n in names) (n, File('$dir/$n').readAsBytesSync()),
      ];
      await drive(tester, c.addFiles(files));
      expect(find.text('haushaltsbuch.xlsx'), findsOneWidget);
      expect(
        container.read(importWizardProvider).sources.last.error?.error,
        ImportReadError.ods,
      );

      // Name the log's account.
      final s = container.read(importWizardProvider);
      for (final sh in s.config.sheets.where(
        (x) => x.fileName == 'haushaltsbuch.xlsx',
      )) {
        c.updateSheet(sh.copyWith(fixedAccount: 'Girokonto'));
      }

      for (final step in ImportStep.values.skip(1)) {
        await drive(tester, c.next());
        expect(container.read(importWizardProvider).step, step);
        expect(tester.takeException(), isNull, reason: step.name);
        switch (step) {
          case ImportStep.mapping:
            expect(find.textContaining('Balance check'), findsOneWidget);
            if (label == 'desktop') {
              expect(find.text('Out + In'), findsOneWidget);
            }
          case ImportStep.transfers:
            expect(
              find.textContaining('19 of 19 pairs merged'),
              findsOneWidget,
            );
          case ImportStep.summary:
            expect(find.text('Import 167 transactions'), findsOneWidget);
            expect(find.text('Ready to import'), findsOneWidget);
          case ImportStep.source:
          case ImportStep.sheets:
          case ImportStep.structure:
          case ImportStep.formats:
          case ImportStep.categories:
          case ImportStep.duplicates:
            break;
        }
      }

      final result = await drive(tester, c.commit());
      expect(result, isNotNull);
      expect(find.text('Import complete'), findsWidgets);
      final batches = await drive(tester, db.select(db.importBatches).get());
      expect(batches.single.rowCount, 167);

      await drive(tester, c.undoCommitted());
      final live = await drive(
        tester,
        (db.select(db.transactions)..where((t) => t.deletedAt.isNull())).get(),
      );
      expect(live, isEmpty);
      await disposeDb(tester, db);
    });
  }

  testWidgets('history lists batches and profiles', (tester) async {
    final db = (await tester.runAsync(() async => newTestDb()))!;
    await tester.pumpWidget(testApp(const ImportHistoryScreen(), db: db));
    await settle(tester);
    expect(find.text('No imports yet.'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ImportHistoryScreen)),
    );
    await drive(
      tester,
      container
          .read(syncWriterProvider)
          .insert(
            db.importBatches,
            ImportBatchesCompanion(
              fileName: const Value('umsaetze.csv'),
              fileHash: const Value('h'),
              importedAt: Value(DateTime(2024, 5, 3)),
              rowCount: const Value(12),
            ),
          ),
    );
    expect(find.text('umsaetze.csv'), findsOneWidget);
    expect(find.text('Undo import'), findsOneWidget);
    await tester.tap(find.text('Profiles'));
    await settle(tester);
    expect(find.textContaining('No profiles yet'), findsOneWidget);
    await disposeDb(tester, db);
  });
}
