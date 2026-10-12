import '../../../l10n/l10n.dart';
import '../../../shared/errors/app_error.dart';

enum AuthErrorField { email, password }

class AuthErrorPresentation {
  const AuthErrorPresentation({required this.message, this.field});

  final String message;
  final AuthErrorField? field;
}

/// Maps Supabase/network errors to localized copy. [field] tells the form
/// which input to show the message under; null means a general banner.
AuthErrorPresentation presentAuthError(AppError error) {
  return _knownAuthError(error) ?? AuthErrorPresentation(message: appL10n.authErrorGeneric);
}

/// Message to show for an auth error whose raw text would otherwise reach the
/// screen (login, password reset): the localized copy for every error we
/// know, the raw message for anything else.
String localizedAuthMessage(AppError error) {
  final known = _knownAuthError(error);
  if (known != null) return known.message;
  final code = error.code.toLowerCase();
  if (code.startsWith('unexpected_') ||
      code == 'sign_in_incomplete' ||
      code == 'no_active_session') {
    return appL10n.authErrorGeneric;
  }
  return error.message;
}

AuthErrorPresentation? _knownAuthError(AppError error) {
  final l10n = appL10n;
  final code = error.code.toLowerCase();
  final raw = error.message.toLowerCase();

  if (code == 'user_already_exists' ||
      code == 'email_exists' ||
      raw.contains('user already registered') ||
      raw.contains('already registered')) {
    return AuthErrorPresentation(
      message: l10n.authErrorEmailExists,
      field: AuthErrorField.email,
    );
  }

  if (code == 'weak_password' || raw.contains('password should be') || raw.contains('weak')) {
    return AuthErrorPresentation(
      message: l10n.authErrorWeakPassword,
      field: AuthErrorField.password,
    );
  }

  if (code == 'email_address_invalid' ||
      code == 'validation_failed' ||
      raw.contains('invalid format') ||
      raw.contains('unable to validate email')) {
    return AuthErrorPresentation(
      message: l10n.authErrorEmailInvalid,
      field: AuthErrorField.email,
    );
  }

  if (code == 'email_not_confirmed' || raw.contains('email not confirmed')) {
    return AuthErrorPresentation(message: l10n.authErrorEmailNotConfirmed);
  }

  if (code == 'email_not_found' || raw.contains('no account found')) {
    return AuthErrorPresentation(message: l10n.authErrorEmailNotFound);
  }

  if (raw.contains('socketexception') ||
      raw.contains('failed host lookup') ||
      raw.contains('clientexception') ||
      raw.contains('network') ||
      raw.contains('connection') ||
      code == 'network') {
    return AuthErrorPresentation(message: l10n.authErrorNoConnection);
  }

  if (code == 'otp_expired' || raw.contains('expired') || raw.contains('invalid or has expired')) {
    return AuthErrorPresentation(message: l10n.authErrorLinkExpired);
  }

  if (code == 'over_email_send_rate_limit' || raw.contains('rate limit')) {
    return AuthErrorPresentation(message: l10n.authErrorRateLimit);
  }

  if (code == 'invalid_credentials' ||
      raw.contains('invalid login credentials') ||
      raw.contains('email or password is incorrect')) {
    return AuthErrorPresentation(message: l10n.authErrorInvalidCredentials);
  }

  return null;
}
