/// Portata dell'evento (docs/features/events_engine.md, sezione 2.2). Il
/// livello descrive da quanto lontano ha senso venire, non la qualità; il
/// valore arriva già deciso dal curatore con una base documentata.
enum EventLevel {
  local,
  provincial,
  regional,
  national,
  international;

  static EventLevel parse(String? value) {
    for (final level in EventLevel.values) {
      if (level.name == value) return level;
    }
    return EventLevel.local;
  }

  String get label {
    switch (this) {
      case EventLevel.local:
        return 'Locale';
      case EventLevel.provincial:
        return 'Provinciale';
      case EventLevel.regional:
        return 'Regionale';
      case EventLevel.national:
        return 'Nazionale';
      case EventLevel.international:
        return 'Internazionale';
    }
  }
}

/// Stato di pubblicazione visibile all'utente. `draft` e `rejected` non
/// arrivano mai all'app (la policy RLS li esclude), quindi non sono modellati.
enum EventStatus {
  published,
  cancelled,
  postponed;

  static EventStatus parse(String? value) {
    switch (value) {
      case 'cancelled':
        return EventStatus.cancelled;
      case 'postponed':
        return EventStatus.postponed;
      default:
        return EventStatus.published;
    }
  }
}

/// Codici `event_type` (tassonomia della sezione 1 del documento) con
/// l'etichetta italiana mostrata in app. Un codice sconosciuto non rompe nulla:
/// si mostra come "Altro".
const Map<String, String> eventTypeLabels = {
  'pet_fair': 'Fiera per animali',
  'dog_show': 'Esposizione canina',
  'breed_gathering': 'Raduno di razza',
  'cat_show': 'Esposizione felina',
  'work_trial': 'Prova di lavoro',
  'dog_sport': 'Sport cinofili',
  'adoption_day': 'Giornata di adozione',
  'shelter_open_day': 'Open day rifugio',
  'microchip_day': 'Microchip day',
  'vaccination_campaign': 'Campagna vaccinale',
  'group_walk': 'Passeggiata di gruppo',
  'course_seminar': 'Corso o seminario',
  'market': 'Mercatino',
  'charity_event': 'Evento benefico',
  'aquarium_expo': 'Acquariofilia',
  'reptile_expo': 'Terraristica',
  'bird_show': 'Ornitologia',
  'equestrian': 'Equestre',
  'other': 'Altro',
};

String eventTypeLabel(String code) => eventTypeLabels[code] ?? eventTypeLabels['other']!;

/// Un evento (una edizione con date concrete). Le date sono solo-giorno:
/// `startsOn`/`endsOn` sono mezzanotte locale del giorno, estremi inclusi.
class EventEntry {
  const EventEntry({
    required this.id,
    required this.title,
    required this.eventType,
    required this.level,
    required this.startsOn,
    required this.endsOn,
    this.description,
    this.city,
    this.provinceCode,
    this.region,
    this.venueName,
    this.organizerName,
    this.sourceUrl,
    this.status = EventStatus.published,
    this.lastVerifiedAt,
  });

  final String id;
  final String title;
  final String eventType;
  final EventLevel level;
  final DateTime startsOn;
  final DateTime endsOn;
  final String? description;
  final String? city;
  final String? provinceCode;
  final String? region;
  final String? venueName;
  final String? organizerName;

  /// Pagina ufficiale dell'evento o dell'organizzatore. Mai inventata: se
  /// manca, la card non apre nulla.
  final String? sourceUrl;
  final EventStatus status;
  final DateTime? lastVerifiedAt;

  /// Solo un http/https valido è apribile: qualunque altra cosa (vuoto, schema
  /// diverso, testo libero) vale come "nessun link".
  Uri? get launchableUrl {
    final raw = sourceUrl?.trim();
    if (raw == null || raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasAuthority) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return uri;
  }

  /// "Cremona (CR)" / "Cremona" / "Lombardia" a seconda di cosa si sa.
  String get placeLabel {
    final cityName = city?.trim();
    final province = provinceCode?.trim();
    if (cityName != null && cityName.isNotEmpty) {
      return province != null && province.isNotEmpty ? '$cityName ($province)' : cityName;
    }
    return region?.trim() ?? '';
  }
}
