import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/home/presentation/pages/home_dashboard_page.dart';
import 'package:vet_app_mobile/features/pet_news/domain/pet_news_item.dart';

PetNewsItem _item(String species, String title, {int hoursAgo = 0}) {
  return PetNewsItem(
    species: species,
    title: title,
    extract: 'Fonte',
    sourceUrl: 'https://example.com/$species/$title',
    publishedAt: DateTime(2026, 1, 1, 12).subtract(Duration(hours: hoursAgo)),
  );
}

void main() {
  group('selectHomeNewsSlots', () {
    test('always places a Generale item at index 2 when every category has results', () {
      final slots = selectHomeNewsSlots(
        nonGenericCategories: ['Cane', 'Gatto', 'Uccello'],
        poolByCategory: {
          'Cane': [_item('Cane', 'Cane 1')],
          'Gatto': [_item('Gatto', 'Gatto 1')],
          'Uccello': [_item('Uccello', 'Uccello 1')],
          'Generale': [_item('Generale', 'Generale 1')],
        },
      );

      expect(slots, hasLength(4));
      expect(slots[2].species, 'Generale');
    });

    test('keeps the invariant even when the Generale batch is the only one to land first '
        '(order of arrival must not matter — pools are passed in fully, but a caller that '
        'streamed them in in a different order must produce the same slot layout)', () {
      final slotsGeneraleFirst = selectHomeNewsSlots(
        nonGenericCategories: ['Cane', 'Gatto', 'Pesce'],
        poolByCategory: {
          'Generale': [_item('Generale', 'Generale 1')],
          'Cane': [_item('Cane', 'Cane 1')],
          'Gatto': [_item('Gatto', 'Gatto 1')],
          'Pesce': [_item('Pesce', 'Pesce 1')],
        },
      );
      final slotsGeneraleLast = selectHomeNewsSlots(
        nonGenericCategories: ['Cane', 'Gatto', 'Pesce'],
        poolByCategory: {
          'Cane': [_item('Cane', 'Cane 1')],
          'Gatto': [_item('Gatto', 'Gatto 1')],
          'Pesce': [_item('Pesce', 'Pesce 1')],
          'Generale': [_item('Generale', 'Generale 1')],
        },
      );

      expect(slotsGeneraleFirst[2].species, 'Generale');
      expect(slotsGeneraleLast[2].species, 'Generale');
    });

    test('falls back to Generale for owners with fewer than 3 species, backfilling from the '
        'same pool instead of repeating the same article', () {
      final slots = selectHomeNewsSlots(
        nonGenericCategories: ['Cane', 'Generale', 'Generale'],
        poolByCategory: {
          'Cane': [_item('Cane', 'Cane 1')],
          'Generale': [
            _item('Generale', 'Generale 1', hoursAgo: 0),
            _item('Generale', 'Generale 2', hoursAgo: 5),
            _item('Generale', 'Generale 3', hoursAgo: 10),
          ],
        },
      );

      expect(slots, hasLength(4));
      expect(slots[2].species, 'Generale');
      final titles = slots.map((i) => i.title).toSet();
      expect(titles, hasLength(4), reason: 'no article should be repeated across slots');
    });

    test('degrades gracefully (no Generale slot) when the Generale pool is entirely empty', () {
      final slots = selectHomeNewsSlots(
        nonGenericCategories: ['Cane', 'Gatto', 'Uccello'],
        poolByCategory: {
          'Cane': [_item('Cane', 'Cane 1')],
          'Gatto': [_item('Gatto', 'Gatto 1')],
          'Uccello': [_item('Uccello', 'Uccello 1')],
          'Generale': [],
        },
      );

      expect(slots, hasLength(3));
      expect(slots.every((i) => i.species != 'Generale'), isTrue);
    });
  });
}
