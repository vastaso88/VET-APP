/// Account-level consent keys — mirrors `AccountConsentType`
/// (packages/core/domain/consent/models.py).
class AccountConsentKeys {
  const AccountConsentKeys._();

  static const termsOfService = 'terms_of_service';
  static const privacyPolicy = 'privacy_policy';
  static const marketingEmail = 'marketing_email';
  static const analytics = 'analytics';

  /// "Quokka does not handle emergencies" (docs/compliance/22): its own box, a condition
  /// of the CHAT only, asked when the first chat is opened (see `ChatNotice`).
  static const emergencyNotice = 'emergency_notice';

  /// The version of the short text this build shows (`emergencyNoticeShort`), equal to
  /// `CURRENT_VERSIONS` on the server (a test checks it).
  static const emergencyNoticeVersion = 'v1';

  /// The version of each mandatory text THIS build can show on its own (the fallback when the
  /// server's catalog could not be read). The version sent with an acceptance is the one of the
  /// catalog the owner can really open (`shownVersionFor`); this is only the last resort. Raise
  /// it with `CURRENT_VERSIONS` when the app's own wording changes (a test compares the two).
  static const shownVersions = {
    termsOfService: 'v2',
    privacyPolicy: 'v4',
    emergencyNotice: emergencyNoticeVersion,
  };

  /// The version to declare for [key]: the catalog's (the text the owner can open now), else
  /// this build's own.
  static String? shownVersionFor(AccountConsentsSnapshot? snapshot, String key) =>
      snapshot?.catalog[key]?.version ?? shownVersions[key];

  /// The same, from the versions of a catalog already read.
  static String? shownVersionIn(Map<String, String>? catalogVersions, String key) =>
      catalogVersions?[key] ?? shownVersions[key];

  /// The mandatory keys of the app, equal to `AccountConsentType.MANDATORY` on the server (a
  /// test checks it): while one is missing or at an old version the server answers
  /// `consent_required`.
  static const mandatory = [termsOfService, privacyPolicy];

  /// "Invia rapporti sugli errori": crash reports to Sentry (EU), opt-in.
  static const diagnostics = 'diagnostics';
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
