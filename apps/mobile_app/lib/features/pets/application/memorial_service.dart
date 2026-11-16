import 'dart:async';

import '../../billing/data/billing_demo_store.dart';
import '../../billing/domain/billing_models.dart';
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

/// A pet cannot come back from Ricordi: the plan's places are all taken by
/// active pets (owner decision 2026-11-16: pets in Ricordi do not count, and
/// bringing one back needs a free place). Nothing was changed: the pet is
/// still in Ricordi.
class PetLimitBlocksRestore implements Exception {
  const PetLimitBlocksRestore({required this.limit, this.upgradePlan});

  /// The plan's maximum number of pets.
  final int limit;

  /// The plan above ("Pro", "Ultra") to suggest, or null when there is none to
  /// suggest: Ultra, the free trial and the public test.
  final String? upgradePlan;
}

/// A pet cannot be moved to Ricordi: the account already keeps as many there as
/// the backend's setting allows (owner decision 2026-11-16: 30, MEMORIAL_PETS_MAX).
/// Nothing was changed: the pet is still among the active ones. Deleting one from
/// Ricordi frees a place.
class MemoriesFullBlocksMove implements Exception {
  const MemoriesFullBlocksMove({required this.limit});

  /// How many pets Ricordi can hold.
  final int limit;
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
    ({int? limit, String? upgradePlan}) Function()? planLimit,
    int? Function()? memorialLimit,
  })  : _store = store ?? PetDemoStore.instance,
        _planLimit = planLimit ?? _currentPlanLimit,
        _memorialLimit = memorialLimit ?? _currentMemorialLimit,
        _stopWalkOf = stopWalkOf ?? _stopActiveWalkOf,
        _revokeRecordsConsent = revokeRecordsConsent ?? _revokeConsentRemotely,
        _onMoved = onMoved ?? _refreshAfterMove,
        _onRestored = onRestored ?? _refreshAfterRestore;

  final PetDemoStore _store;
  final Future<void> Function(String petId) _stopWalkOf;
  final Future<void> Function(String petId) _revokeRecordsConsent;
  final void Function(String petId) _onMoved;
  final void Function() _onRestored;
  final ({int? limit, String? upgradePlan}) Function() _planLimit;
  final int? Function() _memorialLimit;

  /// How many pets Ricordi can hold, as the backend reports it (null: not known
  /// yet, the server decides).
  static int? _currentMemorialLimit() => BillingDemoStore.instance.memorialPetsMax;

  /// The plan's maximum number of pets (null: no limit, or not known yet: the
  /// server decides) and the plan to suggest when it is full.
  static ({int? limit, String? upgradePlan}) _currentPlanLimit() {
    final billing = BillingDemoStore.instance;
    final limit = billing.currentLimits?.maxPets;
    // The free trial and the public test have no plan above to move to.
    final upgrade = (billing.isOnTrial || billing.isTestPeriod)
        ? null
        : switch (billing.currentTier) {
            PlanTier.plus => 'Pro',
            PlanTier.pro => 'Ultra',
            _ => null,
          };
    return (limit: limit, upgradePlan: upgrade);
  }

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

  /// Throws [MemoriesFullBlocksMove] when Ricordi already holds as many pets as it
  /// may. Asked BEFORE the farewell flow opens, so nobody fills in a date for a
  /// move that cannot happen; [moveToMemories] asks again, and the server has the
  /// last word.
  void ensureRoomInMemories() {
    final cap = _memorialLimit();
    if (cap != null && _store.memorialPets().length >= cap) {
      throw MemoriesFullBlocksMove(limit: cap);
    }
  }

  /// Moves [pet] to Ricordi with the date of the loss. Returns the saved
  /// profile; false from the store (not synced) still keeps it on this phone,
  /// flagged like any unsynced pet. With Ricordi full it throws
  /// [MemoriesFullBlocksMove] and changes nothing (if the full house is known
  /// to the server only, the store puts the pet back first).
  Future<PetProfile> moveToMemories(
    PetProfile pet, {
    required DateTime lossDate,
    MemorialReminderChoices choices = const MemorialReminderChoices(),
  }) async {
    ensureRoomInMemories();
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
    final saved = await _store.upsert(moved, revertOnPlanLimit: pet);
    if (!saved.isMemorial) {
      // The server refused: Ricordi is full there (its count wins).
      throw MemoriesFullBlocksMove(
        limit: _store.lastPlanRefusalLimit ??
            _memorialLimit() ??
            _store.memorialPets().length,
      );
    }
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
  ///
  /// Needs a free place in the plan: pets in Ricordi do not count, active ones
  /// do. With the places all taken it throws [PetLimitBlocksRestore] BEFORE
  /// changing anything, and the pet stays in Ricordi. If the plan is full on
  /// the server only (the app's count was out of date) the store puts the pet
  /// back and the same exception is thrown.
  Future<PetProfile> restore(PetProfile pet) async {
    final plan = _planLimit();
    final limit = plan.limit;
    if (limit != null && _store.list().length >= limit) {
      throw PetLimitBlocksRestore(limit: limit, upgradePlan: plan.upgradePlan);
    }
    final restored = pet.copyWith(
      isMemorial: false,
      clearMemorialDate: true,
      memorialBirthdayReminder: false,
      memorialWalksReminder: false,
      memorialPhotosReminder: false,
    );
    final saved = await _store.upsert(restored, revertOnPlanLimit: pet);
    if (saved.isMemorial) {
      // The server refused: the plan is full there (its count wins).
      throw PetLimitBlocksRestore(
        limit: limit ?? _store.list().length,
        upgradePlan: plan.upgradePlan,
      );
    }
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
