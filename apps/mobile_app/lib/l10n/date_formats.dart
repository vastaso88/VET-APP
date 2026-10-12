import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'l10n.dart';

/// intl locale name of the app language ("it", "en", "en_GB", ...).
String get appIntlLocale => Intl.canonicalizedLocale(AppLocaleHolder.current.toString());

/// A [DateFormat] in the app language. Loads the locale's data on first use,
/// so callers never have to think about `initializeDateFormatting`.
///
/// Italian months and weekdays come out lowercase ("mag", "lunedì"), exactly
/// as the app has always shown them; capitalise at the call site if needed.
DateFormat appDateFormat(String pattern) {
  final name = appIntlLocale;
  var loaded = false;
  try {
    loaded = DateFormat.localeExists(name);
  } catch (_) {
    // Nothing initialised yet (plain unit tests): load below.
  }
  if (!loaded) {
    initializeDateFormatting(name);
  }
  return DateFormat(pattern, name);
}

/// `formatAppDate(date, 'd MMM y')` → "5 mag 2021".
String formatAppDate(DateTime date, String pattern) => appDateFormat(pattern).format(date);

/// Month names of the app language, January first: "gen" … "dic".
List<String> appShortMonths() => appDateFormat('MMM').dateSymbols.SHORTMONTHS;

/// "gennaio" … "dicembre".
List<String> appLongMonths() => appDateFormat('MMMM').dateSymbols.MONTHS;

/// Weekday names, **Monday first** ("lun" … "dom").
List<String> appShortWeekdaysMondayFirst() {
  final symbols = appDateFormat('E').dateSymbols.SHORTWEEKDAYS; // Sunday first
  return [...symbols.sublist(1), symbols.first];
}

/// "lunedì" … "domenica", Monday first.
List<String> appLongWeekdaysMondayFirst() {
  final symbols = appDateFormat('EEEE').dateSymbols.WEEKDAYS; // Sunday first
  return [...symbols.sublist(1), symbols.first];
}

/// The decimal separator of the app language ("," or ".").
String appDecimalSeparator() => NumberFormat.decimalPattern(appIntlLocale).symbols.DECIMAL_SEP;
