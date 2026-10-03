import 'package:flutter/material.dart';

import '../../features/auth/presentation/pages/auth_placeholder_page.dart';
import '../../features/auth/presentation/pages/set_new_password_page.dart';
import '../../features/billing/presentation/pages/paywall_page.dart';
import '../preview/maps_demo_page.dart';
import '../shell/home_shell_page.dart';
import '../splash/splash_page.dart';

class AppRouter {
  static final navigatorKey = GlobalKey<NavigatorState>();

  /// Set by the Supabase passwordRecovery listener in bootstrap.dart. Read by
  /// the splash so a cold-start recovery link isn't overwritten by the normal
  /// route to home; cleared once the new password is saved.
  static bool passwordRecoveryPending = false;

  /// Lets a data-layer class (DogWalksRepository's failed-Supabase-sync
  /// notice, 2026-10-01) show a SnackBar without threading a BuildContext
  /// through every call site - same idea as [navigatorKey].
  static final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  static const splash = '/';
  static const auth = '/auth';
  static const home = '/home';
  static const homeShell = '/home-shell';
  static const paywall = '/paywall';
  static const setNewPassword = '/set-new-password';
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
      case paywall:
        return MaterialPageRoute<void>(
          builder: (_) => const PaywallPage(),
          settings: settings,
        );
      case setNewPassword:
        return MaterialPageRoute<void>(
          builder: (_) => const SetNewPasswordPage(),
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
