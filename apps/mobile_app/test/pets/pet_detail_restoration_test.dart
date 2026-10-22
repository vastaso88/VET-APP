import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vet_app_mobile/app/launch/route_restoration.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_models.dart';
import 'package:vet_app_mobile/features/pets/presentation/pages/pet_detail_page.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';

PetProfile _pet() => const PetProfile(
      id: 'p1',
      name: 'Tobia',
      species: 'Gatto',
      breed: '',
      birthDateLabel: '',
      sex: 'Maschio',
      weightLabel: '',
      medicalNote: '',
      healthBadge: '',
      nextVisitLabel: '',
      avatarEmoji: 'T',
      accentColor: Colors.white,
      identityColor: Colors.green,
    );

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the open card is remembered and reopened on the same card', (tester) async {
    Future<void> openPage(int initialTab) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('it'),
          home: ShellTabScope(
            index: 1,
            child: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => PetDetailPage(pet: _pet(), initialTab: initialTab),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }

    // The page marks itself in the global registry, wherever it is opened.
    await openPage(2);
    final entry = RouteRestoration.instance.snapshot().single;
    expect(entry.kind, 'pet_detail');
    expect(entry.tab, 1);
    expect(entry.args, {'petId': 'p1', 'tab': 2});

    // The Chat card (index 1): the saved tab follows what the owner picks.
    await tester.tap(find.byType(Tab).at(1));
    await tester.pumpAndSettle();
    expect(RouteRestoration.instance.snapshot().single.args['tab'], 1);

    // After the "restart" the same page opens straight on that card.
    await tester.pumpWidget(const SizedBox());
    await openPage(1);
    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.controller!.index, 1);
  });
}
