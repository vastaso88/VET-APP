class AuthEmailPasswordCredentials {
  const AuthEmailPasswordCredentials({
    required this.email,
    required this.password,
  });

  final String email;
  final String password;
}

class AuthSignUpRequest {
  const AuthSignUpRequest({
    required this.email,
    required this.password,
    this.displayName,
    this.phone,
  });

  final String email;
  final String password;
  final String? displayName;

  /// Optional, E.164 ("+393331234567"); kept in the account's metadata.
  final String? phone;
}
