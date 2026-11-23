import '../../../shared/errors/app_error.dart';

/// The problem of an e-mail link that was opened and did not work (used, expired, opened on
/// another device). The auth listener in `bootstrap.dart` records it; the sign-in screen
/// shows it once, in plain words, and forgets it. Holds only the error, never the link.
class AuthLinkNotice {
  AuthLinkNotice._();

  static final AuthLinkNotice instance = AuthLinkNotice._();

  AppError? _pending;

  void record(AppError error) => _pending = error;

  /// The recorded problem, once: reading it clears it.
  AppError? take() {
    final error = _pending;
    _pending = null;
    return error;
  }
}
