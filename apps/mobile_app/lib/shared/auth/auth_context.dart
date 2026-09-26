import 'app_session.dart';
import 'app_user.dart';

class AuthContext {
  const AuthContext({
    this.user,
    this.session,
    this.onboardingCompleted = false,
    this.rememberMe = true,
  });

  final AppUser? user;
  final AppSession? session;
  final bool onboardingCompleted;

  /// Whether this session should survive a full app restart. Set from the
  /// "Resta connesso" checkbox at login; a session store may drop a
  /// non-remembered session when the app cold-starts (see
  /// `PersistentAuthSessionStore.restore`).
  final bool rememberMe;

  bool get isSignedIn => user != null && session != null;

  AuthContext copyWith({
    AppUser? user,
    AppSession? session,
    bool? onboardingCompleted,
    bool? rememberMe,
  }) {
    return AuthContext(
      user: user ?? this.user,
      session: session ?? this.session,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      rememberMe: rememberMe ?? this.rememberMe,
    );
  }
}
