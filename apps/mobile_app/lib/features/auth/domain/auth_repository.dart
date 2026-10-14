import '../../../shared/auth/auth.dart';
import '../../../shared/types/result.dart';

abstract interface class AuthRepository {
  AuthContext get currentContext;

  Stream<AuthContext> watchContext();

  Future<Result<AuthContext>> restoreSession();

  Future<Result<AuthContext>> signInWithPassword(
    AuthEmailPasswordCredentials credentials, {
    bool rememberMe = true,
  });

  Future<Result<AuthContext>> signUpWithPassword(
    AuthSignUpRequest request,
  );

  Future<Result<void>> resetPasswordForEmail(String email);

  Future<Result<void>> updatePassword({String? email, required String newPassword});

  /// Saves the profile and refreshes the signed-in user everywhere.
  Future<Result<AuthContext>> updateProfile(ProfileUpdate update);

  Future<Result<EmailChangeStatus>> changeEmail(String newEmail);

  /// Checks the current password again (by signing in) and, only if it is
  /// right, sets [newPassword].
  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Deletes the account after checking [password]; on success the stored
  /// session is gone too.
  Future<Result<AuthContext>> deleteAccount({required String password});

  Future<Result<AuthContext>> signOut();
}
