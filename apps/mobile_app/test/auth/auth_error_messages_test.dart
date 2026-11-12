import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/auth/domain/auth_error_messages.dart';
import 'package:vet_app_mobile/shared/errors/app_auth_error.dart';
import 'package:vet_app_mobile/shared/errors/app_error.dart';

AppError _error(String code, String message) => AppAuthError(code: code, message: message);

void main() {
  test('already-registered email is shown under the email field', () {
    final presented = presentAuthError(
      _error('user_already_exists', 'User already registered'),
    );
    expect(presented.field, AuthErrorField.email);
    expect(presented.message, contains('Esiste già un account'));
  });

  test('weak password is shown under the password field', () {
    final presented = presentAuthError(
      _error('weak_password', 'Password should be at least 6 characters'),
    );
    expect(presented.field, AuthErrorField.password);
  });

  test('invalid email is shown under the email field', () {
    final presented = presentAuthError(
      _error('email_address_invalid', 'Unable to validate email address: invalid format'),
    );
    expect(presented.field, AuthErrorField.email);
    expect(presented.message, contains('non sembra valido'));
  });

  test('expired recovery link gives an actionable message, no field', () {
    final presented = presentAuthError(
      _error('otp_expired', 'Email link is invalid or has expired'),
    );
    expect(presented.field, isNull);
    expect(presented.message, contains('Richiedine uno nuovo'));
  });

  test('network failure gives a connection message', () {
    final presented = presentAuthError(
      _error('auth_error', 'ClientException: Failed host lookup'),
    );
    expect(presented.field, isNull);
    expect(presented.message, contains('Nessuna connessione'));
  });

  test('unknown errors fall back to a generic Italian message', () {
    final presented = presentAuthError(_error('whatever', 'something odd'));
    expect(presented.field, isNull);
    expect(presented.message, isNotEmpty);
  });
}
