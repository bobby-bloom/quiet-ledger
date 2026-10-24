import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:personal_finance/core/calendar/holidays.dart';
import 'package:personal_finance/core/calendar/recurrence.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/core/ledger/ledger_repository.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/features/recurring/domain/recurring_logic.dart';
import 'package:personal_finance/features/recurring/domain/schedule.dart';

final recurringRepositoryProvider = Provider<RecurringRepository>(
  (ref) => RecurringRepository(
    ref.watch(databaseProvider),
    ref.watch(syncWriterProvider),
    ref.watch(ledgerRepositoryProvider),
  ),
);

/// Editable fields of a recurring rule.
@immutable
class RecurringRuleDraft {
  const RecurringRuleDraft({
    required this.name,
    required this.rrule,
    required this.startDate,
    required this.template,
    this.endDate,
    this.count,
    this.postingMode = PostingMode.remindConfirm,
    this.remindDaysBefore = 2,
    this.notifyTime = 9 * 60,
    this.weekendShift = WeekendShift.none,
    this.active = true,
  });

  factory RecurringRuleDraft.fromRow(RecurringRule r) => RecurringRuleDraft(
    name: r.name,
    rrule: r.rrule,
    startDate: dateOnly(r.startDate),
    endDate: r.endDate == null ? null : dateOnly(r.endDate!),
    count: r.count,
    template: decodeTemplate(r.template),
    postingMode: r.postingMode,
    remindDaysBefore: r.remindDaysBefore,
    notifyTime: r.notifyTime,
    weekendShift: parseWeekendShift(r.weekendShift),
    active: r.active,
  );

  final String name;
  final String rrule;
  final DateTime startDate;
  final DateTime? endDate;
  final int? count;

  /// Template transaction; its `date` is ignored (occurrence dates apply).
  final TxnDraft template;
  final PostingMode postingMode;
  final int remindDaysBefore;
  final int notifyTime;
  final WeekendShift weekendShift;
  final bool active;

  /// Problems preventing a save (empty = valid): 'name', 'rrule', 'amount',
  /// 'endBeforeStart', 'count', plus the template's own problems.
  List<String> validate() => [
    if (name.trim().isEmpty) 'name',
    if (!isValidRRule(rrule)) 'rrule',
    if (template.amountMinor == 0) 'amount',
    if (endDate != null && endDate!.isBefore(startDate)) 'endBeforeStart',
    if (count != null && count! < 1) 'count',
    ...template.validate(),
  ];

  RecurringRulesCompanion toCompanion() => RecurringRulesCompanion(
    name: Value(name.trim()),
    rrule: Value(rrule.trim()),
    startDate: Value(dateOnly(startDate)),
    endDate: Value(endDate == null ? null : dateOnly(endDate!)),
    count: Value(count),
    template: Value(
      jsonEncode(template.copyWith(date: dateOnly(startDate)).toJson()),
    ),
    postingMode: Value(postingMode),
    remindDaysBefore: Value(remindDaysBefore),
    notifyTime: Value(notifyTime),
    weekendShift: Value(weekendShift.name),
    active: Value(active),
  );
}

/// Result of an auto-post run.
@immutable
class PostingResult {
  const PostingResult(this.posted, this.rules);

  /// Number of transactions created.
  final int posted;

  /// Ids of rules that posted at least one transaction.
  final Set<String> rules;
}

/// CRUD for recurring rules and their amount changes, plus posting of due
/// occurrences (auto-post and remind & confirm). All writes go through
/// [SyncWriter]; transactions are created with [LedgerRepository].
class RecurringRepository {
  RecurringRepository(this.db, this.writer, this.ledger);

  final AppDatabase db;
  final SyncWriter writer;
  final LedgerRepository ledger;

  // -------------------------------------------------------------- reads ---

  Stream<List<RecurringRule>> watchRules() =>
      (db.select(db.recurringRules)
            ..where((r) => r.deletedAt.isNull())
            ..orderBy([(r) => OrderingTerm(expression: r.name)]))
          .watch();

  Future<List<RecurringRule>> rules() =>
      (db.select(db.recurringRules)..where((r) => r.deletedAt.isNull())).get();

  Future<RecurringRule?> ruleById(String id) => (db.select(
    db.recurringRules,
  )..where((r) => r.id.equals(id) & r.deletedAt.isNull())).getSingleOrNull();

  /// Live amount changes grouped by rule id.
  Stream<Map<String, List<RecurringAmountChange>>> watchAmountChanges() =>
      (db.select(db.recurringAmountChanges)
            ..where((c) => c.deletedAt.isNull())
            ..orderBy([(c) => OrderingTerm(expression: c.fromDate)]))
          .watch()
          .map(_group);

  Future<Map<String, List<RecurringAmountChange>>> amountChanges() async =>
      _group(
        await (db.select(
          db.recurringAmountChanges,
        )..where((c) => c.deletedAt.isNull())).get(),
      );

  static Map<String, List<RecurringAmountChange>> _group(
    List<RecurringAmountChange> rows,
  ) {
    final out = <String, List<RecurringAmountChange>>{};
    for (final r in rows) {
      out.putIfAbsent(r.ruleId, () => []).add(r);
    }
    return out;
  }

  static Map<DateTime, int> changeMap(List<RecurringAmountChange>? rows) => {
    for (final r in rows ?? const <RecurringAmountChange>[])
      dateOnly(r.fromDate): r.amountMinor,
  };

  /// All live rules as [RecurringPlan]s.
  Future<List<RecurringPlan>> plans() async {
    final changes = await amountChanges();
    return [
      for (final r in await rules())
        RecurringPlan.fromRow(r, amountChanges: changeMap(changes[r.id])),
    ];
  }

  Future<RecurringPlan?> planById(String id) async {
    final r = await ruleById(id);
    if (r == null) return null;
    final changes = await (db.select(
      db.recurringAmountChanges,
    )..where((c) => c.ruleId.equals(id) & c.deletedAt.isNull())).get();
    return RecurringPlan.fromRow(r, amountChanges: changeMap(changes));
  }

  /// Transactions posted by rule [ruleId], newest first.
  Stream<List<Txn>> watchPosted(String ruleId, {int limit = 24}) =>
      (db.select(db.transactions)
            ..where(
              (t) =>
                  t.recurringRuleId.equals(ruleId) &
                  t.deletedAt.isNull() &
                  // Only the source leg of transfers.
                  (t.transferPeerId.isNull() |
                      t.amountMinor.isSmallerThanValue(0)),
            )
            ..orderBy([
              (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
            ])
            ..limit(limit))
          .watch();

  // ------------------------------------------------------------- writes ---

  Future<String> create(
    RecurringRuleDraft draft, {
    List<(DateTime, int)> amountChanges = const [],
  }) {
    _check(draft);
    return writer.transaction(() async {
      final id = await writer.insert(db.recurringRules, draft.toCompanion());
      for (final (from, amount) in amountChanges) {
        await addAmountChange(id, from, amount);
      }
      return id;
    });
  }

  /// Updates rule [id]. Changing the schedule does not re-post past
  /// occurrences: `lastPostedDate` is kept.
  Future<void> update(String id, RecurringRuleDraft draft) {
    _check(draft);
    return writer.update(db.recurringRules, id, draft.toCompanion());
  }

  Future<void> setActive(String id, bool active) => writer.update(
    db.recurringRules,
    id,
    RecurringRulesCompanion(active: Value(active)),
  );

  /// Soft-deletes the rule and its amount changes. Posted transactions stay.
  Future<void> delete(String id) => writer.transaction(() async {
    await writer.deleteWhere(db.recurringAmountChanges, 'rule_id', id);
    await writer.delete(db.recurringRules, id);
  });

  /// Adds (or replaces, for the same date) an amount change effective from
  /// [from]. [amountMinor] is signed like the template amount.
  Future<String> addAmountChange(
    String ruleId,
    DateTime from,
    int amountMinor,
  ) => writer.transaction(() async {
    final day = dateOnly(from);
    final existing =
        await (db.select(db.recurringAmountChanges)..where(
              (c) =>
                  c.ruleId.equals(ruleId) &
                  c.fromDate.equals(day) &
                  c.deletedAt.isNull(),
            ))
            .get();
    if (existing.isNotEmpty) {
      await writer.update(
        db.recurringAmountChanges,
        existing.first.id,
        RecurringAmountChangesCompanion(amountMinor: Value(amountMinor)),
      );
      for (final dup in existing.skip(1)) {
        await writer.delete(db.recurringAmountChanges, dup.id);
      }
      return existing.first.id;
    }
    return await writer.insert(
      db.recurringAmountChanges,
      RecurringAmountChangesCompanion(
        ruleId: Value(ruleId),
        fromDate: Value(day),
        amountMinor: Value(amountMinor),
      ),
    );
  });

  Future<void> updateAmountChange(String id, DateTime from, int amountMinor) =>
      writer.update(
        db.recurringAmountChanges,
        id,
        RecurringAmountChangesCompanion(
          fromDate: Value(dateOnly(from)),
          amountMinor: Value(amountMinor),
        ),
      );

  Future<void> deleteAmountChange(String id) =>
      writer.delete(db.recurringAmountChanges, id);

  void _check(RecurringRuleDraft draft) {
    final problems = draft.validate();
    if (problems.isNotEmpty) {
      throw ArgumentError('Invalid recurring rule: ${problems.join(', ')}');
    }
  }

  // ------------------------------------------------------------ posting ---

  /// Posts every due occurrence (date ≤ [today]) of active auto-post rules
  /// exactly once and advances `lastPostedDate`. Idempotent: running it
  /// twice posts nothing the second time.
  Future<PostingResult> postDue({
    required DateTime today,
    required HolidayCalendar calendar,
  }) async {
    var posted = 0;
    final touched = <String>{};
    for (final plan in await plans()) {
      if (!plan.active || plan.mode != PostingMode.autoPost) continue;
      if (plan.template.validate().isNotEmpty) continue;
      final due = plan.pending(dateOnly(today), calendar);
      if (due.isEmpty) continue;
      await writer.transaction(() async {
        // Re-read inside the transaction so concurrent runs cannot post the
        // same occurrence twice.
        final fresh = await planById(plan.id);
        if (fresh == null) return;
        final occurrences = fresh.pending(dateOnly(today), calendar);
        for (final o in occurrences) {
          if (await _alreadyPosted(fresh.id, o.date)) continue;
          await ledger.create(fresh.draftFor(o));
          posted++;
          touched.add(fresh.id);
        }
        if (occurrences.isNotEmpty) {
          await _markPosted(fresh.id, occurrences.last.date);
        }
      });
    }
    return PostingResult(posted, touched);
  }

  /// Posts occurrence [o] of [plan] (remind & confirm), optionally with an
  /// edited signed [amountMinor] and booking [date]. Returns the
  /// transaction id.
  Future<String> confirm(
    RecurringPlan plan,
    Occurrence o, {
    int? amountMinor,
    DateTime? date,
  }) => writer.transaction(() async {
    final id = await ledger.create(
      plan.draftFor(o, amountMinor: amountMinor, date: date),
    );
    await _markPosted(plan.id, o.date);
    return id;
  });

  /// Skips occurrence [o] without posting.
  Future<void> skip(RecurringPlan plan, Occurrence o) =>
      _markPosted(plan.id, o.date);

  Future<void> _markPosted(String ruleId, DateTime date) async {
    final rule = await ruleById(ruleId);
    if (rule == null) return;
    final last = rule.lastPostedDate;
    if (last != null && !dateOnly(date).isAfter(dateOnly(last))) return;
    await writer.update(
      db.recurringRules,
      ruleId,
      RecurringRulesCompanion(lastPostedDate: Value(dateOnly(date))),
    );
  }

  Future<bool> _alreadyPosted(String ruleId, DateTime date) async {
    final row =
        await (db.select(db.transactions)
              ..where(
                (t) =>
                    t.recurringRuleId.equals(ruleId) &
                    t.date.equals(dateOnly(date)) &
                    t.deletedAt.isNull(),
              )
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }
}
