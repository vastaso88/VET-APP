/// The travel cards of "Around the world" (docs/product/18): a short summary of
/// the official rules for taking a dog, a cat or a ferret to one country.
///
/// The backend serves every approved card (`GET /travel/cards`) and the phone
/// picks the one it needs, so the pair of countries a person looks at never
/// reaches the server (docs/compliance/17 A.14).
library;

/// The species a card exists for.
enum TravelSpecies {
  dog('dog'),
  cat('cat'),
  ferret('ferret');

  const TravelSpecies(this.wire);

  /// The value the backend uses.
  final String wire;

  static TravelSpecies? fromWire(String? value) {
    for (final species in TravelSpecies.values) {
      if (species.wire == value) return species;
    }
    return null;
  }
}

/// Where the traveller starts from: a member state of the Union, or not.
enum TravelOrigin {
  eu('EU'),
  nonEu('non_EU');

  const TravelOrigin(this.wire);

  final String wire;

  static TravelOrigin? fromWire(String? value) {
    for (final origin in TravelOrigin.values) {
      if (origin.wire == value) return origin;
    }
    return null;
  }
}

/// How fresh a card is: after 90 days it warns, after 180 days the backend
/// sends no content, only the link to the official source.
enum TravelCardVisibility {
  fresh,
  old,
  hidden;

  static TravelCardVisibility fromWire(String? value) => switch (value) {
        'old' => TravelCardVisibility.old,
        'hidden' => TravelCardVisibility.hidden,
        _ => TravelCardVisibility.fresh,
      };
}

class TravelSentence {
  const TravelSentence({
    required this.text,
    this.origins = const [],
    this.own = false,
    this.sourceIds = const [],
  });

  final String text;

  /// Empty = valid whichever the origin.
  final List<TravelOrigin> origins;

  /// Quokka's own advice, not the source's: shown as such.
  final bool own;
  final List<String> sourceIds;

  bool appliesTo(TravelOrigin origin) => origins.isEmpty || origins.contains(origin);

  factory TravelSentence.fromJson(Map<String, dynamic> json) => TravelSentence(
        text: (json['text'] ?? '').toString(),
        origins: [
          for (final raw in (json['origins'] as List<dynamic>? ?? const []))
            if (TravelOrigin.fromWire(raw.toString()) case final origin?) origin,
        ],
        own: json['own'] == true,
        sourceIds: [for (final raw in (json['source_ids'] as List<dynamic>? ?? const [])) raw.toString()],
      );
}

class TravelBlock {
  const TravelBlock({required this.kind, required this.sentences});

  /// A key such as `documenti` or `vaccini_obbligatori` (see [travelBlockKinds]).
  final String kind;
  final List<TravelSentence> sentences;

  factory TravelBlock.fromJson(Map<String, dynamic> json) => TravelBlock(
        kind: (json['kind'] ?? '').toString(),
        sentences: [
          for (final raw in (json['sentences'] as List<dynamic>? ?? const []))
            TravelSentence.fromJson(raw as Map<String, dynamic>),
        ],
      );
}

/// The order the blocks are shown in, which is also the order things happen.
const travelBlockKinds = <String>[
  'documenti',
  'microchip',
  'vaccini_obbligatori',
  'test_sierologici',
  'vaccini_consigliati',
  'malattie_presenti',
  'farmaci_e_protezioni',
  'comportamenti_e_norme',
  'rientro',
  'non_diffondere',
  'quando_andare_dal_veterinario',
  'limiti',
];

class TravelSource {
  const TravelSource({required this.id, required this.citation, required this.url});

  final String id;

  /// The readable line ("Fonte: ente, titolo, anno, indirizzo. Riassunto di
  /// Quokka, verificato il ...").
  final String citation;
  final String url;

  factory TravelSource.fromJson(Map<String, dynamic> json) => TravelSource(
        id: (json['id'] ?? '').toString(),
        citation: (json['citation'] ?? '').toString(),
        url: (json['url'] ?? '').toString(),
      );
}

class TravelCard {
  const TravelCard({
    required this.id,
    required this.country,
    required this.species,
    required this.title,
    required this.checkedOn,
    required this.officialUrl,
    required this.visibility,
    this.blocks = const [],
    this.sources = const [],
  });

  final String id;

  /// ISO 3166 code, or `EU` for the card common to every member state.
  final String country;
  final TravelSpecies species;
  final String title;
  final DateTime? checkedOn;

  /// The page of the official authority: where to go when the card is old.
  final String officialUrl;
  final TravelCardVisibility visibility;
  final List<TravelBlock> blocks;
  final List<TravelSource> sources;

  /// A card with no content (too old): only the link to the official source.
  bool get isHidden => visibility == TravelCardVisibility.hidden;

  /// The card code, e.g. `via-eu-can` (used in the "report an error" mail).
  String get code => id.toUpperCase();

  static TravelCard? tryParse(Map<String, dynamic> json) {
    final species = TravelSpecies.fromWire(json['species']?.toString());
    final country = (json['country'] ?? '').toString();
    if (species == null || country.isEmpty) return null;
    return TravelCard(
      id: (json['id'] ?? '').toString(),
      country: country,
      species: species,
      title: (json['title'] ?? '').toString(),
      checkedOn: DateTime.tryParse((json['checked_on'] ?? '').toString()),
      officialUrl: (json['official_url'] ?? '').toString(),
      visibility: TravelCardVisibility.fromWire(json['visibility']?.toString()),
      blocks: [
        for (final raw in (json['blocks'] as List<dynamic>? ?? const []))
          TravelBlock.fromJson(raw as Map<String, dynamic>),
      ],
      sources: [
        for (final raw in (json['sources'] as List<dynamic>? ?? const []))
          TravelSource.fromJson(raw as Map<String, dynamic>),
      ],
    );
  }
}
