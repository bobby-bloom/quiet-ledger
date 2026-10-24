import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/features/rules/domain/rule_engine.dart';
import 'package:personal_finance/features/rules/domain/rule_model.dart';

final ruleRepositoryProvider = Provider<RuleRepository>(
  (ref) => RuleRepository(
    ref.watch(databaseProvider),
    ref.watch(syncWriterProvider),
  ),
);

/// All live rules in priority order.
final rulesProvider = StreamProvider<List<RuleDef>>(
  (ref) => ref.watch(ruleRepositoryProvider).watchAll(),
);

/// Reads and writes `rules` rows. Every write goes through [SyncWriter].
class RuleRepository {
  RuleRepository(this.db, this.writer);

  final AppDatabase db;
  final SyncWriter writer;

  static RuleDef fromRow(Rule r) {
    RuleConditions conditions;
    RuleActions actions;
    try {
      conditions = RuleConditions.decode(r.conditions);
    } on FormatException {
      conditions = const RuleConditions();
    }
    try {
      actions = RuleActions.decode(r.actions);
    } on FormatException {
      actions = const RuleActions();
    }
    return RuleDef(
      id: r.id,
      name: r.name,
      priority: r.priority,
      conditions: conditions,
      actions: actions,
      applyOnEntry: r.applyOnEntry,
      applyOnImport: r.applyOnImport,
      enabled: r.enabled,
    );
  }

  SimpleSelectStatement<$RulesTable, Rule> _live() =>
      db.select(db.rules)..where((r) => r.deletedAt.isNull());

  Stream<List<RuleDef>> watchAll() => _live().watch().map(
    (rows) => [for (final r in rows) fromRow(r)]..sort(RuleEngine.compareRules),
  );

  Future<List<RuleDef>> all() async =>
      [for (final r in await _live().get()) fromRow(r)]
        ..sort(RuleEngine.compareRules);

  Future<RuleDef?> byId(String id) async {
    final row = await (_live()..where((r) => r.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : fromRow(row);
  }

  /// Inserts [rule] (when its id is null, at the end of the list) or updates
  /// it. Returns the id.
  Future<String> save(RuleDef rule) => writer.transaction(() async {
    if (rule.id == null) {
      final existing = await all();
      final priority = existing.isEmpty
          ? 0
          : existing.map((r) => r.priority).reduce((a, b) => a > b ? a : b) + 1;
      return await writer.insert(
        db.rules,
        _companion(rule.copyWith(priority: priority)),
      );
    }
    await writer.update(db.rules, rule.id!, _companion(rule));
    return rule.id!;
  });

  Future<void> delete(String id) => writer.delete(db.rules, id);

  Future<void> setEnabled(String id, {required bool enabled}) =>
      writer.update(db.rules, id, RulesCompanion(enabled: Value(enabled)));

  /// Persists the list order: the rule at index i gets priority i. Only rows
  /// whose priority changes are written.
  Future<void> reorder(List<String> idsInOrder) => writer.transaction(() async {
    final byId = {for (final r in await all()) r.id: r};
    for (var i = 0; i < idsInOrder.length; i++) {
      final r = byId[idsInOrder[i]];
      if (r == null || r.priority == i) continue;
      await writer.update(db.rules, r.id!, RulesCompanion(priority: Value(i)));
    }
  });

  RulesCompanion _companion(RuleDef r) => RulesCompanion(
    name: Value(r.name.trim()),
    priority: Value(r.priority),
    conditions: Value(r.conditions.encode()),
    actions: Value(r.actions.encode()),
    applyOnEntry: Value(r.applyOnEntry),
    applyOnImport: Value(r.applyOnImport),
    enabled: Value(r.enabled),
  );
}
