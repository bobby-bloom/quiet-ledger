import 'package:go_router/go_router.dart';
import 'package:personal_finance/features/settings/presentation/settings_screen.dart';

/// Settings routes:
/// * `/more/settings` – search and section list (two panes when expanded)
/// * `/more/settings/:section` – one section (`SettingSection.name` or
///   `about`); `?focus=<setting key>` scrolls to and highlights a setting.
final settingsRoutes = <RouteBase>[
  GoRoute(
    path: '/more/settings',
    builder: (context, state) => const SettingsScreen(),
    routes: [
      GoRoute(
        path: ':section',
        builder: (context, state) => SettingsScreen(
          pageId: state.pathParameters['section'],
          focusId: state.uri.queryParameters['focus'],
        ),
      ),
    ],
  ),
];
