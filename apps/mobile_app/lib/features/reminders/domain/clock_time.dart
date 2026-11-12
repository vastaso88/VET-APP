/// "08:05" — the stored and displayed form of a time of day, e.g. a
/// course's dose times ([ReminderEntry.doseTimes]).
String formatClockTime(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

/// Reads "HH:mm" back as (hour, minute); null for anything else.
({int hour, int minute})? parseClockTime(String value) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
  if (match == null) return null;
  final hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  if (hour > 23 || minute > 59) return null;
  return (hour: hour, minute: minute);
}
