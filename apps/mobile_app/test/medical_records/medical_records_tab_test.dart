import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vet_app_mobile/features/medical_records/data/medical_records_repository.dart';
import 'package:vet_app_mobile/features/medical_records/presentation/pet_medical_records_tab.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_models.dart';
import 'package:vet_app_mobile/l10n/app_localizations.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  Future<void> pumpTab(WidgetTester tester) async {
    final moka = samplePets.firstWhere((pet) => pet.name == 'Moka');
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PetMedicalRecordsTab(pet: moka, repository: MedicalRecordsRepository()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('the tab shows one tile per category with how many entries it holds', (tester) async {
    await pumpTab(tester);

    for (final label in ['Visite', 'Esami', 'Vaccini', 'Terapie', 'Documenti', 'Patologie']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    // Moka has one vaccine, one exam and one visit in the preview data, and
    // nothing else: the numbers follow the category of each entry.
    expect(find.text('1 registrato'), findsNWidgets(3));
    expect(find.text('0 registrati'), findsNWidgets(3));
  });

  testWidgets('a category without entries says so and offers to add the first one', (tester) async {
    await pumpTab(tester);

    await tester.tap(find.text('Terapie'));
    await tester.pumpAndSettle();

    expect(find.text('Nessuna terapia registrata'), findsOneWidget);
    expect(find.text('Aggiungi la prima terapia'), findsOneWidget);
  });

  testWidgets('a category lists its own entries and no others', (tester) async {
    await pumpTab(tester);

    await tester.tap(find.text('Esami'));
    await tester.pumpAndSettle();

    expect(find.text('Esame ematico di Moka'), findsOneWidget);
    expect(find.text('Richiamo vaccinale di Moka'), findsNothing);
  });

  testWidgets('"Invia" offers the whole history as a PDF even when no entry has a file', (
    tester,
  ) async {
    await pumpTab(tester);

    await tester.tap(find.text('Invia'));
    await tester.pumpAndSettle();

    expect(find.text('Tutto lo storico (PDF)'), findsOneWidget);
    expect(find.text('Un PDF con tutti gli eventi in ordine di data'), findsOneWidget);
  });

  testWidgets('the Storico calendar closes the page, with its own send button', (tester) async {
    await pumpTab(tester);

    await tester.scrollUntilVisible(find.text('Storico'), 300, scrollable: find.byType(Scrollable).first);

    expect(find.text('Storico'), findsOneWidget);
    expect(find.text('Invia storico'), findsOneWidget);
    expect(find.byTooltip('Mese precedente'), findsOneWidget);
  });
}
