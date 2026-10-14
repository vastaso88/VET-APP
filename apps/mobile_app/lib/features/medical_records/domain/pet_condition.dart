/// One illness of a pet (the "Patologie" of the cartella clinica): current
/// or past. Stored in `pet_conditions` (scripts/setup/supabase_schema.sql).
class PetConditionEntry {
  const PetConditionEntry({
    required this.id,
    required this.petId,
    required this.name,
    this.startedOn,
    this.ongoing = true,
    this.endedOn,
    this.therapy = '',
    this.notes = '',
    this.attachmentId,
    this.attachmentName,
  });

  final String id;
  final String petId;
  final String name;
  final DateTime? startedOn;

  /// False once resolved; [endedOn] is then the day it ended, when known.
  final bool ongoing;
  final DateTime? endedOn;
  final String therapy;
  final String notes;

  /// The optional file (a prescription, a report), uploaded like the referti.
  final String? attachmentId;
  final String? attachmentName;

  PetConditionEntry copyWith({
    String? name,
    DateTime? startedOn,
    bool? ongoing,
    DateTime? endedOn,
    String? therapy,
    String? notes,
    String? attachmentId,
    String? attachmentName,
    bool clearStartedOn = false,
    bool clearEndedOn = false,
    bool clearAttachment = false,
  }) {
    return PetConditionEntry(
      id: id,
      petId: petId,
      name: name ?? this.name,
      startedOn: clearStartedOn ? null : startedOn ?? this.startedOn,
      ongoing: ongoing ?? this.ongoing,
      endedOn: clearEndedOn ? null : endedOn ?? this.endedOn,
      therapy: therapy ?? this.therapy,
      notes: notes ?? this.notes,
      attachmentId: clearAttachment ? null : attachmentId ?? this.attachmentId,
      attachmentName: clearAttachment
          ? null
          : attachmentName ?? this.attachmentName,
    );
  }
}

/// Ongoing first, then the most recently started; the ones without a start
/// date last within their group.
List<PetConditionEntry> sortConditions(Iterable<PetConditionEntry> conditions) {
  final sorted = conditions.toList();
  sorted.sort((a, b) {
    if (a.ongoing != b.ongoing) return a.ongoing ? -1 : 1;
    final aDate = a.startedOn;
    final bDate = b.startedOn;
    if (aDate == null && bDate == null) return a.name.compareTo(b.name);
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    return bDate.compareTo(aDate);
  });
  return sorted;
}
