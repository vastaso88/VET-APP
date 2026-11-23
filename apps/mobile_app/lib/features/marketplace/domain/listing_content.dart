import '../../../l10n/date_formats.dart';
import '../../../l10n/l10n.dart';

/// The two notices of the backend about the text of an ad (owner decisions of
/// 2026-11-23, docs/compliance/24). Which words call for them is decided by the
/// backend alone: the app has no list of its own.
enum ListingContentNotice {
  food('food'),
  activeSubstance('active_substance');

  const ListingContentNotice(this.wire);

  final String wire;

  static ListingContentNotice? fromWire(String? value) {
    for (final notice in values) {
      if (notice.wire == value) return notice;
    }
    return null;
  }
}

/// The ad names food, supplements or something that may hold active ingredients:
/// the backend publishes it only once the seller has ticked a box for each of
/// [notices].
class ListingConfirmationRequiredException implements Exception {
  const ListingConfirmationRequiredException({required this.notices, required this.words});

  /// From the 400 `content_confirmation_required`. Null when the answer asks for
  /// something this version of the app cannot show.
  static ListingConfirmationRequiredException? fromJson(Map<String, dynamic> json) {
    if (json['code'] != 'content_confirmation_required') return null;
    final fix = json['fix'];
    if (fix is! Map<String, dynamic>) return null;
    final wanted = fix['value'];
    if (wanted is! List<dynamic> || wanted.isEmpty) return null;
    final notices = <ListingContentNotice>[];
    for (final value in wanted) {
      final notice = ListingContentNotice.fromWire(value?.toString());
      if (notice == null) return null;
      notices.add(notice);
    }
    final words = <ListingContentNotice, List<String>>{};
    final terms = fix['terms'];
    for (final term in terms is List<dynamic> ? terms : const <dynamic>[]) {
      if (term is! Map<String, dynamic>) continue;
      final notice = ListingContentNotice.fromWire(term['notice']?.toString());
      final text = term['text']?.toString() ?? '';
      if (notice != null && text.isNotEmpty) words.putIfAbsent(notice, () => []).add(text);
    }
    return ListingConfirmationRequiredException(notices: notices, words: words);
  }

  final List<ListingContentNotice> notices;
  final Map<ListingContentNotice, List<String>> words;

  @override
  String toString() => appL10n.marketplaceSaveFailed;
}

/// Who hid the ad: a person of the team, the app after several reports (until the team
/// looks), or the automatic rule on animals.
enum ListingRemovalKind { team, reports, rule }

/// Why the seller's own ad is not visible. Only a reason code, the date and the words the
/// automatic check had found reach the app: never who reported it or who decided.
class ListingRemoval {
  const ListingRemoval({
    required this.reason,
    required this.decidedAt,
    this.words = const [],
    this.kind = ListingRemovalKind.team,
  });

  static ListingRemoval? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final decidedAt = DateTime.tryParse((json['decided_at'] ?? '').toString());
    if (decidedAt == null) return null;
    return ListingRemoval(
      reason: (json['reason'] ?? 'other').toString(),
      decidedAt: decidedAt,
      words: (json['terms'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      kind: switch (json['kind']) {
        'reports' => ListingRemovalKind.reports,
        'rule' => ListingRemovalKind.rule,
        _ => ListingRemovalKind.team,
      },
    );
  }

  final String reason;
  final DateTime decidedAt;
  final List<String> words;
  final ListingRemovalKind kind;

  /// What happened, why, that the detection was automatic, and how to ask for a
  /// review (DSA art. 17).
  String message([AppLocalizations? l10n]) {
    final strings = l10n ?? appL10n;
    final date = formatAppDate(decidedAt.toLocal(), 'd MMM y');
    return [
      ...switch (kind) {
        ListingRemovalKind.team => [
            strings.marketplaceRemovedNotice(date, _reasonLabel(strings)),
            if (words.isNotEmpty) strings.marketplaceRemovedDetection(words.join(', ')),
          ],
        ListingRemovalKind.reports => [strings.marketplaceHiddenAutoNotice(date)],
        ListingRemovalKind.rule => [
            strings.marketplaceHiddenAnimalNotice(date),
            if (words.isNotEmpty) '${strings.marketplaceContentFoundWords(words.join(', '))}.',
          ],
      },
      listingAppeal(strings),
    ].join(' ');
  }

  String _reasonLabel(AppLocalizations strings) => switch (reason) {
        'food' => strings.marketplaceRemovedReasonFood,
        'supplement' => strings.marketplaceRemovedReasonSupplement,
        'medicine' => strings.marketplaceRemovedReasonMedicine,
        'spam' => strings.marketplaceRemovedReasonSpam,
        'scam' => strings.marketplaceRemovedReasonScam,
        'prohibited_item' => strings.marketplaceRemovedReasonProhibitedItem,
        'inappropriate' => strings.marketplaceRemovedReasonInappropriate,
        'sells_animals' => strings.marketplaceRemovedReasonSellsAnimals,
        _ => strings.marketplaceRemovedReasonOther,
      };
}

/// A medicine or a product with active ingredients: what was found, that the check is
/// automatic and can be wrong, how to ask for a review.
String refusedMedicineMessage(AppLocalizations strings, List<String> words) => [
      strings.marketplaceNoMedicinesMessage,
      if (words.isNotEmpty) '${strings.marketplaceContentFoundWords(words.join(', '))}.',
      strings.marketplaceContentAutomatic,
      listingAppeal(strings),
    ].join(' ');

/// How to ask for a review: the "Contattaci" of the Settings.
String listingAppeal(AppLocalizations strings) => strings.marketplaceRemovedAppeal(
      '${strings.settingsTitle} → ${strings.settingsContactUs}',
    );
