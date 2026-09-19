import '../../../shared/auth/auth.dart';
import '../../../shared/types/result.dart';

abstract interface class AuthRepository {
  AuthContext get currentContext;

  Stream<AuthContext> watchContext();

  Future<Result<AuthContext>> restoreSession();

  Future<Result<AuthContext>> signInWithPassword(
    AuthEmailPasswordCredentials credentials,
  );

  Future<Result<AuthContext>> signUpWithPassword(
    AuthSignUpRequest request,
  );

  Future<Result<void>> resetPasswordForEmail(String email);

  Future<Result<AuthContext>> signOut();
}
