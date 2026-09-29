import 'app_env_keys.dart';
import 'app_runtime_config.dart';

class AppRuntimeConfigLoader {
  const AppRuntimeConfigLoader();

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
        defaultValue: '',
      ),
      supabaseAnonKey: const String.fromEnvironment(
        AppEnvKeys.supabaseAnonKey,
        defaultValue: '',
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
