import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class AccountLanguageStore {
  Future<String?> read();
  Future<void> write(String languageCode, String variantId);
}

/// A display preference, never an authorization claim.
class SupabaseAccountLanguageStore implements AccountLanguageStore {
  const SupabaseAccountLanguageStore();

  @override
  Future<String?> read() async {
    final auth = Supabase.instance.client.auth;
    if (auth.currentUser == null) return null;
    final user = (await auth.getUser()).user;
    final value = user?.userMetadata?['preferred_locale_variant'] ??
        user?.userMetadata?['preferred_locale'];
    return value is String ? value : null;
  }

  @override
  Future<void> write(String languageCode, String variantId) async {
    final auth = Supabase.instance.client.auth;
    if (auth.currentUser == null) return;
    await auth.updateUser(UserAttributes(data: {
      'preferred_locale': languageCode,
      'preferred_locale_variant': variantId,
    }));
  }
}
