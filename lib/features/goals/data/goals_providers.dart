import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/lookups.dart';
import 'package:personal_finance/features/budgets/data/budget_period_provider.dart';
import 'package:personal_finance/features/goals/data/goals_repository.dart';
import 'package:personal_finance/features/goals/domain/goal_math.dart';
import 'package:personal_finance/features/plan/plan_providers.dart';

/// All live goals (archived included), by priority.
final goalsProvider = StreamProvider<List<Goal>>(
  (ref) => ref.watch(goalsRepositoryProvider).watchGoals(),
);

/// Where a goal's projected date comes from.
enum GoalPaceSource { account, contribution, none }

/// A goal with its current progress and projection. Exposed for the
/// dashboard "Goal progress" card through [goalsProgressProvider].
@immutable
class GoalProgress {
  const GoalProgress({
    required this.goal,
    required this.projection,
    required this.paceSource,
    this.account,
  });

  final Goal goal;
  final Account? account;
  final GoalProjection projection;
  final GoalPaceSource paceSource;

  String get id => goal.id;
  String get name => goal.name;
  int get savedMinor => projection.savedMinor;
  int get targetMinor => projection.targetMinor;
  double get fraction => projection.fraction;
}

/// Account pace (last 3–6 months of net change) per account id.
final accountPaceProvider = FutureProvider.family<GoalPace?, String>((
  ref,
  accountId,
) {
  // Recompute when balances change.
  ref.watch(accountBalancesProvider);
  final today = ref.watch(planTodayProvider);
  return ref.watch(goalsRepositoryProvider).accountPace(accountId, today);
});

Future<GoalProgress> _progress(Ref ref, Goal g) async {
  final periods = ref.watch(budgetPeriodsProvider);
  final today = ref.watch(planTodayProvider);
  final accounts = ref.watch(accountMapProvider);
  final balances = ref.watch(accountBalancesProvider).value ?? const {};
  final account = g.accountId == null ? null : accounts[g.accountId];
  final saved = account == null
      ? g.savedMinor
      : (balances[account.id] ?? account.openingBalanceMinor);
  GoalPace? pace;
  var source = GoalPaceSource.none;
  if (account != null) {
    pace = await ref.watch(accountPaceProvider(account.id).future);
    if (pace != null && pace.isPositive) source = GoalPaceSource.account;
  }
  if (source == GoalPaceSource.none &&
      g.contributionMinor != null &&
      g.contributionMinor! > 0) {
    pace = GoalPace.perPeriod(g.contributionMinor!);
    source = GoalPaceSource.contribution;
  }
  return GoalProgress(
    goal: g,
    account: account,
    paceSource: source,
    projection: projectGoal(
      savedMinor: saved,
      targetMinor: g.targetMinor,
      today: today,
      periods: periods,
      targetDate: g.targetDate,
      pace: source == GoalPaceSource.none ? null : pace,
    ),
  );
}

/// Progress of all goals (archived included), by priority.
final allGoalsProgressProvider = FutureProvider<List<GoalProgress>>((
  ref,
) async {
  final goals = await ref.watch(goalsProvider.future);
  return [for (final g in goals) await _progress(ref, g)];
});

/// Progress of active (not archived) goals, by priority.
final goalsProgressProvider = FutureProvider<List<GoalProgress>>((ref) async {
  final all = await ref.watch(allGoalsProgressProvider.future);
  return [
    for (final p in all)
      if (!p.goal.archived) p,
  ];
});
