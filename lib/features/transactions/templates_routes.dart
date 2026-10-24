import 'package:go_router/go_router.dart';
import 'package:personal_finance/features/transactions/presentation/templates_screen.dart';

/// Template management (More › Templates).
final templatesRoutes = <RouteBase>[
  GoRoute(
    path: '/more/templates',
    builder: (context, state) => const TemplatesScreen(),
  ),
];
