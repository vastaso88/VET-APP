// Calendar-day arithmetic on local dates.
//
// Why this exists: `date.add(Duration(days: n))` adds n x 24 hours, and on the
// days the clocks change (last Sunday of March / October) a local day has 23
// or 25 hours. From a local midnight that lands on 01:00 of the right day in
// spring but on 23:00 of the *previous* day in autumn; and
// `later.difference(earlier).inDays` is off by one across the spring change
// (47 hours is 1 day). Everything that works in days goes through these.

// [date] moved by [days] calendar days, at the same time of day. Unlike
// `add(Duration(days: n))` the clock time never shifts with the hour change.
DateTime addCalendarDays(DateTime date, int days) {
  return date.isUtc
      ? DateTime.utc(date.year, date.month, date.day + days, date.hour, date.minute,
          date.second, date.millisecond, date.microsecond)
      : DateTime(date.year, date.month, date.day + days, date.hour, date.minute, date.second,
          date.millisecond, date.microsecond);
}

/// Whole calendar days from [from]'s day to [to]'s day (negative when [to] is
/// earlier), ignoring the time of day and any summer-time change in between.
int calendarDaysBetween(DateTime from, DateTime to) {
  final start = DateTime.utc(from.year, from.month, from.day);
  final end = DateTime.utc(to.year, to.month, to.day);
  return end.difference(start).inDays;
}
