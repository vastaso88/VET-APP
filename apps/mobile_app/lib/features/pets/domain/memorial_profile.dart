import 'pet_models.dart';

/// The app-side twin of `ricordi_profile_read_only` (scripts/setup/
/// ricordi_animali.sql): while a pet stays in Ricordi only the date of the
/// loss and the three memory reminders can change; anything else in [next]
/// is dropped and [stored] wins. Silently, by choice (docs/product/17 §14.4):
/// no screen offers to edit a memory's profile, and a background save (the
/// latest weighing, a profile photo) must neither fail nor show a change the
/// database will not keep.
PetProfile keepMemorialReadOnly(PetProfile stored, PetProfile next) {
  if (!stored.isMemorial || !next.isMemorial) return next;
  final loss = next.memorialDate;
  return stored.copyWith(
    memorialDate: loss,
    clearMemorialDate: loss == null,
    memorialBirthdayReminder: next.memorialBirthdayReminder,
    memorialWalksReminder: next.memorialWalksReminder,
    memorialPhotosReminder: next.memorialPhotosReminder,
  );
}
