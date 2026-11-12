import '../../../app/launch/warm_start_store.dart';
import '../../../l10n/date_formats.dart';
import '../../../l10n/l10n.dart';
import '../../medical_records/data/medical_records_repository.dart';
import '../data/reminders_repository.dart';
import '../domain/reminder_category.dart';
import '../domain/reminder_completion.dart';

/// "Fatto? Registralo nello storico": what each answer does to the reminder and
/// to the pet's cartella clinica.
///
/// * [confirmDone] - a clinical reminder writes a record (category, type, the
///   real date, the owner's notes); then the reminder moves on (next due date
///   of a repeating one, finished otherwise). A non-clinical one is only ticked.
/// * [dismiss] - "Non fatto": same moving on, no record.
/// * [postpone] - "Rimanda": nothing changes, the question comes back tomorrow.
///
/// Nothing here ever completes a reminder by itself: deleting a record later
/// leaves the reminder as it is (it already moved on), so it never "completes
/// again" on its own.
class ReminderCompletionService {
  ReminderCompletionService({
    RemindersRepository? reminders,
    MedicalRecordsRepository? records,
    WarmStartStore store = const WarmStartStore(),
    DateTime Function()? now,
  })  : _reminders = reminders ?? RemindersRepository(),
        _records = records ?? MedicalRecordsRepository(),
        _store = store,
        _now = now ?? DateTime.now;

  final RemindersRepository _reminders;
  final MedicalRecordsRepository _records;
  final WarmStartStore _store;
  final DateTime Function() _now;

  /// The record written for [reminder]'s current occurrence, or null when its
  /// category is not clinical (nothing is written then).
  ///
  /// The record goes first: if it cannot be saved the reminder is untouched and
  /// the owner can try again; if the reminder then fails to save, trying again
  /// rewrites the same record (its id is fixed, see [completedRecordId]).
  /// Throws [MedicalRecordSaveException] / [ReminderSyncException].
  Future<MedicalRecordEntry?> confirmDone(
    ReminderEntry reminder, {
    required ReminderCategory category,
    required DateTime eventDate,
    String? title,
    String? subtype,
    String notes = '',
  }) async {
    final now = _now();
    MedicalRecordEntry? record;
    final recordCategory = category.recordCategory;
    if (recordCategory != null) {
      record = MedicalRecordEntry(
        id: completedRecordId(reminder),
        petName: reminder.petName,
        title: (title ?? reminder.title).trim().isEmpty ? reminder.title : (title ?? reminder.title).trim(),
        subtitle: '',
        meta: '',
        badge: '',
        // Stored with the record, so written in the language in use now.
        detailSource: appL10n.medicalRecordSourceFromReminder,
        createdAt: _formatCreatedAt(now),
        category: recordCategory,
        subtype: subtype,
        eventDate: DateTime(eventDate.year, eventDate.month, eventDate.day),
        notes: notes.trim(),
        createdOn: now,
        timeline: const [],
      );
      await _records.saveRecord(record);
    }

    final confirmed = reminder.copyWith(
      category: category,
      subtype: subtype,
      clearSubtype: subtype == null,
    );
    await _reminders.saveReminder(advanceReminder(confirmed, now));
    await _forgetPostponement(reminder);
    return record;
  }

  /// "Non fatto": the occurrence is closed without a record.
  Future<void> dismiss(ReminderEntry reminder) async {
    await _reminders.saveReminder(advanceReminder(reminder, _now()));
    await _forgetPostponement(reminder);
  }

  /// "Rimanda": asked again tomorrow morning.
  Future<void> postpone(ReminderEntry reminder) =>
      _store.saveDraft(_snoozeKey(reminder), snoozeUntil(_now()).toIso8601String());

  /// Until when the question about [reminder]'s current occurrence is on hold.
  Future<DateTime?> postponedUntil(ReminderEntry reminder) async {
    final stored = await _store.loadDraft(_snoozeKey(reminder));
    return stored == null ? null : DateTime.tryParse(stored);
  }

  Future<void> _forgetPostponement(ReminderEntry reminder) =>
      _store.saveDraft(_snoozeKey(reminder), '');

  // Per occurrence: the answer to one due date does not silence the next.
  // Kept with the other small per-user leftovers WarmStartStore clears at sign-out.
  static String _snoozeKey(ReminderEntry reminder) => 'reminder_snooze.${completedRecordId(reminder)}';

  static String _formatCreatedAt(DateTime date) {
    final months = appShortMonths();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day} ${months[date.month - 1]} ${date.year}, $hour:$minute';
  }
}
