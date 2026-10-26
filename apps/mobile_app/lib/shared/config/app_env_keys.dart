class AppEnvKeys {
  static const environment = 'ENVIRONMENT';
  static const appName = 'APP_NAME';
  static const apiBaseUrl = 'API_BASE_URL';
  static const supabaseUrl = 'SUPABASE_URL';
  static const supabaseAnonKey = 'SUPABASE_ANON_KEY';
  // No service-role key here, ever: it bypasses row-level security and
  // belongs to the backend only (see docs/security/02_audit.md).
  static const logLevel = 'LOG_LEVEL';
  static const enableTelemetry = 'ENABLE_TELEMETRY';
  static const cartoApiKey = 'CARTO_API_KEY';
  static const walkMapStyle = 'WALK_MAP_STYLE';
}
