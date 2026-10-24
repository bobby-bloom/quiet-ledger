import 'package:go_router/go_router.dart';
import 'package:personal_finance/features/forecast/presentation/forecast_screen.dart';
import 'package:personal_finance/features/forecast/presentation/projection_screen.dart';
import 'package:personal_finance/features/scenarios/presentation/scenario_editor_screen.dart';
import 'package:personal_finance/features/scenarios/presentation/scenarios_screen.dart';

/// Routes of the forecast and scenarios features:
/// * `/forecast` cash-flow forecast board
/// * `/forecast/projection` long-term net-worth projection
/// * `/forecast/scenarios` scenario list
/// * `/forecast/scenarios/new`, `/forecast/scenarios/:id` scenario editor
///
/// Each screen shows a "turned off" message when its module is disabled.
final forecastRoutes = <RouteBase>[
  GoRoute(
    path: '/forecast',
    builder: (context, state) => const ForecastScreen(),
    routes: [
      GoRoute(
        path: 'projection',
        builder: (context, state) => const ProjectionScreen(),
      ),
      GoRoute(
        path: 'scenarios',
        builder: (context, state) => const ScenariosScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) =>
                ScenarioEditorScreen(scenarioId: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
  ),
];
