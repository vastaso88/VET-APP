import '../../../l10n/l10n.dart';
import '../../../shared/date/calendar_days.dart';

/// Formats [date] relative to today, in the app language, for short agenda rows.
String relativeDayLabel(DateTime date) {
  final today = DateTime.now();
  final dayDifference = calendarDaysBetween(today, date);

  if (dayDifference == 0) return appL10n.remindersRelativeToday;
  if (dayDifference == 1) return appL10n.remindersRelativeTomorrow;
  if (dayDifference == -1) return appL10n.remindersRelativeYesterday;
  if (dayDifference > 1) return appL10n.remindersRelativeInDays(dayDifference);
  return appL10n.remindersRelativeDaysAgo(-dayDifference);
}
