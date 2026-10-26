import 'dart:async';

import '../../../shared/auth/auth.dart';
import '../../../shared/errors/app_auth_error.dart';
import '../../../shared/types/result.dart';
import '../domain/auth_repository.dart';
import 'auth_remote_data_source.dart';
import 'auth_session_store.dart';
import 'memory_auth_session_store.dart';
import 'remember_me_store.dart';

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
    AuthEmailPasswordCredentials credentials, {
    bool rememberMe = true,
  }) async {
    final result = await _remoteDataSource.signInWithPassword(credentials);
    return await result.fold(
      onSuccess: (session) async {
        final context = AuthContext(
          user: session.user,
          session: session,
          onboardingCompleted: session.user.onboardingCompleted,
          rememberMe: rememberMe,
        );
        await _sessionStore.write(context);
        // Honoured at the next launch for the Supabase session (see
        // RememberMeStore); the demo store honours it on its own.
        await RememberMeStore.write(rememberMe);
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
  Future<Result<void>> updatePassword({String? email, required String newPassword}) {
    return _remoteDataSource.updatePassword(
      email: email ?? currentContext.user?.email,
      newPassword: newPassword,
    );
  }

  @override
  Future<Result<AuthContext>> updateProfile(ProfileUpdate update) async {
    final result = await _remoteDataSource.updateProfile(
      email: currentContext.user?.email,
      update: update,
    );
    return await result.fold(
      onSuccess: (user) async => Result.success(await _replaceUser(user)),
      onFailure: (error) async => Result.failure(error),
    );
  }

  @override
  Future<Result<EmailChangeStatus>> changeEmail(String newEmail) async {
    final current = currentContext.user?.email;
    final result = await _remoteDataSource.changeEmail(email: current, newEmail: newEmail);
    return await result.fold(
      onSuccess: (status) async {
        if (status == EmailChangeStatus.applied) {
          final user = currentContext.user;
          if (user != null) await _replaceUser(user.copyWith(email: newEmail.trim()));
        }
        return Result.success(status);
      },
      onFailure: (error) async => Result.failure(error),
    );
  }

  @override
  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final email = currentContext.user?.email;
    if (email == null) {
      return Result.failure(
        const AppAuthError(code: 'no_active_session', message: 'No signed-in account'),
      );
    }
    final verified = await _remoteDataSource.verifyPassword(
      email: email,
      password: currentPassword,
    );
    return await verified.fold(
      onSuccess: (_) => _remoteDataSource.updatePassword(email: email, newPassword: newPassword),
      onFailure: (error) async => Result.failure(error),
    );
  }

  @override
  Future<Result<AuthContext>> deleteAccount({required String password}) async {
    final email = currentContext.user?.email;
    if (email == null) {
      return Result.failure(
        const AppAuthError(code: 'no_active_session', message: 'No signed-in account'),
      );
    }
    final verified = await _remoteDataSource.verifyPassword(email: email, password: password);
    return await verified.fold(
      onSuccess: (_) async {
        final deleted = await _remoteDataSource.deleteAccount(email: email);
        return await deleted.fold(
          onSuccess: (_) async {
            await _sessionStore.clear();
            return Result.success(const AuthContext());
          },
          onFailure: (error) async => Result.failure(error),
        );
      },
      onFailure: (error) async => Result.failure(error),
    );
  }

  /// Puts [user] into the stored session, so every screen that reads the
  /// current user (greetings, avatar, profile) sees the change at once.
  Future<AuthContext> _replaceUser(AppUser user) async {
    final context = currentContext;
    final session = context.session;
    final updated = context.copyWith(
      user: user,
      session: session?.copyWith(user: user),
    );
    await _sessionStore.write(updated);
    return updated;
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
