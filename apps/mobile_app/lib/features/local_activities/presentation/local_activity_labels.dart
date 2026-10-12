import '../../../l10n/date_formats.dart';
import '../../../l10n/l10n.dart';
import '../domain/local_activity.dart';

String localActivityKindLabel(LocalActivityKind kind) {
  switch (kind) {
    case LocalActivityKind.event:
      return appL10n.localActivitiesKindEvent;
    case LocalActivityKind.service:
      return appL10n.localActivitiesKindService;
  }
}

/// Null when the activity has no date (a standing service like a clinic,
/// not a one-off event) - callers group those separately.
String? localActivityDateRangeLabel(LocalActivity activity) {
  final starts = activity.startsAt;
  if (starts == null) return null;

  final dayMonthFormat = appDateFormat('d MMM');
  final ends = activity.endsAt;
  if (ends == null || _isSameDay(ends, starts)) {
    return dayMonthFormat.format(starts);
  }
  return '${dayMonthFormat.format(starts)} - ${dayMonthFormat.format(ends)}';
}

bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
