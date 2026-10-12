import '../../../l10n/date_formats.dart';
import '../../../l10n/l10n.dart';

/// State of a "Segnala!" report as the backend shows it to this viewer.
/// Never says who reported or voted: only what the viewer themself did.
class RadarReportInfo {
  const RadarReportInfo({
    required this.reportId,
    required this.isPending,
    required this.confirmations,
    required this.required,
    this.viewerVote,
    this.viewerIsReporter = false,
    this.expiresInDays,
  });

  final String reportId;
  final bool isPending;

  /// Confirmations net of denials, out of [required].
  final int confirmations;
  final int required;

  /// +1 confirmed, -1 denied, null not voted.
  final int? viewerVote;
  final bool viewerIsReporter;

  /// Days before the report is dropped because nobody confirmed it; null
  /// once it has a confirmation.
  final int? expiresInDays;

  String get progressLabel => '$confirmations/$required';

  /// "Scade tra N giorni se nessuno conferma", or null when it does not expire.
  String? get expiryLabel => switch (expiresInDays) {
        null => null,
        0 => appL10n.placesExpiryToday,
        final days => appL10n.placesExpiryDays(days),
      };

  static RadarReportInfo? tryFromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      return null;
    }
    final reportId = json['report_id'] as String?;
    if (reportId == null) {
      return null;
    }
    return RadarReportInfo(
      reportId: reportId,
      isPending: json['status'] == 'pending',
      confirmations: (json['confirmations'] as num?)?.toInt() ?? 0,
      required: (json['required'] as num?)?.toInt() ?? 5,
      viewerVote: (json['viewer_vote'] as num?)?.toInt(),
      viewerIsReporter: json['viewer_is_reporter'] == true,
      expiresInDays: (json['expires_in_days'] as num?)?.toInt(),
    );
  }
}

/// Star rating of a public dog park. [average] stays null until enough
/// people voted for it to mean something.
class RadarRating {
  const RadarRating({required this.count, this.average, this.viewerStars});

  final int count;
  final double? average;
  final int? viewerStars;

  /// This rating with the viewer's vote set to [stars]: used to show a
  /// vote just given on a card whose data was loaded before it.
  RadarRating withViewerStars(int? stars) => stars == null
      ? this
      : RadarRating(
          count: viewerStars == null ? count + 1 : count,
          average: average,
          viewerStars: stars,
        );

  /// The community's vote in words. Below the threshold only how many
  /// voted is said, never what a single person gave.
  String get communityLabel {
    final l10n = appL10n;
    final votes = l10n.placesVotesCount(count);
    final average = this.average;
    if (average != null) {
      return l10n.placesRatingAverage(
        average.toStringAsFixed(1).replaceAll('.', appDecimalSeparator()),
        votes,
      );
    }
    return count == 0 ? l10n.placesRatingNone : l10n.placesRatingBelowThreshold(votes);
  }

  static RadarRating? tryFromJson(Object? json) {
    if (json is! Map<String, dynamic> || json['can_rate'] != true) {
      return null;
    }
    return RadarRating(
      count: (json['count'] as num?)?.toInt() ?? 0,
      average: (json['average'] as num?)?.toDouble(),
      viewerStars: (json['viewer_stars'] as num?)?.toInt(),
    );
  }
}

/// What can be reported about an existing place.
enum RadarProblem {
  closed('closed'),
  duplicate('duplicate'),
  wrongPosition('wrong_position');

  const RadarProblem(this.apiValue);

  final String apiValue;

  String get label {
    final l10n = appL10n;
    switch (this) {
      case RadarProblem.closed:
        return l10n.placesProblemClosed;
      case RadarProblem.duplicate:
        return l10n.placesProblemDuplicate;
      case RadarProblem.wrongPosition:
        return l10n.placesProblemWrongPosition;
    }
  }
}
