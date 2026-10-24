import 'package:go_router/go_router.dart';
import 'package:personal_finance/features/onboarding/presentation/onboarding_screen.dart';

final onboardingRoutes = <RouteBase>[
  GoRoute(
    path: '/onboarding',
    builder: (context, state) => const OnboardingScreen(),
  ),
];
