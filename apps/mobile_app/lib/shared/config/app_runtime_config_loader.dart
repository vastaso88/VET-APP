import 'app_env_keys.dart';
import 'app_runtime_config.dart';

class AppRuntimeConfigLoader {
  const AppRuntimeConfigLoader();

  static const _defaultSupabaseUrl =
      'https://ywbuzgwbkrmkukkpysbz.supabase.co';
  static const _defaultSupabasePublishableKey =
      'sb_publishable_t5vFAehg91FYPh_rFLOiUQ_Wv9tFh5m';

  AppRuntimeConfig load() {
    return AppRuntimeConfig(
      environment: _parseEnvironment(
        const String.fromEnvironment(
          AppEnvKeys.environment,
          defaultValue: 'development',
        ),
      ),
      appName: const String.fromEnvironment(
        AppEnvKeys.appName,
        defaultValue: 'Vet App',
      ),
      apiBaseUrl: const String.fromEnvironment(
        AppEnvKeys.apiBaseUrl,
        defaultValue: '',
      ),
      supabaseUrl: const String.fromEnvironment(
        AppEnvKeys.supabaseUrl,
        defaultValue: _defaultSupabaseUrl,
      ),
      // Supabase's Flutter client still names this parameter `anonKey`, but
      // the current recommended client credential is the publishable key.
      supabaseAnonKey: const String.fromEnvironment(
        AppEnvKeys.supabaseAnonKey,
        defaultValue: _defaultSupabasePublishableKey,
      ),
      logLevel: const String.fromEnvironment(
        AppEnvKeys.logLevel,
        defaultValue: 'INFO',
      ),
      enableTelemetry: const bool.fromEnvironment(
        AppEnvKeys.enableTelemetry,
        defaultValue: false,
      ),
      cartoApiKey: const String.fromEnvironment(
        AppEnvKeys.cartoApiKey,
        defaultValue: '',
      ),
      walkMapStyle: const String.fromEnvironment(
        AppEnvKeys.walkMapStyle,
        defaultValue: 'osm',
      ),
    );
  }

  AppEnvironment _parseEnvironment(String value) {
    switch (value.toLowerCase()) {
      case 'production':
        return AppEnvironment.production;
      case 'staging':
        return AppEnvironment.staging;
      default:
        return AppEnvironment.development;
    }
  }
}
