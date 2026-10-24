import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/features/scenarios/domain/scenario.dart';

final scenarioRepositoryProvider = Provider<ScenarioRepository>(
  (ref) => ScenarioRepository(
    ref.watch(databaseProvider),
    ref.watch(syncWriterProvider),
  ),
);

/// All live scenarios, oldest first.
final scenariosProvider = StreamProvider<List<ScenarioDef>>(
  (ref) => ref.watch(scenarioRepositoryProvider).watchAll(),
);

/// A recurring rule offered in the scenario editor.
@immutable
class RuleOption {
  const RuleOption(this.id, this.name, this.amountMinor);

  final String id;
  final String name;

  /// Template amount (signed), 0 when the template cannot be read.
  final int amountMinor;
}

/// Active recurring rules (read directly from the table; the recurring
/// feature owns writing them).
final recurringRuleOptionsProvider = StreamProvider<List<RuleOption>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.recurringRules)
        ..where((r) => r.deletedAt.isNull() & r.active.equals(true))
        ..orderBy([(r) => OrderingTerm(expression: r.name)]))
      .watch()
      .map(
        (rows) => [
          for (final r in rows) RuleOption(r.id, r.name, _templateAmount(r)),
        ],
      );
});

int _templateAmount(RecurringRule r) {
  try {
    final j = jsonDecode(r.template);
    if (j is Map && j['amountMinor'] is num) {
      return (j['amountMinor'] as num).toInt();
    }
  } on FormatException {
    // Unreadable template.
  }
  return 0;
}

/// CRUD for scenarios. Writes go through [SyncWriter]; adjustments are
/// stored as a JSON list in `scenarios.adjustments`.
class ScenarioRepository {
  ScenarioRepository(this.db, this.writer);

  final AppDatabase db;
  final SyncWriter writer;

  static ScenarioDef fromRow(Scenario row) => ScenarioDef(
    id: row.id,
    name: row.name,
    color: row.color,
    enabled: row.enabled,
    adjustments: ScenarioAdjustment.decodeList(row.adjustments),
  );

  SimpleSelectStatement<$ScenariosTable, Scenario> _live() =>
      db.select(db.scenarios)
        ..where((s) => s.deletedAt.isNull())
        ..orderBy([
          (s) => OrderingTerm(expression: s.createdAt),
          (s) => OrderingTerm(expression: s.id),
        ]);

  Stream<List<ScenarioDef>> watchAll() =>
      _live().watch().map((rows) => rows.map(fromRow).toList());

  Future<List<ScenarioDef>> all() async =>
      (await _live().get()).map(fromRow).toList();

  Future<ScenarioDef?> byId(String id) async {
    final row = await (db.select(
      db.scenarios,
    )..where((s) => s.id.equals(id) & s.deletedAt.isNull())).getSingleOrNull();
    return row == null ? null : fromRow(row);
  }

  ScenariosCompanion _companion(ScenarioDef s) => ScenariosCompanion(
    name: Value(s.name.trim()),
    color: Value(s.color),
    enabled: Value(s.enabled),
    adjustments: Value(ScenarioAdjustment.encodeList(s.adjustments)),
  );

  /// Creates [scenario] (its id is ignored) and returns the new id.
  Future<String> create(ScenarioDef scenario) {
    if (scenario.name.trim().isEmpty) {
      throw ArgumentError.value(scenario.name, 'name', 'must not be empty');
    }
    return writer.insert(db.scenarios, _companion(scenario));
  }

  Future<void> save(ScenarioDef scenario) {
    if (scenario.name.trim().isEmpty) {
      throw ArgumentError.value(scenario.name, 'name', 'must not be empty');
    }
    return writer.update(db.scenarios, scenario.id, _companion(scenario));
  }

  /// Turns the comparison on or off. Enabling fails (returns false) when
  /// [maxComparedScenarios] are already enabled.
  Future<bool> setEnabled(String id, {required bool enabled}) async {
    if (enabled) {
      final others = (await all()).where((s) => s.enabled && s.id != id);
      if (others.length >= maxComparedScenarios) return false;
    }
    await writer.update(
      db.scenarios,
      id,
      ScenariosCompanion(enabled: Value(enabled)),
    );
    return true;
  }

  /// Copies scenario [id] under [name] (not compared). Returns the new id.
  Future<String?> duplicate(String id, {required String name}) async {
    final s = await byId(id);
    if (s == null) return null;
    return await create(s.copyWith(name: name, enabled: false));
  }

  Future<void> delete(String id) => writer.delete(db.scenarios, id);
}
