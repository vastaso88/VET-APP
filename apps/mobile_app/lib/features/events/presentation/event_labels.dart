import 'package:intl/intl.dart';

import '../domain/event_filter.dart';

/// "17 ott 2026", "17-18 ott 2026", "30 apr - 3 mag 2026" or, across years,
/// "30 dic 2026 - 2 gen 2027". Needs the 'it_IT' date symbols loaded
/// (initializeDateFormatting, done at app start in bootstrap.dart).
String eventDateRangeLabel(DateTime startsOn, DateTime endsOn) {
  final start = eventDay(startsOn);
  final end = eventDay(endsOn);
  final dayMonth = DateFormat('d MMM', 'it_IT');
  final dayMonthYear = DateFormat('d MMM y', 'it_IT');

  if (start == end) return dayMonthYear.format(start);
  if (start.year != end.year) {
    return '${dayMonthYear.format(start)} - ${dayMonthYear.format(end)}';
  }
  if (start.month == end.month) {
    return '${start.day}-${dayMonthYear.format(end)}';
  }
  return '${dayMonth.format(start)} - ${dayMonthYear.format(end)}';
}

/// Chip del filtro date: il testo fisso per la finestra predefinita, altrimenti
/// le date scelte.
String eventWindowChipLabel(EventFilter filter, DateTime today) {
  if (filter.isDefaultWindow(today)) return 'Prossimi $defaultEventWindowDays giorni';
  return eventDateRangeLabel(filter.from, filter.to);
}

/// Testo dello stato vuoto: onesto sul perché non c'è nulla. Con la finestra
/// predefinita nomina i 30 giorni; con filtri aggiuntivi lo dice.
String eventsEmptyMessage(EventFilter filter, DateTime today) {
  if (filter.hasExtraFilters) return 'Nessun evento con questi filtri nel periodo scelto';
  if (filter.isDefaultWindow(today)) {
    return 'Nessun evento nei prossimi $defaultEventWindowDays giorni';
  }
  return 'Nessun evento nel periodo scelto';
}
