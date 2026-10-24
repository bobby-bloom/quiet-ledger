import 'package:go_router/go_router.dart';
import 'package:personal_finance/features/accounts/presentation/account_detail_screen.dart';
import 'package:personal_finance/features/accounts/presentation/account_form_screen.dart';
import 'package:personal_finance/features/accounts/presentation/account_groups_screen.dart';
import 'package:personal_finance/features/accounts/presentation/accounts_screen.dart';
import 'package:personal_finance/features/accounts/presentation/reconcile_screen.dart';

/// Routes of the accounts feature:
/// * `/accounts` list (list-detail on expanded windows)
/// * `/accounts/new`, `/accounts/:id/edit` form
/// * `/accounts/groups` account groups
/// * `/accounts/:id` detail, `/accounts/:id/reconcile` reconciliation
final accountsRoutes = <RouteBase>[
  GoRoute(
    path: '/accounts',
    builder: (context, state) => const AccountsScreen(),
    routes: [
      GoRoute(
        path: 'new',
        builder: (context, state) => const AccountFormScreen(),
      ),
      GoRoute(
        path: 'groups',
        builder: (context, state) => const AccountGroupsScreen(),
      ),
      GoRoute(
        path: ':id',
        builder: (context, state) =>
            AccountDetailScreen(accountId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (context, state) =>
                AccountFormScreen(accountId: state.pathParameters['id']),
          ),
          GoRoute(
            path: 'reconcile',
            builder: (context, state) =>
                ReconcileScreen(accountId: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
  ),
];
