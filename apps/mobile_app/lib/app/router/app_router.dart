import 'package:flutter/material.dart';

import '../../features/auth/presentation/pages/auth_placeholder_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_welcome_page.dart';
import '../preview/maps_demo_page.dart';
import '../preview/preview_dashboard_page.dart';
import '../shell/home_shell_page.dart';
import '../splash/splash_page.dart';

class AppRouter {
  static const splash = '/';
  static const onboardingWelcome = '/onboarding';
  static const auth = '/auth';
  static const home = '/home';
  static const homeShell = '/home-shell';
  static const previewDashboard = '/preview-dashboard';
  // Isolated demo harness for the maps foundations (docs/maps/) - not
  // linked from any real nav button, see maps_demo_page.dart.
  static const mapsDemo = '/demo/maps';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute<void>(
          builder: (_) => const SplashPage(),
          settings: settings,
        );
      case onboardingWelcome:
        return MaterialPageRoute<void>(
          builder: (_) => const OnboardingWelcomePage(),
          settings: settings,
        );
      case auth:
        return MaterialPageRoute<void>(
          builder: (_) => const AuthPlaceholderPage(),
          settings: settings,
        );
      case home:
      case homeShell:
        return MaterialPageRoute<void>(
          builder: (_) => const HomeShellPage(),
          settings: settings,
        );
      case previewDashboard:
        return MaterialPageRoute<void>(
          builder: (_) => const PreviewDashboardPage(),
          settings: settings,
        );
      case mapsDemo:
        return MaterialPageRoute<void>(
          builder: (_) => const MapsDemoPage(),
          settings: settings,
        );
      default:
        return MaterialPageRoute<void>(
          builder: (_) => const SplashPage(),
          settings: settings,
        );
    }
  }
}
