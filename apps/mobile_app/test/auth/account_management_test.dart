import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/features/account/presentation/pages/change_password_page.dart';
import 'package:vet_app_mobile/features/auth/data/auth_repository_impl.dart';
import 'package:vet_app_mobile/features/auth/data/fake_auth_remote_data_source.dart';
import 'package:vet_app_mobile/features/auth/data/memory_auth_session_store.dart';
import 'package:vet_app_mobile/shared/auth/auth.dart';
import 'package:vet_app_mobile/shared/errors/app_auth_error.dart';

const _email = 'demo@vetapp.local';
const _password = 'VETAPP';

Future<AuthRepositoryImpl> _signedIn() async {
  SharedPreferences.setMockInitialValues({});
  final repository = AuthRepositoryImpl(
    remoteDataSource: FakeAuthRemoteDataSource(),
    sessionStore: MemoryAuthSessionStore(),
  );
  final result = await repository.signInWithPassword(
    const AuthEmailPasswordCredentials(email: _email, password: _password),
  );
  expect(result.isSuccess, isTrue);
  return repository;
}

void main() {
  test('the optional phone given at sign-up is kept on the account, E.164', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = AuthRepositoryImpl(
      remoteDataSource: FakeAuthRemoteDataSource(),
      sessionStore: MemoryAuthSessionStore(),
    );

    final withPhone = await repository.signUpWithPassword(
      const AuthSignUpRequest(
        email: 'con.telefono@vetapp.local',
        password: 'secret-1',
        displayName: 'Ada',
        phone: '+393331234567',
      ),
    );
    expect(withPhone.isSuccess, isTrue);
    expect(repository.currentContext.user!.phone, '+393331234567');

    final without = await repository.signUpWithPassword(
      const AuthSignUpRequest(
        email: 'senza.telefono@vetapp.local',
        password: 'secret-1',
        displayName: 'Bea',
      ),
    );
    expect(without.isSuccess, isTrue);
    expect(repository.currentContext.user!.phone, isNull);
  });

  test('saving the profile updates the signed-in user everywhere', () async {
    final repository = await _signedIn();

    final saved = await repository.updateProfile(
      const ProfileUpdate(firstName: 'Mario', lastName: 'Rossi', phone: '+39 333 1234567'),
    );

    expect(saved.isSuccess, isTrue);
    final user = repository.currentContext.user!;
    expect(user.displayName, 'Mario Rossi');
    expect(user.firstName, 'Mario');
    expect(user.phone, '+39 333 1234567');
    expect(repository.currentContext.session!.user.displayName, 'Mario Rossi');

    await repository.updateProfile(const ProfileUpdate(firstName: 'Mario', lastName: 'Rossi'));
    expect(repository.currentContext.user!.phone, isNull);
  });

  test('changing the password asks for the current one first', () async {
    final repository = await _signedIn();

    final wrong = await repository.changePassword(
      currentPassword: 'not-it',
      newPassword: 'brand-new-1',
    );
    expect(wrong.isFailure, isTrue);
    expect(wrong.fold(onSuccess: (_) => null, onFailure: (e) => isWrongPasswordError(e)), isTrue);

    final right = await repository.changePassword(
      currentPassword: _password,
      newPassword: 'brand-new-1',
    );
    expect(right.isSuccess, isTrue);

    final oldLogin = await repository.signInWithPassword(
      const AuthEmailPasswordCredentials(email: _email, password: _password),
    );
    final newLogin = await repository.signInWithPassword(
      const AuthEmailPasswordCredentials(email: _email, password: 'brand-new-1'),
    );
    expect(oldLogin.isFailure, isTrue);
    expect(newLogin.isSuccess, isTrue);
  });

  test('changing the email applies at once offline and refuses an address in use', () async {
    final repository = await _signedIn();

    final changed = await repository.changeEmail('nuova@vetapp.local');
    expect(changed.fold(onSuccess: (s) => s, onFailure: (_) => null), EmailChangeStatus.applied);
    expect(repository.currentContext.user!.email, 'nuova@vetapp.local');

    final taken = await repository.changeEmail('nuova@vetapp.local');
    expect(taken.isFailure, isTrue);
  });

  test('deleting the account needs the right password and ends the session', () async {
    final repository = await _signedIn();

    final refused = await repository.deleteAccount(password: 'not-it');
    expect(refused.isFailure, isTrue);
    expect(repository.currentContext.isSignedIn, isTrue);

    final deleted = await repository.deleteAccount(password: _password);
    expect(deleted.isSuccess, isTrue);
    expect(repository.currentContext.isSignedIn, isFalse);

    final login = await repository.signInWithPassword(
      const AuthEmailPasswordCredentials(email: _email, password: _password),
    );
    expect(login.isFailure, isTrue);
  });

  test('a wrong password is recognised from Supabase errors', () {
    expect(
      isWrongPasswordError(
        const AppAuthError(code: 'invalid_credentials', message: 'Invalid login credentials'),
      ),
      isTrue,
    );
    expect(
      isWrongPasswordError(const AppAuthError(code: 'weak_password', message: 'too short')),
      isFalse,
    );
  });
}
