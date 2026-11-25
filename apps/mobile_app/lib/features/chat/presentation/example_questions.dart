import '../../../l10n/l10n.dart';
import '../../pets/domain/pet_details.dart';
import '../../pets/domain/pet_models.dart';

/// Three questions an empty chat offers to start from, by kind of animal: why
/// it does something, how to live with it, what it needs. Never an emergency,
/// a medicine or a dose. A tap only writes the question in the field.
List<String> exampleQuestionsFor(
  AppLocalizations l10n, {
  required String petName,
  PetProfile? pet,
}) {
  return switch (petKindOf(pet?.species, pet?.breed)) {
    PetKind.dog => [
        l10n.chatExampleLeash(petName),
        l10n.chatExampleBored(petName),
        l10n.chatExampleDuties(petName),
      ],
    PetKind.cat => [
        l10n.chatExampleScratching(petName),
        l10n.chatExamplePlayIndoors(petName),
        l10n.chatExampleLitterBox,
      ],
    PetKind.rabbit => [
        l10n.chatExampleThumping(petName),
        l10n.chatExampleSpace(petName),
        l10n.chatExampleTrust(petName),
      ],
    PetKind.smallMammal => [
        l10n.chatExampleBored(petName),
        l10n.chatExampleSpace(petName),
        l10n.chatExampleTrust(petName),
      ],
    PetKind.bird => [
        l10n.chatExampleSounds(petName),
        l10n.chatExampleSpace(petName),
        l10n.chatExampleTrust(petName),
      ],
    PetKind.reptile || PetKind.amphibian => [
        l10n.chatExampleHiding(petName),
        l10n.chatExampleHabitat(petName),
        l10n.chatExampleSpace(petName),
      ],
    // The "pet" may be a whole tank: no name in the questions.
    PetKind.fish => [
        l10n.chatExampleTankWater,
        l10n.chatExampleTankMates,
        l10n.chatExampleTankPlants,
      ],
    PetKind.largeMammal || PetKind.invertebrate || PetKind.unknown => [
        l10n.chatExampleHabitat(petName),
        l10n.chatExampleSpace(petName),
        l10n.chatExampleDuties(petName),
      ],
  };
}
