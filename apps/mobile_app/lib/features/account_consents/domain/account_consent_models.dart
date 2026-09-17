/// Account-level consent keys — mirrors `AccountConsentType`
/// (packages/core/domain/consent/models.py).
class AccountConsentKeys {
  const AccountConsentKeys._();

  static const termsOfService = 'terms_of_service';
  static const privacyPolicy = 'privacy_policy';
  static const marketingEmail = 'marketing_email';
  static const analytics = 'analytics';
}

class ConsentDecision {
  const ConsentDecision({
    required this.granted,
    required this.version,
    required this.decidedAt,
  });

  factory ConsentDecision.fromJson(Map<String, dynamic> json) {
    return ConsentDecision(
      granted: json['granted'] as bool,
      version: json['version'] as String,
      decidedAt: DateTime.parse(json['decided_at'] as String),
    );
  }

  final bool granted;
  final String version;
  final DateTime decidedAt;
}

class ConsentCatalogEntry {
  const ConsentCatalogEntry({required this.version, required this.text});

  factory ConsentCatalogEntry.fromJson(Map<String, dynamic> json) {
    return ConsentCatalogEntry(
      version: json['version'] as String,
      text: json['text'] as String,
    );
  }

  final String version;
  final String text;
}

/// The owner's decisions plus the current text/version for every consent
/// key — see `GetAccountConsentsOutput`
/// (packages/core/application/services/get_account_consents.py). Carrying
/// the catalog alongside the decisions means the legal copy lives only on
/// the backend, never duplicated (and risking drift) in Dart.
class AccountConsentsSnapshot {
  const AccountConsentsSnapshot({required this.decisions, required this.catalog});

  factory AccountConsentsSnapshot.fromJson(Map<String, dynamic> json) {
    final rawConsents = json['account_consents']['consents'] as Map<String, dynamic>;
    final rawCatalog = json['catalog'] as Map<String, dynamic>;
    return AccountConsentsSnapshot(
      decisions: rawConsents.map(
        (key, value) => MapEntry(key, ConsentDecision.fromJson(value as Map<String, dynamic>)),
      ),
      catalog: rawCatalog.map(
        (key, value) =>
            MapEntry(key, ConsentCatalogEntry.fromJson(value as Map<String, dynamic>)),
      ),
    );
  }

  final Map<String, ConsentDecision> decisions;
  final Map<String, ConsentCatalogEntry> catalog;
}
