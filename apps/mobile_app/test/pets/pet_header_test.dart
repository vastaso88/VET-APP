import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_format.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_models.dart';
import 'package:vet_app_mobile/features/pets/presentation/pages/pet_detail_page.dart';

final _now = DateTime(2026, 10, 6);

PetProfile _pet({
  String species = 'Cane',
  String breed = 'Labrador Retriever',
  String birthDateLabel = '05 Ott 2023',
  String? dogSizeCategory,
  List<FishStock> aquariumStock = const [],
}) {
  return PetProfile(
    id: 'p',
    name: 'Tobia',
    species: species,
    breed: breed,
    birthDateLabel: birthDateLabel,
    sex: 'Maschio',
    weightLabel: '',
    medicalNote: '',
    healthBadge: '',
    nextVisitLabel: '',
    avatarEmoji: '🐶',
    accentColor: Colors.white,
    identityColor: Colors.green,
    dogSizeCategory: dogSizeCategory,
    aquariumStock: aquariumStock,
  );
}

void main() {
  group('parsePetBirthDateLabel', () {
    test('reads the three formats the app has stored', () {
      expect(parsePetBirthDateLabel('05 Mag 2021'), DateTime(2021, 5, 5));
      expect(parsePetBirthDateLabel('Mag 2021'), DateTime(2021, 5, 1));
      expect(parsePetBirthDateLabel('2021'), DateTime(2021));
    });

    test('is case-insensitive and null for empty or garbage', () {
      expect(parsePetBirthDateLabel('05 mag 2021'), DateTime(2021, 5, 5));
      expect(parsePetBirthDateLabel(''), isNull);
      expect(parsePetBirthDateLabel(null), isNull);
      expect(parsePetBirthDateLabel('ieri'), isNull);
      expect(parsePetBirthDateLabel('05 Xxx 2021'), isNull);
      expect(parsePetBirthDateLabel('40 Mag 2021'), isNull);
    });
  });

  group('petAgeLabel', () {
    test('years, singular and plural', () {
      expect(petAgeLabel('05 Ott 2023', now: _now), '3 anni');
      expect(petAgeLabel('05 Ott 2025', now: _now), '1 anno');
    });

    test('a birthday not yet reached this year does not count a year early', () {
      expect(petAgeLabel('07 Ott 2023', now: _now), '2 anni');
    });

    test('months under a year', () {
      expect(petAgeLabel('06 Mar 2026', now: _now), '7 mesi');
      expect(petAgeLabel('06 Set 2026', now: _now), '1 mese');
    });

    test('under a month', () {
      expect(petAgeLabel('20 Set 2026', now: _now), 'Meno di un mese');
    });

    test('nothing for a missing, unreadable or future date', () {
      expect(petAgeLabel('', now: _now), isNull);
      expect(petAgeLabel('boh', now: _now), isNull);
      expect(petAgeLabel('01 Gen 2030', now: _now), isNull);
    });
  });

  group('petHeaderSubtitle', () {
    test('species, breed and age', () {
      expect(petHeaderSubtitle(_pet(), now: _now), 'Cane · Labrador Retriever · 3 anni');
    });

    test('a missing breed is left out, not shown as a placeholder', () {
      expect(petHeaderSubtitle(_pet(breed: ''), now: _now), 'Cane · 3 anni');
    });

    test('a missing birth date leaves species and breed', () {
      expect(petHeaderSubtitle(_pet(birthDateLabel: ''), now: _now), 'Cane · Labrador Retriever');
    });

    test('nothing but the species when both are missing', () {
      expect(petHeaderSubtitle(_pet(breed: '', birthDateLabel: ''), now: _now), 'Cane');
    });

    test('the bare "Altro" breed is hidden, but with a size it says so', () {
      expect(petHeaderSubtitle(_pet(breed: 'Altro'), now: _now), 'Cane · 3 anni');
      expect(
        petHeaderSubtitle(_pet(breed: 'Altro', dogSizeCategory: 'Media'), now: _now),
        'Cane · Altro · Taglia Media · 3 anni',
      );
    });

    test('an aquarium shows its population and no age', () {
      final aquarium = _pet(
        species: 'Pesce',
        breed: '',
        birthDateLabel: '',
        aquariumStock: const [FishStock(species: 'Guppy', maleCount: 3, femaleCount: 2)],
      );

      expect(petHeaderSubtitle(aquarium, now: _now), 'Acquario · 1 specie · 5 pesci');
    });
  });

  group('PetTabLabel', () {
    const labels = ['Promemoria', 'Chat', 'Referti', 'Monitoraggio', 'Passeggiate'];

    Future<void> pumpTabs(WidgetTester tester, double width, {int selected = 0}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: DefaultTabController(
                  length: labels.length,
                  initialIndex: selected,
                  child: TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                    tabs: [for (final label in labels) PetTabLabel(label)],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('every title has the same font size', (tester) async {
      await pumpTabs(tester, 300);

      final sizes = {
        for (final label in labels)
          DefaultTextStyle.of(tester.element(find.text(label))).style.fontSize,
      };
      expect(sizes, hasLength(1), reason: 'no title may be smaller than the others');
    });

    testWidgets('the bar scrolls sideways instead of shrinking the titles', (tester) async {
      await pumpTabs(tester, 300);

      final bar = tester.widget<TabBar>(find.byType(TabBar));
      expect(bar.isScrollable, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the selected tab is scrolled into view', (tester) async {
      await pumpTabs(tester, 300, selected: 4);

      final bar = tester.getRect(find.byType(TabBar));
      final rect = tester.getRect(find.text('Passeggiate'));
      expect(rect.left, greaterThanOrEqualTo(bar.left));
      expect(rect.right, lessThanOrEqualTo(bar.right));
    });

    testWidgets('the label text is never truncated with an ellipsis', (tester) async {
      await pumpTabs(tester, 300);

      final text = tester.widget<Text>(find.text('Passeggiate'));
      expect(text.overflow, isNot(TextOverflow.ellipsis));
      expect(text.maxLines, 1);
    });
  });
}
