import '../../medical_records/domain/record_category.dart';
import '../../pets/domain/pet_details.dart';
import '../data/reminders_repository.dart';

/// What a reminder is about. The clinical ones ARE the cartella clinica's
/// categories (same names, same symbols - see `reminder_category_labels.dart`):
/// completing one can write a record into the pet's Storico. The others
/// (grooming, other) are only ticked off, they never become records.
enum ReminderCategory {
  visit,
  exam,
  vaccine,
  therapy,
  grooming,
  other;

  /// What is stored in `reminders.category`.
  String get key => name;

  static ReminderCategory? tryFromKey(Object? key) {
    for (final category in values) {
      if (category.name == key) return category;
    }
    return null;
  }

  /// The record category a completed reminder of this kind becomes, or null
  /// for the non-clinical ones.
  RecordCategory? get recordCategory => switch (this) {
        ReminderCategory.visit => RecordCategory.visit,
        ReminderCategory.exam => RecordCategory.exam,
        ReminderCategory.vaccine => RecordCategory.vaccine,
        ReminderCategory.therapy => RecordCategory.therapy,
        ReminderCategory.grooming || ReminderCategory.other => null,
      };

  bool get isClinical => recordCategory != null;

  /// The finer types, the record category's own (visits, exams, therapies).
  List<String> get subtypes => recordCategory?.subtypes ?? const [];

  static ReminderCategory fromRecordCategory(RecordCategory category) => switch (category) {
        RecordCategory.visit => ReminderCategory.visit,
        RecordCategory.exam => ReminderCategory.exam,
        RecordCategory.vaccine => ReminderCategory.vaccine,
        RecordCategory.therapy => ReminderCategory.therapy,
        RecordCategory.document => ReminderCategory.other,
      };

  /// Whether this category makes sense for the animal: no vaccines for fish,
  /// reptiles or birds (the rule lives in pet_details.dart).
  bool isOfferedFor(String? species, {String? breed}) => switch (this) {
        ReminderCategory.vaccine => speciesHasVaccines(species, breed: breed),
        _ => true,
      };

  /// The categories to offer for an animal, in display order.
  static List<ReminderCategory> offeredFor(String? species, {String? breed}) => [
        for (final category in values)
          if (category.isOfferedFor(species, breed: breed)) category,
      ];
}

/// The category of a reminder saved before categories existed: a prudent
/// guess from its title (and kind), never stored - the owner confirms or
/// changes it when completing it. "Controllo peso" is not a vet visit, so a
/// bare "controllo" does not count as one; unsure means [ReminderCategory.other].
ReminderCategory legacyReminderCategory({required String title, required EventKind kind}) {
  final suggested = suggestCategoryFromTitle(title);
  if (suggested != null && suggested != RecordCategory.document) {
    final lowered = title.toLowerCase();
    final plainCheck = suggested == RecordCategory.visit &&
        !lowered.contains('visit') &&
        !lowered.contains('consult');
    if (!plainCheck) return ReminderCategory.fromRecordCategory(suggested);
  }
  return kind == EventKind.course ? ReminderCategory.therapy : ReminderCategory.other;
}
