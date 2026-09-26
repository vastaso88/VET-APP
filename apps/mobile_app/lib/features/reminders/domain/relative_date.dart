/// Formats [date] relative to today, in Italian, for short agenda rows.
String relativeDayLabel(DateTime date) {
  final today = DateTime.now();
  final startOfToday = DateTime(today.year, today.month, today.day);
  final startOfDate = DateTime(date.year, date.month, date.day);
  final dayDifference = startOfDate.difference(startOfToday).inDays;

  if (dayDifference == 0) return 'oggi';
  if (dayDifference == 1) return 'domani';
  if (dayDifference == -1) return 'ieri';
  if (dayDifference > 1) return 'tra $dayDifference giorni';
  return '${-dayDifference} giorni fa';
}
