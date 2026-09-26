import '../../features/auth/data/auth_repository_factory.dart';
import 'app_user.dart';

/// Small convenience wrapper around the cached [AuthRepositoryFactory]
/// repository, so screens can read who is actually signed in without
/// each one re-deriving the fallback logic.
class CurrentUser {
  const CurrentUser._();

  static AppUser? get() =>
      const AuthRepositoryFactory().create().currentContext.user;

  /// A short, presentable name for greetings and avatars.
  /// Falls back to the email's local part, then to [fallback].
  static String firstName({String fallback = 'ospite'}) {
    final user = get();
    if (user == null) {
      return fallback;
    }

    final displayName = user.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName.split(' ').first;
    }

    final emailLocalPart = user.email.split('@').first.trim();
    return emailLocalPart.isEmpty ? fallback : emailLocalPart;
  }

  static String fullName({String fallback = 'Ospite'}) {
    final user = get();
    if (user == null) {
      return fallback;
    }

    final displayName = user.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    final emailLocalPart = user.email.split('@').first.trim();
    return emailLocalPart.isEmpty ? fallback : emailLocalPart;
  }
}
