import 'package:drift/drift.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/sync_writer.dart';

/// Re-points JSON references from [oldId] to [newId] in the JSON columns
/// that may hold category/tag ids: recurring rule templates, transaction
/// templates, rule conditions/actions, budget templates and saved filters.
///
/// Ids are UUIDs, so replacing the quoted id string is unambiguous.
Future<void> repointJsonReferences(
  AppDatabase db,
  SyncWriter writer,
  String oldId,
  String newId,
) => writer.transaction(() async {
  final quoted = '"$oldId"';
  final replacement = '"$newId"';
  String fix(String s) => s.replaceAll(quoted, replacement);

  for (final r in await (db.select(
    db.recurringRules,
  )..where((t) => t.deletedAt.isNull() & t.template.contains(oldId))).get()) {
    await writer.update(
      db.recurringRules,
      r.id,
      RecurringRulesCompanion(template: Value(fix(r.template))),
    );
  }
  for (final r in await (db.select(
    db.transactionTemplates,
  )..where((t) => t.deletedAt.isNull() & t.fields.contains(oldId))).get()) {
    await writer.update(
      db.transactionTemplates,
      r.id,
      TransactionTemplatesCompanion(fields: Value(fix(r.fields))),
    );
  }
  for (final r
      in await (db.select(db.rules)..where(
            (t) =>
                t.deletedAt.isNull() &
                (t.conditions.contains(oldId) | t.actions.contains(oldId)),
          ))
          .get()) {
    await writer.update(
      db.rules,
      r.id,
      RulesCompanion(
        conditions: Value(fix(r.conditions)),
        actions: Value(fix(r.actions)),
      ),
    );
  }
  for (final r in await (db.select(
    db.budgetTemplates,
  )..where((t) => t.deletedAt.isNull() & t.items.contains(oldId))).get()) {
    await writer.update(
      db.budgetTemplates,
      r.id,
      BudgetTemplatesCompanion(items: Value(fix(r.items))),
    );
  }
  for (final r in await (db.select(
    db.savedFilters,
  )..where((t) => t.deletedAt.isNull() & t.filter.contains(oldId))).get()) {
    await writer.update(
      db.savedFilters,
      r.id,
      SavedFiltersCompanion(filter: Value(fix(r.filter))),
    );
  }
});
