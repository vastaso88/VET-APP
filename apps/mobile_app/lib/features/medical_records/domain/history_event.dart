import '../../../shared/date/calendar_days.dart';
import '../data/medical_records_repository.dart';
import 'pet_condition.dart';
import 'record_category.dart';

/// One line of a pet's "Storico": an entry of the cartella clinica (on the day
/// it happened) or an illness (on the day it started).
class HistoryEvent {
  const HistoryEvent._({
    required this.id,
    required this.date,
    required this.title,
    this.category,
    this.subtype,
    this.notes = '',
    this.record,
    this.condition,
  });

  factory HistoryEvent.fromRecord(MedicalRecordEntry record) {
    final day = record.eventDate ?? record.createdOn;
    return HistoryEvent._(
      id: 'record:${record.id}',
      date: day == null ? null : dayOnly(day),
      title: record.title,
      category: record.category,
      subtype: record.subtype,
      notes: record.notes,
      record: record,
    );
  }

  factory HistoryEvent.fromCondition(PetConditionEntry condition) {
    final started = condition.startedOn;
    return HistoryEvent._(
      id: 'condition:${condition.id}',
      date: started == null ? null : dayOnly(started),
      title: condition.name,
      notes: condition.notes,
      condition: condition,
    );
  }

  final String id;

  /// The calendar day, or null when the entry carries no date at all.
  final DateTime? date;
  final String title;

  /// The record's category; null for an illness.
  final RecordCategory? category;
  final String? subtype;
  final String notes;
  final MedicalRecordEntry? record;
  final PetConditionEntry? condition;

  bool get isCondition => condition != null;
}

/// Every record and illness as events, oldest first. Undated ones come first
/// (they cannot be placed on the calendar but still belong in an export). Two
/// events on the same day keep a fixed order, so a list never reshuffles.
List<HistoryEvent> buildHistoryEvents({
  required Iterable<MedicalRecordEntry> records,
  required Iterable<PetConditionEntry> conditions,
}) {
  final events = <HistoryEvent>[
    for (final record in records) HistoryEvent.fromRecord(record),
    for (final condition in conditions) HistoryEvent.fromCondition(condition),
  ];
  events.sort(compareHistoryEvents);
  return events;
}

int compareHistoryEvents(HistoryEvent a, HistoryEvent b) {
  final aDate = a.date;
  final bDate = b.date;
  if (aDate != bDate) {
    if (aDate == null) return -1;
    if (bDate == null) return 1;
    return aDate.compareTo(bDate);
  }
  final byKind = _kindOrder(a).compareTo(_kindOrder(b));
  if (byKind != 0) return byKind;
  final byTitle = a.title.toLowerCase().compareTo(b.title.toLowerCase());
  return byTitle != 0 ? byTitle : a.id.compareTo(b.id);
}

int _kindOrder(HistoryEvent event) =>
    event.category?.index ?? RecordCategory.values.length;

/// The dated events grouped by day.
Map<DateTime, List<HistoryEvent>> groupEventsByDay(
    Iterable<HistoryEvent> events) {
  final byDay = <DateTime, List<HistoryEvent>>{};
  for (final event in events) {
    final date = event.date;
    if (date != null) byDay.putIfAbsent(date, () => []).add(event);
  }
  return byDay;
}

/// The cells of the month grid, Monday first: null for the days of the
/// neighbouring months that complete the first and last week.
List<DateTime?> monthGridCells(DateTime month) {
  final first = DateTime(month.year, month.month);
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  final leading = first.weekday - DateTime.monday;
  final cells = <DateTime?>[
    for (var i = 0; i < leading; i++) null,
    for (var day = 1; day <= daysInMonth; day++)
      DateTime(month.year, month.month, day),
  ];
  while (cells.length % 7 != 0) {
    cells.add(null);
  }
  return cells;
}
