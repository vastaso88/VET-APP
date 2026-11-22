// Entry point of the COLLAUDO builds only (web build for the aesthetics testers, APK for the
// Android emulator): `flutter build web|apk -t lib/main_collaudo.dart`. Never distributed,
// never uploaded anywhere (Vercel, Drive, Firebase, attachments): the synthetic password is
// readable inside the bundle. `lib/main.dart` does not import this file.
//
// The account comes from --dart-define at build time (values in .local/collaudo/, outside the
// repository); there is no default value on purpose. See docs/collaudo/00_metodo.md.
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/bootstrap.dart';
import 'collaudo/auto_login_guard.dart';
import 'features/auth/data/remember_me_store.dart';
import 'shared/config/app_env_keys.dart';

const _email = String.fromEnvironment('COLLAUDO_EMAIL');
const _password = String.fromEnvironment('COLLAUDO_PASSWORD');
const _twinRef = String.fromEnvironment('COLLAUDO_SUPABASE_REF');
const _supabaseUrl = String.fromEnvironment(AppEnvKeys.supabaseUrl);
const _environment = String.fromEnvironment(AppEnvKeys.environment);

Future<void> main() async {
  await bootstrap(afterSupabaseReady: _signInTestAccount);
}

Future<void> _signInTestAccount() async {
  final auth = Supabase.instance.client.auth;
  final refusal = CollaudoAutoLoginGuard.refusal(
    supabaseUrl: _supabaseUrl,
    twinRef: _twinRef,
    email: _email,
    password: _password,
    environment: _environment,
    alreadySignedIn: auth.currentSession != null,
  );
  if (refusal != null) {
    // One notice, never the password or the address.
    debugPrint('Collaudo: automatic sign-in skipped ($refusal)');
    return;
  }
  try {
    await auth.signInWithPassword(email: _email, password: _password);
    await RememberMeStore.write(true);
  } catch (_) {
    debugPrint('Collaudo: automatic sign-in failed');
  }
}
