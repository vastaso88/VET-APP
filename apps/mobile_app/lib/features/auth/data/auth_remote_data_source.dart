import '../../../shared/auth/auth.dart';
import '../../../shared/types/result.dart';

abstract interface class AuthRemoteDataSource {
  Future<Result<AppSession>> signInWithPassword(
    AuthEmailPasswordCredentials credentials,
  );

  Future<Result<AppSession>> signUpWithPassword(
    AuthSignUpRequest request,
  );

  Future<Result<void>> resetPasswordForEmail(String email);

  /// Sets a new password. [email] is only used by data sources that have no
  /// notion of "current session" (the fake/offline one) — the Supabase
  /// implementation ignores it and updates whichever session Supabase
  /// itself considers active (e.g. the one it establishes automatically
  /// after the owner opens the password-recovery email link).
  Future<Result<void>> updatePassword({String? email, required String newPassword});

  Future<Result<void>> signOut();
}
