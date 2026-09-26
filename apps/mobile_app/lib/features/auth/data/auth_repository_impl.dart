import 'dart:async';

import '../../../shared/auth/auth.dart';
import '../../../shared/types/result.dart';
import '../domain/auth_repository.dart';
import 'auth_remote_data_source.dart';
import 'auth_session_store.dart';
import 'memory_auth_session_store.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required AuthSessionStore sessionStore,
  })  : _remoteDataSource = remoteDataSource,
        _sessionStore = sessionStore {
    _contextController.add(_sessionStore.read());
    _storeSubscription = _sessionStore.watch().listen(_contextController.add);
  }

  final AuthRemoteDataSource _remoteDataSource;
  final AuthSessionStore _sessionStore;
  final StreamController<AuthContext> _contextController =
      StreamController<AuthContext>.broadcast();
  late final StreamSubscription<AuthContext> _storeSubscription;

  @override
  AuthContext get currentContext => _sessionStore.read();

  @override
  Stream<AuthContext> watchContext() => _contextController.stream;

  @override
  Future<Result<AuthContext>> restoreSession() async {
    final context = await _sessionStore.restore();
    return Result.success(context);
  }

  @override
  Future<Result<AuthContext>> signInWithPassword(
    AuthEmailPasswordCredentials credentials,
  ) async {
    final result = await _remoteDataSource.signInWithPassword(credentials);
    return await result.fold(
      onSuccess: (session) async {
        final context = AuthContext(
          user: session.user,
          session: session,
          onboardingCompleted: session.user.onboardingCompleted,
        );
        await _sessionStore.write(context);
        return Result.success(context);
      },
      onFailure: (error) async => Result.failure(error),
    );
  }

  @override
  Future<Result<AuthContext>> signUpWithPassword(
    AuthSignUpRequest request,
  ) async {
    final result = await _remoteDataSource.signUpWithPassword(request);
    return await result.fold(
      onSuccess: (session) async {
        // Reaching the register form means the user already stepped through
        // the onboarding welcome/value-proposition/privacy screens.
        final user = session.user.copyWith(onboardingCompleted: true);
        final updatedSession = session.copyWith(user: user);
        final context = AuthContext(
          user: user,
          session: updatedSession,
          onboardingCompleted: true,
        );
        await _sessionStore.write(context);
        return Result.success(context);
      },
      onFailure: (error) async => Result.failure(error),
    );
  }

  @override
  Future<Result<void>> resetPasswordForEmail(String email) {
    return _remoteDataSource.resetPasswordForEmail(email);
  }

  @override
  Future<Result<AuthContext>> signOut() async {
    final result = await _remoteDataSource.signOut();
    return await result.fold(
      onSuccess: (_) async {
        const context = AuthContext();
        await _sessionStore.clear();
        return Result.success(context);
      },
      onFailure: (error) async => Result.failure(error),
    );
  }

  Future<void> dispose() async {
    await _storeSubscription.cancel();
    await _contextController.close();
    if (_sessionStore case final MemoryAuthSessionStore memoryStore) {
      await memoryStore.dispose();
    }
  }
}
