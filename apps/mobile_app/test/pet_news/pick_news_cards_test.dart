import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/pet_news/domain/pet_news_item.dart';
import 'package:vet_app_mobile/features/pet_news/presentation/pages/news_feed_page.dart';

PetNewsItem _item(String species, String title) {
  return PetNewsItem(
    species: species,
    title: title,
    extract: 'Fonte',
    sourceUrl: 'https://example.com/$species/$title',
  );
}

void main() {
  group('pickNewsCards', () {
    test('always includes a Generale card when requireGeneric is true and one is available', () {
      final candidates = [
        _item('Cane', 'Cane 1'),
        _item('Cane', 'Cane 2'),
        _item('Gatto', 'Gatto 1'),
        _item('Gatto', 'Gatto 2'),
        _item('Uccello', 'Uccello 1'),
        _item('Pesce', 'Pesce 1'),
        _item('Generale', 'Generale 1'),
      ];

      // Run several times: this is randomized (shuffle), so the guarantee
      // must hold regardless of which seed picks which 6 cards.
      for (var seed = 0; seed < 20; seed++) {
        final picked = pickNewsCards(
          candidates: candidates,
          count: 6,
          random: Random(seed),
          requireGeneric: true,
        );
        expect(picked.any((i) => i.species == 'Generale'), isTrue, reason: 'seed $seed');
      }
    });

    test('does not force a Generale card when requireGeneric is false (category filter active)', () {
      final candidates = [
        _item('Cane', 'Cane 1'),
        _item('Cane', 'Cane 2'),
        _item('Cane', 'Cane 3'),
      ];

      final picked = pickNewsCards(
        candidates: candidates,
        count: 6,
        random: Random(1),
        requireGeneric: false,
      );

      expect(picked.every((i) => i.species == 'Cane'), isTrue);
    });

    test('does not crash or fabricate a Generale card when none exists in the pool', () {
      final candidates = [_item('Cane', 'Cane 1'), _item('Gatto', 'Gatto 1')];

      final picked = pickNewsCards(
        candidates: candidates,
        count: 6,
        random: Random(2),
        requireGeneric: true,
      );

      expect(picked, hasLength(2));
      expect(picked.any((i) => i.species == 'Generale'), isFalse);
    });

    test('avoids repeating the last-shown links when enough fresh candidates exist', () {
      final candidates = List.generate(10, (i) => _item('Cane', 'Cane $i'));
      final avoid = {candidates[0].sourceUrl, candidates[1].sourceUrl};

      final picked = pickNewsCards(
        candidates: candidates,
        count: 6,
        random: Random(3),
        avoidLinks: avoid,
        requireGeneric: false,
      );

      expect(picked.any((i) => avoid.contains(i.sourceUrl)), isFalse);
    });
  });
}
