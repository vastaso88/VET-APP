import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/pet_news/domain/pet_news_item.dart';
import 'package:vet_app_mobile/features/pet_news/presentation/widgets/pet_news_card.dart';

void main() {
  testWidgets('a story says it opens outside the app and shows three lines of title',
      (tester) async {
    final handle = tester.ensureSemantics();
    const title = 'Esempio: il gatto anziano che cambia abitudini e come accompagnarlo in casa';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 358,
            child: PetNewsCard(
              item: PetNewsItem(
                species: 'Gatto',
                title: title,
                extract: 'Fonte di esempio',
                sourceUrl: 'https://example.com/',
                publishedAt: DateTime(2026, 11, 25),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.open_in_new_rounded), findsOneWidget);
    expect(tester.widget<Text>(find.text(title)).maxLines, 3);
    expect(tester.getSemantics(find.text(title)), isSemantics(isLink: true));
    expect(tester.takeException(), isNull);
    handle.dispose();
  });
}
