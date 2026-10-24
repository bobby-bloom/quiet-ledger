import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/features/forecast/presentation/forecast_providers.dart';
import 'package:personal_finance/features/scenarios/data/scenario_repository.dart';
import 'package:personal_finance/features/scenarios/domain/scenario.dart';
import 'package:personal_finance/features/scenarios/presentation/scenario_editor_screen.dart';

import '../../helpers/test_app.dart';

void main() {
  late AppDatabase db;
  late ScenarioRepository repo;

  setUp(() {
    db = newTestDb();
    repo = ScenarioRepository(db, SyncWriter(db, testClock(), 'dev-1'));
  });

  tearDown(() => db.close());

  group('ScenarioRepository', () {
    test('create, read, save, delete with JSON adjustments', () async {
      final id = await repo.create(
        ScenarioDef(
          id: '',
          name: '  Raise ',
          color: 0xFF4F79C2,
          adjustments: [
            RecurringChangeAdjustment(
              ruleId: 'salary',
              from: DateTime(2027),
              mode: ChangeMode.percent,
              value: 500,
            ),
          ],
        ),
      );
      final s = (await repo.byId(id))!;
      expect(s.name, 'Raise');
      expect(s.color, 0xFF4F79C2);
      expect(s.enabled, isFalse);
      expect(s.adjustments.single, isA<RecurringChangeAdjustment>());
      final row = await (db.select(
        db.scenarios,
      )..where((t) => t.id.equals(id))).getSingle();
      expect(row.adjustments, contains('"type":"recurringChange"'));

      await repo.save(
        s.copyWith(
          name: 'Raise 5 %',
          adjustments: [const InflationAdjustment(inflationBp: 300)],
        ),
      );
      expect((await repo.byId(id))!.adjustments, [
        const InflationAdjustment(inflationBp: 300),
      ]);

      await repo.delete(id);
      expect(await repo.byId(id), isNull);
      expect(await repo.all(), isEmpty);
      // Every write is in the change log.
      final log = await (db.select(
        db.changeLog,
      )..where((c) => c.entityId.equals(id))).get();
      expect(log.map((e) => e.op), [
        ChangeOp.insert,
        ChangeOp.update,
        ChangeOp.delete,
      ]);
    });

    test('empty names are rejected', () {
      expect(
        () => repo.create(const ScenarioDef(id: '', name: ' ')),
        throwsArgumentError,
      );
    });

    test('at most five scenarios are compared', () async {
      final ids = [
        for (var i = 0; i < 6; i++)
          await repo.create(ScenarioDef(id: '', name: 's$i')),
      ];
      for (final id in ids.take(5)) {
        expect(await repo.setEnabled(id, enabled: true), isTrue);
      }
      expect(await repo.setEnabled(ids[5], enabled: true), isFalse);
      expect(await repo.setEnabled(ids[0], enabled: true), isTrue);
      expect(await repo.setEnabled(ids[0], enabled: false), isTrue);
      expect(await repo.setEnabled(ids[5], enabled: true), isTrue);
      final enabled = [
        for (final s in await repo.all())
          if (s.enabled) s.name,
      ];
      expect(enabled, ['s1', 's2', 's3', 's4', 's5']);
    });

    test('duplicate copies adjustments and is not compared', () async {
      final id = await repo.create(
        ScenarioDef(
          id: '',
          name: 'Laptop',
          enabled: true,
          adjustments: [
            OneOffAdjustment(
              date: DateTime(2027, 2),
              amountMinor: -140000,
              accountId: 'a',
              label: 'Laptop',
            ),
          ],
        ),
      );
      final copy = (await repo.byId(
        (await repo.duplicate(id, name: 'Laptop (copy)'))!,
      ))!;
      expect(copy.name, 'Laptop (copy)');
      expect(copy.enabled, isFalse);
      expect(copy.adjustments, (await repo.byId(id))!.adjustments);
      expect(await repo.duplicate('missing', name: 'x'), isNull);
    });

    test('watchAll emits live scenarios oldest first', () async {
      await repo.create(const ScenarioDef(id: '', name: 'a'));
      await repo.create(const ScenarioDef(id: '', name: 'b'));
      final list = await repo.watchAll().first;
      expect(list.map((s) => s.name), ['a', 'b']);
    });
  });

  testWidgets('editor: add an inflation change and save', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(
        const ScenarioEditorScreen(scenarioId: 'new'),
        db: db,
        overrides: [
          forecastRunnerProvider.overrideWithValue(
            const ForecastRunner.inline(),
          ),
          forecastTodayProvider.overrideWithValue(DateTime(2026, 10, 23)),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'High inflation');
    await tester.tap(find.text('Add change'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Different inflation'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, '4,5');
    await tester.tap(find.text('Done'));
    // The live preview keeps a progress indicator running: pump manually.
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('Inflation 4.5 %'), findsOneWidget);

    await tester.tap(find.text('Save'));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 100));
    }
    final saved = await tester.runAsync(repo.all);
    expect(saved!.single.name, 'High inflation');
    expect(saved.single.adjustments, [
      const InflationAdjustment(inflationBp: 450),
    ]);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
