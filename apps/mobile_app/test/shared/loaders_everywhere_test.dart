import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/app/splash/loading_animation.dart';
import 'package:vet_app_mobile/app/splash/splash_messages.dart';
import 'package:vet_app_mobile/features/pet_news/presentation/pages/news_feed_page.dart';
import 'package:vet_app_mobile/features/reminders/presentation/pages/reminders_pages.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';
import 'package:vet_app_mobile/shared/widgets/pet_loader.dart';

Widget _app(Widget home) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('it'),
      home: home,
    );

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the news page shows the spinning animal while it loads', (tester) async {
    await tester.pumpWidget(_app(const NewsFeedPage()));

    expect(find.byType(PetLoader), findsOneWidget);
    expect(find.text('Carico le notizie...'), findsOneWidget);
    expect(find.byType(SplashAnimalTicker), findsNothing);

    await tester.pumpAndSettle(const Duration(milliseconds: 200));
  });

  testWidgets('the reminders page shows the spinning animal while it loads', (tester) async {
    await tester.pumpWidget(_app(const RemindersListPage()));

    expect(find.byType(PetLoader), findsOneWidget);

    await tester.pumpAndSettle(const Duration(milliseconds: 200));
  });

  group('the animal strip', () {
    final original = SplashAnimalTicker.orderOf;
    tearDown(() => SplashAnimalTicker.orderOf = original);

    test('its order is a shuffle of the same animals, and it varies', () {
      final orders = {for (var i = 0; i < 40; i++) original(splashAnimals).join()};

      for (final order in orders) {
        expect(order.runes.length, splashAnimals.join().runes.length);
      }
      expect(orders.length, greaterThan(1), reason: 'not always dog and cat first');
    });

    testWidgets('the strip uses the order it was given', (tester) async {
      SplashAnimalTicker.orderOf = (animals) => animals.reversed.toList();

      await tester.pumpWidget(_app(const Scaffold(body: Center(child: SplashAnimalTicker()))));

      // The strip is laid out starting from the first animal of its order.
      final first = tester.widget<Text>(find.text(splashAnimals.last));
      expect(first.data, splashAnimals.last);
      expect(
        tester.getTopLeft(find.text(splashAnimals.last)).dx,
        lessThan(tester.getTopLeft(find.text(splashAnimals.first)).dx),
      );
    });
  });
}
