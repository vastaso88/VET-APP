/// When the collaudo build may sign in by itself (agreed with the Auth session, 22/11/2026).
///
/// Only `lib/main_collaudo.dart` uses this; the normal entry point never imports it, so a
/// normal build cannot contain the automatic sign-in. Every condition must hold, otherwise
/// the app starts normally:
/// - the Supabase address is exactly `https://<twinRef>.supabase.co` (allowlist), and never
///   the production project or a retired one (denylist on top);
/// - the account is a synthetic `@example.com` one, with a password;
/// - the build is not a production build;
/// - nobody is signed in yet.
class CollaudoAutoLoginGuard {
  const CollaudoAutoLoginGuard._();

  static const forbiddenRefs = {
    'ywbuzgwbkrmkukkpysbz',
    'dkzzcoastheciitvkiuo',
    'noulpaaonqjvprfddipn',
  };

  /// A debug-only code saying why the automatic sign-in is refused, or null when it may run.
  static String? refusal({
    required String supabaseUrl,
    required String twinRef,
    required String email,
    required String password,
    required String environment,
    required bool alreadySignedIn,
  }) {
    final ref = twinRef.trim().toLowerCase();
    final url = supabaseUrl.trim().toLowerCase();
    if (forbiddenRefs.any(url.contains) || forbiddenRefs.contains(ref)) {
      return 'forbidden_project';
    }
    if (!RegExp(r'^[a-z0-9]{20}$').hasMatch(ref)) {
      return 'missing_twin_ref';
    }
    final host = Uri.tryParse(url)?.host ?? '';
    if (!url.startsWith('https://') || host != '$ref.supabase.co') {
      return 'not_the_twin';
    }
    if (!email.trim().toLowerCase().endsWith('@example.com') || password.isEmpty) {
      return 'not_synthetic';
    }
    if (environment.trim().toLowerCase() == 'production') {
      return 'production_build';
    }
    if (alreadySignedIn) {
      return 'already_signed_in';
    }
    return null;
  }
}
