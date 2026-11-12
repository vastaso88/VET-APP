import '../../../l10n/l10n.dart';

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
    final l10n = appL10n;
    switch (this) {
      case EventLevel.local:
        return l10n.eventsLevelLocal;
      case EventLevel.provincial:
        return l10n.eventsLevelProvincial;
      case EventLevel.regional:
        return l10n.eventsLevelRegional;
      case EventLevel.national:
        return l10n.eventsLevelNational;
      case EventLevel.international:
        return l10n.eventsLevelInternational;
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

/// I codici `event_type` che l'app sa nominare, nell'ordine in cui si offrono
/// nel modulo "Segnala un evento" ("other" in fondo).
const eventTypeCodes = <String>[
  'pet_fair',
  'dog_show',
  'cat_show',
  'breed_gathering',
  'work_trial',
  'dog_sport',
  'adoption_day',
  'shelter_open_day',
  'microchip_day',
  'vaccination_campaign',
  'group_walk',
  'course_seminar',
  'market',
  'charity_event',
  'aquarium_expo',
  'reptile_expo',
  'bird_show',
  'equestrian',
  'other',
];

/// Codici `event_type` (tassonomia della sezione 1 del documento) con
/// l'etichetta mostrata in app nella lingua dell'utente. Un codice
/// sconosciuto non rompe nulla: si mostra come "Altro".
String eventTypeLabel(String code) {
  final l10n = appL10n;
  switch (code) {
    case 'pet_fair':
      return l10n.eventsTypePetFair;
    case 'dog_show':
      return l10n.eventsTypeDogShow;
    case 'breed_gathering':
      return l10n.eventsTypeBreedGathering;
    case 'cat_show':
      return l10n.eventsTypeCatShow;
    case 'work_trial':
      return l10n.eventsTypeWorkTrial;
    case 'dog_sport':
      return l10n.eventsTypeDogSport;
    case 'adoption_day':
      return l10n.eventsTypeAdoptionDay;
    case 'shelter_open_day':
      return l10n.eventsTypeShelterOpenDay;
    case 'microchip_day':
      return l10n.eventsTypeMicrochipDay;
    case 'vaccination_campaign':
      return l10n.eventsTypeVaccinationCampaign;
    case 'group_walk':
      return l10n.eventsTypeGroupWalk;
    case 'course_seminar':
      return l10n.eventsTypeCourseSeminar;
    case 'market':
      return l10n.eventsTypeMarket;
    case 'charity_event':
      return l10n.eventsTypeCharityEvent;
    case 'aquarium_expo':
      return l10n.eventsTypeAquariumExpo;
    case 'reptile_expo':
      return l10n.eventsTypeReptileExpo;
    case 'bird_show':
      return l10n.eventsTypeBirdShow;
    case 'equestrian':
      return l10n.eventsTypeEquestrian;
    default:
      return l10n.eventsTypeOther;
  }
}

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
    this.country = 'IT',
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

  /// ISO 3166-1 alpha-2 of the country the event takes place in. The app only
  /// ever shows the owner's country (EventsRepository.loadEvents); rows
  /// written before the column existed are Italian.
  final String country;
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
