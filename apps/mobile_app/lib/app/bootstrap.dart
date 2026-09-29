import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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

  if (kIsWeb) {
    usePathUrlStrategy();
  }

  final runtimeConfig = const AppRuntimeConfigLoader().load();
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
          AppRouter.navigatorKey.currentState
              ?.pushNamedAndRemoveUntil(AppRouter.setNewPassword, (route) => false);
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
