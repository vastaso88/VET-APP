import 'package:flutter_test/flutter_test.dart';

import 'package:vet_app_mobile/shared/config/app_runtime_config_loader.dart';

void main() {
  test('senza dart-define non punta a nessun Supabase (modalità locale)', () {
    final config = const AppRuntimeConfigLoader().load();

    expect(config.supabaseUrl, isEmpty);
    expect(config.supabaseAnonKey, isEmpty);
    expect(config.hasSupabaseCredentials, isFalse);
  });
}
