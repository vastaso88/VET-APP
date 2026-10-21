import '../../pets/domain/pet_models.dart';

/// The species the app can explain how to assess the body condition of: only
/// those with a published, peer-reviewed or society-issued reference. For
/// every other species there is no "corporatura" at all (no free choice from
/// the owner either): see docs/monitoring/corporatura_fonti.md.
enum BodyConditionGuideKind {
  dog,
  cat,
  rabbit;

  /// The reference the guide is based on, shown at the bottom of the popup.
  String get sourceKey => name;
}

/// The guide of a species / breed as stored in the pet profile (species is
/// the Italian label, rabbits are a breed of "Piccoli mammiferi"), or null
/// when the species has no reference: then there is no body condition.
BodyConditionGuideKind? bodyConditionGuideForSpecies(
  String? species, {
  String? breed,
}) {
  switch (species?.trim().toLowerCase()) {
    case 'cane':
      return BodyConditionGuideKind.dog;
    case 'gatto':
      return BodyConditionGuideKind.cat;
    case 'piccoli mammiferi':
      final name = (breed ?? '').trim().toLowerCase();
      return name.startsWith('coniglio')
          ? BodyConditionGuideKind.rabbit
          : null;
  }
  return null;
}

BodyConditionGuideKind? bodyConditionGuideFor(PetProfile pet) =>
    pet.isAquarium
        ? null
        : bodyConditionGuideForSpecies(pet.species, breed: pet.breed);

/// Whether the body condition exists for this pet at all (profile, weighings,
/// "Dati animale" and chat all follow this one rule).
bool supportsBodyCondition(PetProfile pet) => bodyConditionGuideFor(pet) != null;
