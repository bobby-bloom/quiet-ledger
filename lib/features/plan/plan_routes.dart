import 'package:go_router/go_router.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/features/budgets/presentation/budget_detail_screen.dart';
import 'package:personal_finance/features/goals/presentation/goal_editor_screen.dart';
import 'package:personal_finance/features/plan/presentation/plan_screen.dart';
import 'package:personal_finance/features/plan/presentation/plan_widgets.dart';
import 'package:personal_finance/features/recurring/presentation/bills_calendar_screen.dart';
import 'package:personal_finance/features/recurring/presentation/rule_editor_screen.dart';
import 'package:personal_finance/features/recurring/presentation/rule_picker.dart';

/// Routes of the Plan feature (budgets, recurring, goals, bills calendar).
///
/// * `/plan?tab=budgets|recurring|goals`
/// * `/plan/budgets/:categoryId?period=yyyy-MM-dd`
/// * `/plan/recurring/new?type=expense|income|transfer`, `/plan/recurring/:id`
/// * `/plan/recurring/pick` (salary rule for Settings › Budgets)
/// * `/plan/calendar`
/// * `/plan/goals/new`, `/plan/goals/:id`
final planRoutes = <RouteBase>[
  GoRoute(
    path: '/plan',
    builder: (context, state) =>
        PlanScreen(initialTab: state.uri.queryParameters['tab']),
    routes: [
      GoRoute(
        path: 'budgets/:categoryId',
        builder: (context, state) => BudgetDetailScreen(
          categoryId: state.pathParameters['categoryId']!,
          periodStart: parseIsoDate(state.uri.queryParameters['period']),
        ),
      ),
      GoRoute(
        path: 'recurring/new',
        builder: (context, state) => RuleEditorScreen(
          initialType: TxnType.values
              .asNameMap()[state.uri.queryParameters['type']],
        ),
      ),
      GoRoute(
        path: 'recurring/pick',
        builder: (context, state) => const SalaryRulePickScreen(),
      ),
      GoRoute(
        path: 'recurring/:id',
        builder: (context, state) =>
            RuleEditorScreen(ruleId: state.pathParameters['id']),
      ),
      GoRoute(
        path: 'calendar',
        builder: (context, state) => const BillsCalendarScreen(),
      ),
      GoRoute(
        path: 'goals/new',
        builder: (context, state) => const GoalEditorScreen(),
      ),
      GoRoute(
        path: 'goals/:id',
        builder: (context, state) =>
            GoalEditorScreen(goalId: state.pathParameters['id']),
      ),
    ],
  ),
];
