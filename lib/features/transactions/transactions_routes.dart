import 'package:go_router/go_router.dart';
import 'package:personal_finance/features/transactions/domain/txn_filter.dart';
import 'package:personal_finance/features/transactions/presentation/saved_filters_screen.dart';
import 'package:personal_finance/features/transactions/presentation/transaction_detail.dart';
import 'package:personal_finance/features/transactions/presentation/transactions_screen.dart';

/// Routes of the transactions feature (Transactions branch):
///
/// * `/transactions` — the list. Deep-link query parameters set the filter
///   (see [TxnFilter.fromQuery]): `account`, `category`, `tag` (ids,
///   comma-separated), `payee`, `from`/`to` (`YYYY-MM-DD`, inclusive),
///   `type` (`expense|income|transfer`), `status`
///   (`cleared|pending|planned`), `q` (search). Example:
///   `/transactions?account=abc&from=2026-10-01&to=2026-10-31`.
/// * `/transactions/filters` — saved filters ("smart lists"), also the
///   editor of Settings › Transactions › Default filter.
/// * `/transactions/:id` — full-screen detail (compact layouts).
final transactionsRoutes = <RouteBase>[
  GoRoute(
    path: '/transactions',
    builder: (context, state) {
      final q = state.uri.queryParameters;
      return TransactionsScreen(
        deepLink: q.isEmpty ? null : TxnFilter.fromQuery(q),
      );
    },
    routes: [
      GoRoute(
        path: 'filters',
        builder: (context, state) => const SavedFiltersScreen(),
      ),
      GoRoute(
        path: ':id',
        builder: (context, state) =>
            TransactionDetailScreen(id: state.pathParameters['id']!),
      ),
    ],
  ),
];
