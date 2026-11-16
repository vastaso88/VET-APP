import '../../pets/domain/pet_models.dart';
import 'travel_card.dart';

/// The travel species of one of the owner's pets, or null when the pet is of a
/// species without cards in this version (only dog, cat and ferret). Read on
/// the phone: the pet itself never goes to the server.
TravelSpecies? travelSpeciesOfPet(PetProfile pet) {
  switch (pet.species.trim().toLowerCase()) {
    case 'cane':
      return TravelSpecies.dog;
    case 'gatto':
      return TravelSpecies.cat;
    case 'piccoli mammiferi':
      // The app files a ferret under "Piccoli mammiferi", with its breed.
      return pet.breed.trim().toLowerCase().startsWith('furetto') ? TravelSpecies.ferret : null;
    default:
      return null;
  }
}
