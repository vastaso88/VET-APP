import 'package:intl/intl.dart';

import '../domain/local_activity.dart';

String localActivityKindLabel(LocalActivityKind kind) {
  switch (kind) {
    case LocalActivityKind.event:
      return 'Evento';
    case LocalActivityKind.service:
      return 'Servizio';
  }
}

final _dayMonthFormat = DateFormat('d MMM', 'it_IT');

/// Null when the activity has no date (a standing service like a clinic,
/// not a one-off event) - callers group those separately.
String? localActivityDateRangeLabel(LocalActivity activity) {
  final starts = activity.startsAt;
  if (starts == null) return null;

  final ends = activity.endsAt;
  if (ends == null || _isSameDay(ends, starts)) {
    return _dayMonthFormat.format(starts);
  }
  return '${_dayMonthFormat.format(starts)} - ${_dayMonthFormat.format(ends)}';
}

bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
