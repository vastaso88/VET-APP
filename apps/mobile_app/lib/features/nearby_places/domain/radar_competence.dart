/// "Esperti in esotici": exotic-animal groups a veterinary practice is
/// declared competent for. Every competence carries its own source and the
/// date it was read (packages/core/domain/radar_places/competences.py);
/// none of them is a judgement by Quokka.
library;

enum ExoticGroup {
  reptileAmphibian('reptile_amphibian'),
  bird('bird'),
  smallMammal('small_mammal'),
  fish('fish'),
  other('other');

  const ExoticGroup(this.apiValue);

  final String apiValue;

  static ExoticGroup? fromApi(String? value) {
    for (final group in ExoticGroup.values) {
      if (group.apiValue == value) return group;
    }
    return null;
  }
}

/// "Exotic animals" with no group named: matches every group.
const exoticGeneralApiValue = 'exotic_general';

/// How a competence was read.
enum CompetenceBasis { osmTag, name, confirmedClaim }

class RadarCompetence {
  const RadarCompetence({
    required this.group,
    required this.basis,
    this.readAt,
    this.evidenceUrl,
  });

  /// Null for a general "exotic animals" declaration.
  final ExoticGroup? group;
  final CompetenceBasis basis;
  final DateTime? readAt;

  /// For a confirmed claim: the practice's own page that was checked.
  final String? evidenceUrl;

  bool get isGeneral => group == null;

  static RadarCompetence? tryFromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final rawGroup = json['group'] as String?;
    final group = ExoticGroup.fromApi(rawGroup);
    if (group == null && rawGroup != exoticGeneralApiValue) return null;
    final basis = switch (json['basis']) {
      'osm_tag' => CompetenceBasis.osmTag,
      'name' => CompetenceBasis.name,
      'confirmed_claim' => CompetenceBasis.confirmedClaim,
      _ => null,
    };
    if (basis == null) return null;
    final evidence = json['evidence_url'];
    return RadarCompetence(
      group: group,
      basis: basis,
      readAt: DateTime.tryParse(json['read_at'] as String? ?? ''),
      evidenceUrl: evidence is String && evidence.isNotEmpty ? evidence : null,
    );
  }
}

/// Whether a practice belongs under [group] (null: any exotic group).
bool matchesExoticGroup(List<RadarCompetence> competences, ExoticGroup? group) {
  if (competences.isEmpty) return false;
  if (group == null) return true;
  return competences.any((item) => item.isGeneral || item.group == group);
}

/// Where the reporter read that a practice treats exotic animals.
enum CompetenceEvidence {
  website('website'),
  sign('sign'),
  other('other');

  const CompetenceEvidence(this.apiValue);

  final String apiValue;
}
