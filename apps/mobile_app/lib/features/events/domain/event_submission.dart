import '../../territory/domain/territory.dart';

/// The country the form starts from: the one of the owner's home (Località)
/// when the app knows it, else the account's.
String defaultEventCountry(String? homeCountryCode) {
  final home = homeCountryCode?.toUpperCase();
  return home != null && knownTerritoryCodes.contains(home)
      ? home
      : currentTerritory().countryCode;
}

/// I dati del modulo "Segnala un evento", già ripuliti.
class EventSubmissionDraft {
  const EventSubmissionDraft({
    required this.title,
    required this.eventType,
    required this.startsOn,
    required this.endsOn,
    required this.city,
    required this.sourceUrl,
    this.country = sourceTerritoryCode,
    this.region,
    this.provinceCode,
    this.venueName,
  });

  final String title;
  final String eventType;
  final DateTime startsOn;
  final DateTime endsOn;
  final String city;
  final String sourceUrl;

  /// ISO 3166-1 alpha-2, one of `knownTerritoryCodes`.
  final String country;

  /// One of `eventRegionsByCountry[country]`.
  final String? region;
  final String? provinceCode;
  final String? venueName;

  Map<String, dynamic> toJson() => {
        'title': title,
        'event_type': eventType,
        'starts_on': _day(startsOn),
        'ends_on': _day(endsOn),
        'city': city,
        'source_url': sourceUrl,
        'country': country,
        if (region != null) 'region': region,
        if (provinceCode != null) 'province_code': provinceCode,
        if (venueName != null) 'venue_name': venueName,
      };

  static String _day(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}

/// Un link è accettabile se è un indirizzo http/https con un dominio.
bool isValidEventLink(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || !uri.hasAuthority) return false;
  return (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.contains('.');
}
