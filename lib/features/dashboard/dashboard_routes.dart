import 'package:go_router/go_router.dart';
import 'package:personal_finance/features/dashboard/presentation/dashboard_screen.dart';

final dashboardRoutes = <RouteBase>[
  GoRoute(path: '/home', builder: (context, state) => const DashboardScreen()),
];
