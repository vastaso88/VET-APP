/// How a walk's own times (`started_at`, `ended_at`, `paused_at`) travel to and
/// from the database.
///
/// The columns are `timestamptz`, but the app has always written them as the
/// phone's wall clock WITHOUT a zone ("2026-10-09T10:00:00", what
/// `DateTime.toIso8601String` gives for a local time). Postgres reads such a
/// string as UTC, so the row holds 10:00 UTC for a walk that began at 10:00
/// Rome time, and reading it back yields an instant two hours (one in winter)
/// off. The date shown looked right - the same fields - but anything comparing
/// instants was wrong: a photo taken during the walk fell outside "its" walk
/// (owner report, build 26: no "Passeggiata del ..." caption).
///
/// The rows already in the database follow that convention, so it is kept and
/// made explicit rather than migrated: the stored value is the wall clock
/// written as if it were UTC, and reading it back turns those fields into a
/// local time again. Old and new rows therefore read the same, no SQL is
/// needed, and a walk keeps its wall-clock time wherever the phone is later.
/// (Route points are different: their `recorded_at` are real UTC instants from
/// the GPS and are not touched by this.)
library;

/// The string to store for [time]: its local wall-clock fields, marked as UTC.
String wallClockToStored(DateTime time) {
  final local = time.toLocal();
  return DateTime.utc(
    local.year,
    local.month,
    local.day,
    local.hour,
    local.minute,
    local.second,
    local.millisecond,
    local.microsecond,
  ).toIso8601String();
}

/// The local time for a stored value, or null when [raw] is empty or not a
/// date. A value with a zone ("Z", "+00:00" - what Supabase returns) is read
/// as wall-clock fields; one without (the app's own on-device copy) is already
/// local and is returned as it is.
DateTime? storedToWallClock(Object? raw) {
  final text = (raw ?? '').toString().trim();
  if (text.isEmpty) return null;
  final parsed = DateTime.tryParse(text);
  if (parsed == null) return null;
  if (!parsed.isUtc) return parsed;
  return DateTime(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
    parsed.millisecond,
    parsed.microsecond,
  );
}
