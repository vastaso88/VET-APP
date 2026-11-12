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

  /// Saves the profile fields in the account. [email] only identifies the
  /// account for the fake/offline source (Supabase uses its own session).
  Future<Result<AppUser>> updateProfile({String? email, required ProfileUpdate update});

  /// Asks to change the sign-in email. Whether it applies at once or needs a
  /// confirmation link depends on the project's email settings; the result
  /// says which happened.
  Future<Result<EmailChangeStatus>> changeEmail({String? email, required String newEmail});

  /// Checks [password] against the account by signing in again, without
  /// changing who is signed in.
  Future<Result<void>> verifyPassword({required String email, required String password});

  /// Deletes the signed-in account and all its data (right to erasure).
  Future<Result<void>> deleteAccount({String? email});

  Future<Result<void>> signOut();
}
