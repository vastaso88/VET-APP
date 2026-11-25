import '../data/pet_demo_store.dart';
import '../data/pet_photo_repository.dart';
import '../domain/pet_models.dart';

/// The photo that becomes the face of [pet] by itself: the newest of its
/// gallery, when it has no face and none of its photos was ever chosen as one.
/// A face taken away ("Rimuovi foto") stays away: its photo still says it was
/// chosen. [photos] come newest first.
PetPhotoEntry? faceToAdopt(PetProfile pet, List<PetPhotoEntry> photos) {
  if (pet.isMemorial || pet.photoPath != null || pet.photoBytes != null) return null;
  if (photos.any((photo) => photo.isProfile)) return null;
  return photos.where((photo) => !photo.isVideo).firstOrNull;
}

/// Gives the animal the face of [faceToAdopt], if there is one. Best effort:
/// without network the photos stay where they are, and it is tried again at the
/// next visit.
Future<void> adoptFace(String petId, {List<PetPhotoEntry>? photos}) async {
  try {
    final repository = PetPhotoRepository();
    final entries = photos ?? await repository.list(petId);
    final pet = PetDemoStore.instance.byId(petId);
    final face = pet == null ? null : faceToAdopt(pet, entries);
    if (face == null) return;
    await repository.setProfile(face);
    PetDemoStore.instance.setPhotoLocal(petId, face.storagePath);
  } catch (_) {
    // See above.
  }
}
