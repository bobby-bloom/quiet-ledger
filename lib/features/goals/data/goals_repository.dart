import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/db/sync_writer.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/features/goals/domain/goal_math.dart';

final goalsRepositoryProvider = Provider<GoalsRepository>(
  (ref) => GoalsRepository(
    ref.watch(databaseProvider),
    ref.watch(syncWriterProvider),
  ),
);

/// Editable fields of a goal.
@immutable
class GoalDraft {
  const GoalDraft({
    required this.name,
    required this.targetMinor,
    this.targetDate,
    this.accountId,
    this.savedMinor = 0,
    this.contributionMinor,
    this.color,
    this.icon,
  });

  factory GoalDraft.fromRow(Goal g) => GoalDraft(
    name: g.name,
    targetMinor: g.targetMinor,
    targetDate: g.targetDate,
    accountId: g.accountId,
    savedMinor: g.savedMinor,
    contributionMinor: g.contributionMinor,
    color: g.color,
    icon: g.icon,
  );

  final String name;
  final int targetMinor;
  final DateTime? targetDate;

  /// Linked account: progress = its balance (then [savedMinor] is unused).
  final String? accountId;
  final int savedMinor;

  /// Planned contribution per budget period.
  final int? contributionMinor;
  final int? color;
  final String? icon;

  /// 'name', 'target', 'contribution', 'saved' when invalid.
  List<String> validate() => [
    if (name.trim().isEmpty) 'name',
    if (targetMinor <= 0) 'target',
    if (contributionMinor != null && contributionMinor! < 0) 'contribution',
    if (savedMinor < 0) 'saved',
  ];

  GoalsCompanion toCompanion() => GoalsCompanion(
    name: Value(name.trim()),
    targetMinor: Value(targetMinor),
    targetDate: Value(targetDate == null ? null : dateOnly(targetDate!)),
    accountId: Value(accountId),
    savedMinor: Value(savedMinor),
    contributionMinor: Value(
      contributionMinor == null || contributionMinor == 0
          ? null
          : contributionMinor,
    ),
    color: Value(color),
    icon: Value(icon),
  );
}

/// Savings goals. Writes go through [SyncWriter].
class GoalsRepository {
  GoalsRepository(this.db, this.writer);

  final AppDatabase db;
  final SyncWriter writer;

  /// All live goals (archived included), by priority.
  Stream<List<Goal>> watchGoals() =>
      (db.select(db.goals)
            ..where((g) => g.deletedAt.isNull())
            ..orderBy([
              (g) => OrderingTerm(expression: g.priority),
              (g) => OrderingTerm(expression: g.name),
            ]))
          .watch();

  Future<Goal?> goalById(String id) => (db.select(
    db.goals,
  )..where((g) => g.id.equals(id) & g.deletedAt.isNull())).getSingleOrNull();

  Future<String> create(GoalDraft draft) async {
    _check(draft);
    return await writer.transaction(() async {
      final max = db.goals.priority.max();
      final row =
          await (db.selectOnly(db.goals)
                ..addColumns([max])
                ..where(db.goals.deletedAt.isNull()))
              .getSingle();
      final priority = (row.read(max) ?? -1) + 1;
      return await writer.insert(
        db.goals,
        draft.toCompanion().copyWith(priority: Value(priority)),
      );
    });
  }

  Future<void> update(String id, GoalDraft draft) {
    _check(draft);
    return writer.update(db.goals, id, draft.toCompanion());
  }

  Future<void> delete(String id) => writer.delete(db.goals, id);

  Future<void> setArchived(String id, bool archived) =>
      writer.update(db.goals, id, GoalsCompanion(archived: Value(archived)));

  /// Adds [amountMinor] (negative = withdrawal) to a manual goal's saved
  /// amount; never goes below zero.
  Future<void> addContribution(String id, int amountMinor) =>
      writer.transaction(() async {
        final g = await goalById(id);
        if (g == null) return;
        final next = g.savedMinor + amountMinor;
        await writer.update(
          db.goals,
          id,
          GoalsCompanion(savedMinor: Value(next < 0 ? 0 : next)),
        );
      });

  /// Stores the order of [ids] as priorities 0..n-1.
  Future<void> reorder(List<String> ids) => writer.transaction(() async {
    final current = {
      for (final g in await (db.select(
        db.goals,
      )..where((g) => g.deletedAt.isNull())).get())
        g.id: g.priority,
    };
    for (var i = 0; i < ids.length; i++) {
      if (current[ids[i]] == i) continue;
      if (!current.containsKey(ids[i])) continue;
      await writer.update(db.goals, ids[i], GoalsCompanion(priority: Value(i)));
    }
  });

  /// Net change of [accountId] over the last [months] months (at most) up to
  /// [today], as a pace. Null when the account has less than [minDays] of
  /// history in the window.
  Future<GoalPace?> accountPace(
    String accountId,
    DateTime today, {
    int months = 6,
    int minDays = 90,
  }) async {
    final t = dateOnly(today);
    final windowStart = DateTime(t.year, t.month - months, t.day);
    final account =
        await (db.select(db.accounts)
              ..where((a) => a.id.equals(accountId) & a.deletedAt.isNull()))
            .getSingleOrNull();
    if (account == null) return null;
    final first = await db
        .customSelect(
          'SELECT MIN(date) AS d FROM transactions '
          'WHERE account_id = ? AND deleted_at IS NULL',
          variables: [Variable<String>(accountId)],
          readsFrom: {db.transactions},
        )
        .getSingle();
    final firstTxn = first.readNullable<DateTime>('d');
    var historyStart = dateOnly(account.openingDate);
    if (firstTxn != null && firstTxn.isBefore(historyStart)) {
      historyStart = dateOnly(firstTxn);
    }
    final from = historyStart.isAfter(windowStart) ? historyStart : windowStart;
    final days = DateTime.utc(
      t.year,
      t.month,
      t.day,
    ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
    if (days < minDays) return null;
    final row = await db
        .customSelect(
          'SELECT COALESCE(SUM(amount_minor), 0) AS s FROM transactions '
          'WHERE account_id = ? AND deleted_at IS NULL AND status <> ? '
          'AND date > ? AND date <= ?',
          variables: [
            Variable<String>(accountId),
            const Variable<String>('planned'),
            Variable<DateTime>(from),
            Variable<DateTime>(t),
          ],
          readsFrom: {db.transactions},
        )
        .getSingle();
    return GoalPace.perDays(row.read<int>('s'), days);
  }

  void _check(GoalDraft draft) {
    final problems = draft.validate();
    if (problems.isNotEmpty) {
      throw ArgumentError('Invalid goal: ${problems.join(', ')}');
    }
  }
}
