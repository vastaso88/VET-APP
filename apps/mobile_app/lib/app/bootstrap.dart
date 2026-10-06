import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/app_bootstrap_state.dart';
import 'router/app_router.dart';
import '../features/dog_walks/data/walk_home_widget.dart';
import '../shared/config/app_runtime_config_loader.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('it_IT');

  // The app has no landscape layouts anywhere; rotating breaks several
  // pages (Home's week-strip, the walk map). The Android manifest also
  // locks the activity to portrait, but this covers iOS/web too, and any
  // future full-screen viewer (e.g. photos) that wants to allow rotation
  // is expected to call setPreferredOrientations again on entry and
  // restore this call on exit.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  if (kIsWeb) {
    usePathUrlStrategy();
  }

  final runtimeConfig = const AppRuntimeConfigLoader().load();
  if (runtimeConfig.isProduction && !runtimeConfig.hasSupabaseCredentials) {
    throw StateError(
      'Build di produzione senza SUPABASE_URL/SUPABASE_ANON_KEY: '
      'usa --dart-define-from-file=.env.production.json',
    );
  }
  var supabaseEnabled = false;

  if (runtimeConfig.hasSupabaseCredentials) {
    try {
      await Supabase.initialize(
        url: runtimeConfig.supabaseUrl,
        anonKey: runtimeConfig.supabaseAnonKey,
      );
      supabaseEnabled = true;

      // Supabase parses a password-recovery link's URL fragment during
      // initialize() above and fires this event once the resulting
      // recovery session is ready — that's the only reliable signal that
      // "the current session exists because of a reset link", as opposed
      // to a normal sign-in. Without this, opening the email link would
      // just log the owner straight into their account instead of asking
      // for a new password.
      Supabase.instance.client.auth.onAuthStateChange.listen((state) {
        if (state.event == AuthChangeEvent.passwordRecovery) {
          AppRouter.passwordRecoveryPending = true;
          _openSetNewPasswordWhenReady();
        }
      });
    } catch (_) {
      supabaseEnabled = false;
    }
  }

  runApp(
    VetApp(
      bootstrapState: AppBootstrapState(
        runtimeConfig: runtimeConfig,
        supabaseEnabled: supabaseEnabled,
      ),
    ),
  );

  initWalkHomeWidgetLaunchHandling();
}

/// On a cold start the recovery link can arrive before the first frame, when
/// there is no navigator yet: retry briefly instead of dropping it.
void _openSetNewPasswordWhenReady({int attempt = 0}) {
  final navigator = AppRouter.navigatorKey.currentState;
  if (navigator != null) {
    navigator.pushNamedAndRemoveUntil(AppRouter.setNewPassword, (route) => false);
    return;
  }
  if (attempt < 50) {
    Future<void>.delayed(
      const Duration(milliseconds: 100),
      () => _openSetNewPasswordWhenReady(attempt: attempt + 1),
    );
  }
}
