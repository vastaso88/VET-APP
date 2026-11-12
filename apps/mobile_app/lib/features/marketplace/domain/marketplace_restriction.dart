import '../../../l10n/date_formats.dart';
import '../../../l10n/l10n.dart';

/// The moderation team kept this owner out of the Mercatino: no new ads, no
/// edits, no messages. Reading and reporting stay open. Only the reason code and
/// the date reach the app; the team's own notes stay in the portal.
class MarketplaceRestriction {
  const MarketplaceRestriction({required this.reason, required this.since});

  /// From `GET /marketplace/restriction` or a 403 `marketplace_restricted`.
  /// Null when the owner is not restricted.
  static MarketplaceRestriction? fromJson(Map<String, dynamic> json) {
    final restricted = json['restricted'] == true || json['code'] == 'marketplace_restricted';
    if (!restricted) return null;
    return MarketplaceRestriction(
      reason: json['reason'] as String? ?? 'other',
      since: DateTime.tryParse(json['since'] as String? ?? '') ?? DateTime.now(),
    );
  }

  final String reason;
  final DateTime since;

  /// The whole explanation, in the owner's language, with the way to ask for a
  /// review (DSA art. 17): the same "Contattaci" of the Settings, whose address
  /// comes from the backend, so it is never written twice.
  String message([AppLocalizations? l10n]) {
    final strings = l10n ?? appL10n;
    final notice = strings.marketplaceRestrictedNotice(
      formatAppDate(since.toLocal(), 'd MMM y'),
      _reasonLabel(strings),
    );
    final appeal = strings.marketplaceRestrictedAppeal(
      '${strings.settingsTitle} → ${strings.settingsContactUs}',
    );
    return '$notice $appeal';
  }

  String _reasonLabel(AppLocalizations strings) => switch (reason) {
        'spam' => strings.marketplaceRestrictionReasonSpam,
        'scam' => strings.marketplaceRestrictionReasonScam,
        'harassment' => strings.marketplaceRestrictionReasonHarassment,
        'prohibited_items' => strings.marketplaceRestrictionReasonProhibitedItems,
        _ => strings.marketplaceRestrictionReasonOther,
      };
}
