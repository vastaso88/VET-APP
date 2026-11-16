import '../../pets/domain/pet_models.dart';
import '../data/reminders_repository.dart';

/// Ricordi (docs/product/17_ricordi_animali.md §4): everything about a living
/// pet stops at once and silently when it is moved to Ricordi. Its reminders
/// and courses are NOT deleted or marked done — they are only hidden from
/// Home, the reminders list, the "Fatto?" prompt and the notifications, so
/// bringing the pet back restores them as they were.
///
/// [pets] must include the pets in Ricordi (`list(includeMemorial: true)`).
bool reminderBelongsToMemorialPet(
  ReminderEntry reminder,
  Iterable<PetProfile> pets,
) {
  final petId = reminder.petId;
  if (petId != null) {
    for (final pet in pets) {
      if (pet.id == petId) return pet.isMemorial;
    }
  }
  // No id (a reminder just created on this phone) or an unknown id: by name.
  // An active pet with the same name wins, so its reminders never vanish.
  final name = reminder.petName.trim().toLowerCase();
  var memorialNamed = false;
  for (final pet in pets) {
    if (pet.name.trim().toLowerCase() != name) continue;
    if (!pet.isMemorial) return false;
    memorialNamed = true;
  }
  return memorialNamed;
}

/// [reminders] without those of pets in Ricordi.
List<ReminderEntry> remindersOfActivePets(
  Iterable<ReminderEntry> reminders,
  Iterable<PetProfile> pets,
) {
  final petList = pets.toList(growable: false);
  if (!petList.any((pet) => pet.isMemorial)) return reminders.toList();
  return [
    for (final reminder in reminders)
      if (!reminderBelongsToMemorialPet(reminder, petList)) reminder,
  ];
}
