import 'dart:async';

import '../../dog_walks/data/active_walk_controller.dart';
import '../../notifications/application/notification_scheduler.dart';
import '../../reminders/data/reminders_repository.dart';
import '../data/medical_record_consent_remote_data_source.dart';
import '../data/pet_demo_store.dart';
import '../domain/pet_models.dart';

/// The memory reminders the owner chose for a pet in Ricordi (doc 17 §5).
class MemorialReminderChoices {
  const MemorialReminderChoices({
    this.birthday = false,
    this.walks = false,
    this.photos = false,
  });

  final bool birthday;
  final bool walks;
  final bool photos;
}

/// Moving a pet to Ricordi and back (docs/product/17_ricordi_animali.md).
///
/// Moving stops at once and silently everything about a living pet: a walk
/// in progress is closed and saved, reminders and courses disappear from
/// Home/lists/notifications (they are kept, see memorial_reminders.dart),
/// notifications already in the shade are removed, and the chat stops
/// reading its clinical records (consent switched off, compliance doc 17
/// §B.2 point 4). Nothing is deleted, so [restore] undoes it — except the
/// consent, which the chat asks for again like for a new pet.
class MemorialService {
  MemorialService({
    PetDemoStore? store,
    Future<void> Function(String petId)? stopWalkOf,
    Future<void> Function(String petId)? revokeRecordsConsent,
    void Function(String petId)? onMoved,
    void Function()? onRestored,
  })  : _store = store ?? PetDemoStore.instance,
        _stopWalkOf = stopWalkOf ?? _stopActiveWalkOf,
        _revokeRecordsConsent = revokeRecordsConsent ?? _revokeConsentRemotely,
        _onMoved = onMoved ?? _refreshAfterMove,
        _onRestored = onRestored ?? _refreshAfterRestore;

  final PetDemoStore _store;
  final Future<void> Function(String petId) _stopWalkOf;
  final Future<void> Function(String petId) _revokeRecordsConsent;
  final void Function(String petId) _onMoved;
  final void Function() _onRestored;

  static Future<void> _stopActiveWalkOf(String petId) async {
    final walks = ActiveWalkController.instance;
    if (walks.isActive && walks.activePetId == petId) await walks.stop();
  }

  static Future<void> _revokeConsentRemotely(String petId) async {
    await MedicalRecordConsentRemoteDataSource().setGranted(
      petId: petId,
      granted: false,
    );
  }

  static void _refreshAfterMove(String petId) {
    RemindersRepository.changes.value++;
    unawaited(NotificationScheduler.instance.forgetPet(petId));
  }

  static void _refreshAfterRestore() {
    RemindersRepository.changes.value++;
    NotificationScheduler.instance.requestResync();
  }

  /// Moves [pet] to Ricordi with the date of the loss. Returns the saved
  /// profile; false from the store (not synced) still keeps it on this phone,
  /// flagged like any unsynced pet.
  Future<PetProfile> moveToMemories(
    PetProfile pet, {
    required DateTime lossDate,
    MemorialReminderChoices choices = const MemorialReminderChoices(),
  }) async {
    await _stopWalkOf(pet.id);
    final hadConsent = pet.medicalRecordConsentGranted == true;
    final moved = pet.copyWith(
      isMemorial: true,
      memorialDate: DateTime(lossDate.year, lossDate.month, lossDate.day),
      memorialBirthdayReminder: choices.birthday,
      memorialWalksReminder: choices.walks,
      memorialPhotosReminder: choices.photos,
      medicalRecordConsentGranted: hadConsent ? false : null,
    );
    await _store.upsert(moved);
    _onMoved(pet.id);
    if (hadConsent) {
      // Best effort: the pet is already in Ricordi; a failed call leaves the
      // consent on the server, which the chat never reaches for this pet
      // anyway (no new conversation can be started about it).
      try {
        await _revokeRecordsConsent(pet.id);
      } catch (_) {}
    }
    return moved;
  }

  /// Brings [pet] back to the Animali list, as it was before Ricordi: the
  /// date of the loss and the memory reminders are cleared.
  Future<PetProfile> restore(PetProfile pet) async {
    final restored = pet.copyWith(
      isMemorial: false,
      clearMemorialDate: true,
      memorialBirthdayReminder: false,
      memorialWalksReminder: false,
      memorialPhotosReminder: false,
    );
    await _store.upsert(restored);
    _onRestored();
    return restored;
  }

  /// Saves the memory reminders switched on or off on the memorial page.
  Future<PetProfile> updateChoices(
    PetProfile pet,
    MemorialReminderChoices choices,
  ) async {
    final updated = pet.copyWith(
      memorialBirthdayReminder: choices.birthday,
      memorialWalksReminder: choices.walks,
      memorialPhotosReminder: choices.photos,
    );
    await _store.upsert(updated);
    NotificationScheduler.instance.requestResync();
    return updated;
  }
}
