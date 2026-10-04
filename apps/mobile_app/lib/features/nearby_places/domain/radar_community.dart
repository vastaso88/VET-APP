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
  });

  final String reportId;
  final bool isPending;

  /// Confirmations net of denials, out of [required].
  final int confirmations;
  final int required;

  /// +1 confirmed, -1 denied, null not voted.
  final int? viewerVote;
  final bool viewerIsReporter;

  String get progressLabel => '$confirmations/$required';

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
  closed('closed', 'Ha chiuso o non esiste più'),
  duplicate('duplicate', 'È un doppione di un altro luogo'),
  wrongPosition('wrong_position', 'La posizione è sbagliata');

  const RadarProblem(this.apiValue, this.label);

  final String apiValue;
  final String label;
}
