import '../../../l10n/l10n.dart';

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
/// backend is unreachable. Names are proper nouns and stay as they are;
/// descriptions, attributions and license names follow the app language.
class RadarSourceInfo {
  const RadarSourceInfo({required this.source, required String name, required this.url})
      : _name = name;

  /// Backend `source_name` of the places that come from this source.
  final String source;
  final String _name;
  final String url;

  String get name => source == _userSource ? appL10n.placesSourceUsersName : _name;

  String get description {
    final l10n = appL10n;
    switch (source) {
      case 'openstreetmap_overpass':
        return l10n.placesSourceOsmDescription;
      case 'overture':
        return l10n.placesSourceOvertureDescription;
      case 'comune_bologna':
        return l10n.placesSourceBolognaDescription;
      case 'comune_torino':
        return l10n.placesSourceTorinoDescription;
      case 'comune_milano':
        return l10n.placesSourceMilanoDescription;
      default:
        return l10n.placesSourceUsersDescription;
    }
  }

  String get attribution {
    final l10n = appL10n;
    switch (source) {
      case 'openstreetmap_overpass':
        return '© OpenStreetMap contributors';
      case 'overture':
        return '© Overture Maps Foundation — Places';
      case 'comune_bologna':
        return l10n.placesSourceBolognaAttribution;
      case 'comune_torino':
        return l10n.placesSourceTorinoAttribution;
      case 'comune_milano':
        return l10n.placesSourceMilanoAttribution;
      default:
        return l10n.placesSourceUsersAttribution;
    }
  }

  String get license {
    switch (source) {
      case 'openstreetmap_overpass':
        return 'Open Database License (ODbL) 1.0';
      case 'overture':
        return 'Community Data License Agreement – Permissive 2.0';
      case 'comune_bologna':
      case 'comune_torino':
      case 'comune_milano':
        return appL10n.placesSourceLicenseCcBy;
      default:
        return '';
    }
  }
}

const _userSource = 'vetapp_users';

const radarSourceCatalog = [
  RadarSourceInfo(
    source: 'openstreetmap_overpass',
    name: 'OpenStreetMap',
    url: 'https://www.openstreetmap.org/copyright',
  ),
  RadarSourceInfo(
    source: 'overture',
    name: 'Overture Maps',
    url: 'https://docs.overturemaps.org/attribution/',
  ),
  RadarSourceInfo(
    source: 'comune_bologna',
    name: 'Comune di Bologna',
    url: 'https://opendata.comune.bologna.it/explore/dataset/sgambatura_cani/',
  ),
  RadarSourceInfo(
    source: 'comune_torino',
    name: 'Città di Torino',
    url: 'https://aperto.comune.torino.it/dataset/aree-cani',
  ),
  RadarSourceInfo(
    source: 'comune_milano',
    name: 'Comune di Milano',
    url: 'https://dati.comune.milano.it/dataset/ds52_infogeo_aree_cani_localizzazione',
  ),
];

/// Places added through "Segnala!". Not an imported dataset, so not part
/// of [radarSourceCatalog] (the "Fonti dati" list), but still a source a
/// place card must name.
// The name is localized by [RadarSourceInfo.name].
const radarUserSourceInfo = RadarSourceInfo(source: _userSource, name: '', url: '');

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
