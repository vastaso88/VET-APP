import '../../../l10n/date_formats.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/date/calendar_days.dart';
import '../domain/event_filter.dart';

/// "17 ott 2026", "17-18 ott 2026", "30 apr - 3 mag 2026" or, across years,
/// "30 dic 2026 - 2 gen 2027" (month names in the app language).
String eventDateRangeLabel(DateTime startsOn, DateTime endsOn) {
  final start = dayOnly(startsOn);
  final end = dayOnly(endsOn);
  final dayMonth = appDateFormat('d MMM');
  final dayMonthYear = appDateFormat('d MMM y');

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
  if (filter.isDefaultWindow(today)) return appL10n.eventsWindowDefault(defaultEventWindowDays);
  return eventDateRangeLabel(filter.from, filter.to);
}

/// Testo dello stato vuoto: onesto sul perché non c'è nulla. Con la finestra
/// predefinita nomina i 30 giorni; con filtri aggiuntivi lo dice.
String eventsEmptyMessage(EventFilter filter, DateTime today) {
  final l10n = appL10n;
  if (filter.hasExtraFilters) return l10n.eventsEmptyFiltered;
  if (filter.isDefaultWindow(today)) {
    return l10n.eventsEmptyDefault(defaultEventWindowDays);
  }
  return l10n.eventsEmptyPeriod;
}
