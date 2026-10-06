import 'app_env_keys.dart';
import 'app_runtime_config.dart';

class AppRuntimeConfigLoader {
  const AppRuntimeConfigLoader();

  AppRuntimeConfig load() {
    const configuredSupabaseUrl = String.fromEnvironment(
      AppEnvKeys.supabaseUrl,
      defaultValue: '',
    );
    const configuredSupabaseKey = String.fromEnvironment(
      AppEnvKeys.supabaseAnonKey,
      defaultValue: '',
    );

    final retiredSupabase = _isDeprecatedSupabaseUrl(configuredSupabaseUrl);

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
      // Supabase's Flutter client still names this parameter `anonKey`, but
      // the current recommended client credential is the publishable key.
      // A retired project's URL (from a stale build-time define) is dropped
      // rather than replaced, so that build runs in local mode instead of
      // sending auth traffic to a dead environment.
      supabaseUrl: retiredSupabase ? '' : configuredSupabaseUrl,
      supabaseAnonKey: retiredSupabase ? '' : configuredSupabaseKey,
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
