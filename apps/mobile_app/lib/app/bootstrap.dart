import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/app_bootstrap_state.dart';
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
}
