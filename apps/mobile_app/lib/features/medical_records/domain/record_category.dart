import '../../pets/domain/pet_details.dart';

/// The categories of the cartella clinica. [key] is what is stored in
/// `clinical_events.category` and what the backend reads
/// (packages/core/domain/medical_record/models.py): keep the two in step.
enum RecordCategory {
  visit,
  exam,
  vaccine,
  therapy,
  document;

  String get key => name;

  /// Whether to offer this category for the animal: no vaccines for fish,
  /// reptiles or birds (the rule is `speciesHasVaccines`, in pet_details.dart).
  /// Entries already stored under it stay visible: this only decides what a
  /// form or a tile list proposes.
  bool isOfferedFor(String? species, {String? breed}) =>
      this != RecordCategory.vaccine || speciesHasVaccines(species, breed: breed);

  /// An unknown or missing value is a document: rows written before the
  /// categories existed have none.
  static RecordCategory fromKey(Object? key) {
    for (final category in values) {
      if (category.name == key) return category;
    }
    return RecordCategory.document;
  }

  /// The finer types the owner can pick (stored in `clinical_events.subtype`).
  /// Vaccines and documents have none: the category says it all.
  List<String> get subtypes => switch (this) {
    RecordCategory.visit => const [
      'checkup',
      'specialist',
      'first_visit',
      'emergency',
      'post_surgery',
      'other',
    ],
    RecordCategory.exam => const [
      'blood',
      'urine',
      'stool',
      'xray',
      'ultrasound',
      'other',
    ],
    RecordCategory.therapy => const ['antiparasitic', 'medication', 'other'],
    RecordCategory.vaccine || RecordCategory.document => const [],
  };
}

// Words in a title that tell what kind of entry it is, checked in this order
// (a "richiamo vaccinale" is a vaccine even if it also says "visita").
const _titleHints = <(RecordCategory, List<String>)>[
  (RecordCategory.vaccine, ['vaccin', 'richiamo', 'libretto']),
  (
    RecordCategory.exam,
    [
      'emocromo',
      'esame',
      'analisi',
      'sangue',
      'ematic',
      'biochim',
      'urin',
      'feci',
      'radiograf',
      'ecograf',
      'lastra',
      'citolog',
      'istolog',
    ],
  ),
  (
    RecordCategory.therapy,
    ['terapia', 'antibiotic', 'antiparassit', 'farmaco', 'prescrizione'],
  ),
  (RecordCategory.visit, ['visita', 'controllo', 'consulto']),
];

/// The category a title suggests ("Emocromo 2026", "richiamo_vaccinale.pdf"),
/// or null when it says nothing. Only ever a proposal: the owner decides.
RecordCategory? suggestCategoryFromTitle(String title) {
  final lowered = title.toLowerCase();
  for (final (category, words) in _titleHints) {
    if (words.any(lowered.contains)) return category;
  }
  return null;
}
