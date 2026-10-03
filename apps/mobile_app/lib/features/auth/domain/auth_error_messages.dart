import '../../../shared/errors/app_error.dart';

enum AuthErrorField { email, password }

class AuthErrorPresentation {
  const AuthErrorPresentation({required this.message, this.field});

  final String message;
  final AuthErrorField? field;
}

/// Maps Supabase/network errors to Italian copy. [field] tells the form
/// which input to show the message under; null means a general banner.
AuthErrorPresentation presentAuthError(AppError error) {
  final code = error.code.toLowerCase();
  final raw = error.message.toLowerCase();

  if (code == 'user_already_exists' ||
      code == 'email_exists' ||
      raw.contains('user already registered') ||
      raw.contains('already registered')) {
    return const AuthErrorPresentation(
      message: 'Esiste già un account con questa email. Prova ad accedere.',
      field: AuthErrorField.email,
    );
  }

  if (code == 'weak_password' || raw.contains('password should be') || raw.contains('weak')) {
    return const AuthErrorPresentation(
      message: 'La password è troppo debole: usa almeno 6 caratteri, meglio se con numeri o lettere maiuscole.',
      field: AuthErrorField.password,
    );
  }

  if (code == 'email_address_invalid' ||
      code == 'validation_failed' ||
      raw.contains('invalid format') ||
      raw.contains('unable to validate email')) {
    return const AuthErrorPresentation(
      message: "L'indirizzo email non sembra valido.",
      field: AuthErrorField.email,
    );
  }

  if (raw.contains('socketexception') ||
      raw.contains('failed host lookup') ||
      raw.contains('clientexception') ||
      raw.contains('network') ||
      raw.contains('connection') ||
      code == 'network') {
    return const AuthErrorPresentation(
      message: 'Nessuna connessione. Controlla la rete e riprova.',
    );
  }

  if (code == 'otp_expired' || raw.contains('expired') || raw.contains('invalid or has expired')) {
    return const AuthErrorPresentation(
      message: 'Il link non è più valido o è già stato usato. Richiedine uno nuovo dalla schermata di recupero.',
    );
  }

  if (code == 'over_email_send_rate_limit' || raw.contains('rate limit')) {
    return const AuthErrorPresentation(
      message: 'Hai richiesto troppe email in poco tempo. Aspetta qualche minuto e riprova.',
    );
  }

  if (code == 'invalid_credentials' || raw.contains('invalid login credentials')) {
    return const AuthErrorPresentation(
      message: 'Email o password non corrette.',
    );
  }

  return const AuthErrorPresentation(
    message: 'Qualcosa non è andato come previsto. Riprova tra poco.',
  );
}
