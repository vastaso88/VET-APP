import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/presentation/pages/legal_text_page.dart';
import '../../features/account_consents/domain/account_consent_models.dart';
import '../../l10n/l10n.dart';

/// The activities that open with a short notice (privacy notice art. 13, at the
/// moment of use). Not consents: no version, no switch. The chat has its own
/// screen instead (ChatNotice).
enum ShortNotice {
  /// A document added to a medical record.
  recordDocument('record_document'),

  /// First walk: what is kept of the route.
  firstWalk('first_walk'),

  /// First opening of the Mercatino: adults only, two private parties, when the
  /// team reads a conversation. Links to the Terms (Mercatino rules).
  marketplace('marketplace');

  const ShortNotice(this.id);

  final String id;

  String text(BuildContext context) {
    final l10n = context.l10n;
    return switch (this) {
      recordDocument => l10n.noticeRecordDocument,
      firstWalk => l10n.noticeFirstWalk,
      marketplace => l10n.noticeMarketplace,
    };
  }

  /// What the second button opens: the Terms for the Mercatino, the privacy
  /// notice for everything else.
  String get linkConsentKey =>
      this == marketplace ? AccountConsentKeys.termsOfService : AccountConsentKeys.privacyPolicy;

  String linkLabel(BuildContext context) =>
      this == marketplace ? context.l10n.noticeRules : context.l10n.noticePolicy;
}

/// Remembers, on this phone, which notices were already acknowledged. Emptied
/// when the owner signs out, like every other local store.
class ShortNoticeStore {
  ShortNoticeStore._();

  static final ShortNoticeStore instance = ShortNoticeStore._();

  static const _prefix = 'vet_app.short_notice.';

  Future<bool> wasSeen(ShortNotice notice) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      return preferences.getBool('$_prefix${notice.id}') ?? false;
    } catch (_) {
      // Unreadable: better to say it once more than to skip it.
      return false;
    }
  }

  Future<void> markSeen(ShortNotice notice) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool('$_prefix${notice.id}', true);
    } catch (_) {}
  }

  Future<void> clear() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      for (final key in preferences.getKeys().where((key) => key.startsWith(_prefix)).toList()) {
        await preferences.remove(key);
      }
    } catch (_) {}
  }
}

/// Shows [notice] the first time, then never again on this phone ("Ho capito"). One that
/// was left without acknowledging it comes back next time.
Future<void> showShortNoticeOnce(BuildContext context, ShortNotice notice) async {
  if (await ShortNoticeStore.instance.wasSeen(notice)) return;
  if (!context.mounted) return;
  final understood = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      content: Text(notice.text(dialogContext)),
      actions: [
        TextButton(
          key: const ValueKey('short-notice-policy'),
          onPressed: () => Navigator.of(dialogContext).push(
            MaterialPageRoute<void>(
              builder: (_) => LegalTextPage(
                consentKey: notice.linkConsentKey,
                title: notice.linkLabel(dialogContext),
              ),
            ),
          ),
          child: Text(notice.linkLabel(dialogContext)),
        ),
        TextButton(
          key: const ValueKey('short-notice-ok'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(dialogContext.l10n.noticeUnderstood),
        ),
      ],
    ),
  );
  if (understood == true) await ShortNoticeStore.instance.markSeen(notice);
}
