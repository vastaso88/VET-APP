/// How old the owner declared they are, as far as the app may know: a band,
/// never the date (the backend does not send it back).
enum AgeBand {
  unknown,
  underMinimum,
  minor,
  adult;

  static AgeBand fromName(String? name) => switch (name) {
        'under_minimum' => AgeBand.underMinimum,
        'minor' => AgeBand.minor,
        'adult' => AgeBand.adult,
        _ => AgeBand.unknown,
      };
}

/// 403 codes of the paid-plan choice (backend `AgeGateService`).
const kAgeRequiredCode = 'age_required';
const kGuardianRequiredCode = 'guardian_required';

/// The minimum age to have an account (Italy: 14; one constant per country
/// when others open). The backend enforces it; the app only uses it to stop
/// before creating an account.
const kMinimumAge = 14;

/// Full years between [birth] and [today].
int ageOn(DateTime birth, DateTime today) {
  final hadBirthday =
      today.month > birth.month || (today.month == birth.month && today.day >= birth.day);
  return today.year - birth.year - (hadBirthday ? 0 : 1);
}

class AgeStatus {
  const AgeStatus({
    required this.band,
    required this.marketplaceAllowed,
    required this.guardianRequired,
    required this.guardianConfirmed,
    required this.paidPlanAllowed,
    this.supportContactEmail,
  });

  const AgeStatus.unknown()
      : band = AgeBand.unknown,
        marketplaceAllowed = false,
        guardianRequired = false,
        guardianConfirmed = false,
        paidPlanAllowed = false,
        supportContactEmail = null;

  final AgeBand band;
  final bool marketplaceAllowed;

  /// A declared minor must confirm a parent's authorisation before a paid plan.
  final bool guardianRequired;
  final bool guardianConfirmed;
  final bool paidPlanAllowed;

  /// Where to write to correct a mistyped date (comes with the status, because a
  /// closed account cannot reach the other routes). Null when not configured.
  final String? supportContactEmail;

  factory AgeStatus.fromJson(Map<String, dynamic> json) => AgeStatus(
        band: AgeBand.fromName(json['band'] as String?),
        marketplaceAllowed: json['marketplace_allowed'] == true,
        guardianRequired: json['guardian_required'] == true,
        guardianConfirmed: json['guardian_confirmed'] == true,
        paidPlanAllowed: json['paid_plan_allowed'] == true,
        supportContactEmail: json['support_contact_email'] as String?,
      );
}
