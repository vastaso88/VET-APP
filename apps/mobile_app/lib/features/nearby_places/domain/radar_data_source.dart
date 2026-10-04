/// An imported dataset as reported by the backend (`/local-services/sources`).
class RadarDataSource {
  const RadarDataSource({required this.source, required this.release, required this.importedAt});

  final String source;
  final String release;
  final DateTime importedAt;

  static RadarDataSource? tryFromJson(Map<String, dynamic> json) {
    final source = json['source'] as String?;
    final importedAt = DateTime.tryParse(json['imported_at'] as String? ?? '');
    if (source == null || importedAt == null) {
      return null;
    }
    return RadarDataSource(
      source: source,
      release: json['release'] as String? ?? '',
      importedAt: importedAt,
    );
  }
}

/// What the app says about a source wherever its data is shown. Kept in
/// the app, not fetched: the attribution must be right even when the
/// backend is unreachable.
class RadarSourceInfo {
  const RadarSourceInfo({
    required this.source,
    required this.name,
    required this.description,
    required this.attribution,
    required this.license,
    required this.url,
  });

  /// Backend `source_name` of the places that come from this source.
  final String source;
  final String name;
  final String description;
  final String attribution;
  final String license;
  final String url;
}

const radarSourceCatalog = [
  RadarSourceInfo(
    source: 'openstreetmap_overpass',
    name: 'OpenStreetMap',
    description: 'Mappa libera curata da volontari. Fonte delle aree cani e di parte di '
        'veterinari, negozi e altri servizi, con i dettagli che i volontari hanno indicato.',
    attribution: '© OpenStreetMap contributors',
    license: 'Open Database License (ODbL) 1.0',
    url: 'https://www.openstreetmap.org/copyright',
  ),
  RadarSourceInfo(
    source: 'overture',
    name: 'Overture Maps',
    description: 'Archivio aperto di attività commerciali. Fonte di veterinari, toelettature, '
        'negozi, pensioni e addestratori che OpenStreetMap non conosce.',
    attribution: '© Overture Maps Foundation — Places',
    license: 'Community Data License Agreement – Permissive 2.0',
    url: 'https://docs.overturemaps.org/attribution/',
  ),
  RadarSourceInfo(
    source: 'comune_bologna',
    name: 'Comune di Bologna',
    description: 'Elenco ufficiale delle aree di sgambatura per cani del Comune di Bologna.',
    attribution: 'Comune di Bologna — Open Data',
    license: 'Creative Commons Attribuzione 4.0 (CC BY 4.0)',
    url: 'https://opendata.comune.bologna.it/explore/dataset/sgambatura_cani/',
  ),
  RadarSourceInfo(
    source: 'comune_torino',
    name: 'Città di Torino',
    description: 'Elenco ufficiale delle aree cani della Città di Torino.',
    attribution: 'Città di Torino — aperTO',
    license: 'Creative Commons Attribuzione 4.0 (CC BY 4.0)',
    url: 'https://aperto.comune.torino.it/dataset/aree-cani',
  ),
];

/// Places added through "Segnala!". Not an imported dataset, so not part
/// of [radarSourceCatalog] (the "Fonti dati" list), but still a source a
/// place card must name.
const radarUserSourceInfo = RadarSourceInfo(
  source: 'vetapp_users',
  name: 'Utenti VetApp',
  description: 'Luoghi segnalati dagli utenti e confermati da altri utenti.',
  attribution: 'Segnalato dagli utenti VetApp',
  license: '',
  url: '',
);

RadarSourceInfo? radarSourceInfo(String source) {
  if (source == radarUserSourceInfo.source) {
    return radarUserSourceInfo;
  }
  for (final info in radarSourceCatalog) {
    if (info.source == source) {
      return info;
    }
  }
  return null;
}
