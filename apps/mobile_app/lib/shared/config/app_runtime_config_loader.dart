import 'app_env_keys.dart';
import 'app_runtime_config.dart';

class AppRuntimeConfigLoader {
  const AppRuntimeConfigLoader();

  static const _defaultSupabaseUrl =
      'https://ywbuzgwbkrmkukkpysbz.supabase.co';
  static const _defaultSupabasePublishableKey =
      'sb_publishable_t5vFAehg91FYPh_rFLOiUQ_Wv9tFh5m';

  AppRuntimeConfig load() {
    const configuredSupabaseUrl = String.fromEnvironment(
      AppEnvKeys.supabaseUrl,
      defaultValue: _defaultSupabaseUrl,
    );
    const configuredSupabaseKey = String.fromEnvironment(
      AppEnvKeys.supabaseAnonKey,
      defaultValue: _defaultSupabasePublishableKey,
    );

    final useCanonicalSupabase = _isDeprecatedSupabaseUrl(configuredSupabaseUrl);

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
      supabaseUrl:
          useCanonicalSupabase ? _defaultSupabaseUrl : configuredSupabaseUrl,
      // Supabase's Flutter client still names this parameter `anonKey`, but
      // the current recommended client credential is the publishable key.
      // During the project consolidation, two temporary Supabase projects
      // existed. A stale build-time define for either one must not send auth
      // traffic back to those retired environments.
      supabaseAnonKey: useCanonicalSupabase
          ? _defaultSupabasePublishableKey
          : configuredSupabaseKey,
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

  bool _isDeprecatedSupabaseUrl(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.contains('dkzzcoastheciitvkiuo.supabase.co') ||
        normalized.contains('noulpaaonqjvprfddipn.supabase.co');
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
