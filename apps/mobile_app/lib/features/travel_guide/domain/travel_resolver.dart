/// Picks, on the phone, the card that answers "from where, to where, with whom"
/// (docs/product/18 §2.1). Nothing here talks to the server.
library;

import 'travel_card.dart';
import 'travel_countries.dart';

/// What the screen shows for one traveller.
sealed class TravelAnswer {
  const TravelAnswer();
}

/// A card is available (it may be old, or hidden because it is too old).
class TravelCardAnswer extends TravelAnswer {
  const TravelCardAnswer(this.card, this.origin);

  final TravelCard card;
  final TravelOrigin origin;

  /// The blocks of the card that apply to this origin, in the order of
  /// [travelBlockKinds], without the blocks left empty by the filter.
  List<TravelBlock> get blocks {
    final result = <TravelBlock>[];
    for (final kind in travelBlockKinds) {
      for (final block in card.blocks.where((b) => b.kind == kind)) {
        final sentences = block.sentences.where((s) => s.appliesTo(origin)).toList();
        if (sentences.isNotEmpty) result.add(TravelBlock(kind: block.kind, sentences: sentences));
      }
    }
    return result;
  }
}

/// No verified card for this combination: the screen says so and points to
/// the official authority; it never invents one.
class NoTravelCardAnswer extends TravelAnswer {
  const NoTravelCardAnswer();
}

/// The species has no card in this version (only dog, cat and ferret).
class OtherSpeciesAnswer extends TravelAnswer {
  const OtherSpeciesAnswer();
}

/// Where the journey starts, from the point of view of the rules.
TravelOrigin originFor(String fromCode) =>
    isEuMemberState(fromCode) ? TravelOrigin.eu : TravelOrigin.nonEu;

/// The card country that answers a destination: any member state is covered by
/// the card common to the Union (`EU`); any other country by its own card.
String cardCountryFor(String toCode) => isEuMemberState(toCode) ? 'EU' : toCode.toUpperCase();

/// The answer for one species. [species] null means a species without cards.
TravelAnswer resolveTravel({
  required List<TravelCard> cards,
  required String fromCode,
  required String toCode,
  required TravelSpecies? species,
}) {
  if (species == null) return const OtherSpeciesAnswer();
  final country = cardCountryFor(toCode);
  for (final card in cards) {
    if (card.country == country && card.species == species) {
      return TravelCardAnswer(card, originFor(fromCode));
    }
  }
  return const NoTravelCardAnswer();
}
