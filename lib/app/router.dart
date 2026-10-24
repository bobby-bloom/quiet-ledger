import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/app/shell/adaptive_shell.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/accounts/accounts_routes.dart';
import 'package:personal_finance/features/categories/categories_routes.dart';
import 'package:personal_finance/features/dashboard/dashboard_routes.dart';
import 'package:personal_finance/features/export/export_routes.dart';
import 'package:personal_finance/features/forecast/forecast_routes.dart';
import 'package:personal_finance/features/import/import_routes.dart';
import 'package:personal_finance/features/more/more_routes.dart';
import 'package:personal_finance/features/onboarding/onboarding_routes.dart';
import 'package:personal_finance/features/plan/plan_routes.dart';
import 'package:personal_finance/features/reports/reports_routes.dart';
import 'package:personal_finance/features/rules/rules_routes.dart';
import 'package:personal_finance/features/settings/settings_routes.dart';
import 'package:personal_finance/features/transactions/templates_routes.dart';
import 'package:personal_finance/features/transactions/transactions_routes.dart';

/// Shell branches. The order is fixed (go_router needs stable branches);
/// which ones show in the nav bar is configurable (Settings › Navigation).
/// Branches not shown are reachable through More.
enum ShellBranch { home, transactions, plan, forecast, accounts, reports, more }

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

String _startLocation(StartScreen s) => switch (s) {
  StartScreen.home => '/home',
  StartScreen.transactions => '/transactions',
  StartScreen.plan => '/plan',
  StartScreen.forecast => '/forecast',
};

final routerProvider = Provider<GoRouter>((ref) {
  final settings = ref.read(settingsProvider);
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: settings.get(GeneralSettings.onboardingDone)
        ? _startLocation(settings.get(GeneralSettings.startScreen))
        : '/onboarding',
    redirect: (context, state) {
      final done = ref
          .read(settingsProvider)
          .get(GeneralSettings.onboardingDone);
      final atOnboarding = state.matchedLocation.startsWith('/onboarding');
      if (!done && !atOnboarding) return '/onboarding';
      if (state.matchedLocation == '/') return '/home';
      return null;
    },
    routes: [
      ...onboardingRoutes,
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            AdaptiveShell(shell: shell, location: state.uri.path),
        branches: [
          StatefulShellBranch(routes: dashboardRoutes),
          StatefulShellBranch(routes: transactionsRoutes),
          StatefulShellBranch(routes: planRoutes),
          StatefulShellBranch(routes: forecastRoutes),
          StatefulShellBranch(routes: accountsRoutes),
          StatefulShellBranch(routes: reportsRoutes),
          StatefulShellBranch(
            routes: [
              ...moreRoutes,
              ...settingsRoutes,
              ...categoriesRoutes,
              ...rulesRoutes,
              ...importRoutes,
              ...exportRoutes,
              ...templatesRoutes,
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
