enum AppEnvironment {
  development,
  staging,
  production,
}

class AppRuntimeConfig {
  const AppRuntimeConfig({
    required this.environment,
    required this.appName,
    required this.apiBaseUrl,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.logLevel,
    required this.enableTelemetry,
    this.cartoApiKey = '',
  });

  final AppEnvironment environment;
  final String appName;
  final String apiBaseUrl;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String logLevel;
  final bool enableTelemetry;

  /// CARTO now watermarks its free raster basemaps ("API KEY REQUIRED")
  /// without one - see walk_map_style.dart. Free tier is plenty for this
  /// app's volume (carto.com/basemaps/apikey), just needs registering.
  final String cartoApiKey;

  bool get hasCartoApiKey => cartoApiKey.trim().isNotEmpty;

  bool get hasApiBaseUrl => apiBaseUrl.trim().isNotEmpty;
  bool get hasSupabaseCredentials =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  bool get isProduction => environment == AppEnvironment.production;
}
