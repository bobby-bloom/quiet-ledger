import 'package:go_router/go_router.dart';
import 'package:personal_finance/features/import/presentation/import_history_screen.dart';
import 'package:personal_finance/features/import/presentation/import_wizard_screen.dart';

/// Routes of the import feature (PLAN.md §2.5):
/// * `/more/import` – the wizard (`?profile=<id>` preselects a profile)
/// * `/more/import/history` – batches (undo) and profiles
///   (`?tab=profiles` opens the profiles tab)
final importRoutes = <RouteBase>[
  GoRoute(
    path: '/more/import',
    builder: (context, state) =>
        ImportWizardScreen(profileId: state.uri.queryParameters['profile']),
    routes: [
      GoRoute(
        path: 'history',
        builder: (context, state) => ImportHistoryScreen(
          initialTab: state.uri.queryParameters['tab'] == 'profiles' ? 1 : 0,
        ),
      ),
    ],
  ),
];
