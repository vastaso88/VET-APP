import '../../../l10n/l10n.dart';

/// Formats [date] relative to today, in the app language, for short agenda rows.
String relativeDayLabel(DateTime date) {
  final today = DateTime.now();
  final startOfToday = DateTime(today.year, today.month, today.day);
  final startOfDate = DateTime(date.year, date.month, date.day);
  final dayDifference = startOfDate.difference(startOfToday).inDays;

  if (dayDifference == 0) return appL10n.remindersRelativeToday;
  if (dayDifference == 1) return appL10n.remindersRelativeTomorrow;
  if (dayDifference == -1) return appL10n.remindersRelativeYesterday;
  if (dayDifference > 1) return appL10n.remindersRelativeInDays(dayDifference);
  return appL10n.remindersRelativeDaysAgo(-dayDifference);
}
