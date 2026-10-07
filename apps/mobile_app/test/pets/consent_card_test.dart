import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_models.dart';
import 'package:vet_app_mobile/features/pets/presentation/widgets/medical_record_consent_card.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('the card is one collapsed row; tapping expands the full text and tapping again closes it',
      (tester) async {
    final pet = samplePets.first;
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: MedicalRecordConsentCard(pet: pet))),
    );

    expect(find.text('Leggi come viene usata'), findsOneWidget);
    expect(find.textContaining('fornitore esterno'), findsNothing);
    expect(find.byType(Switch), findsOneWidget);

    await tester.tap(find.text('Leggi come viene usata'));
    await tester.pump();
    expect(find.textContaining('fornitore esterno'), findsOneWidget);
    expect(find.text('Chiudi'), findsOneWidget);

    await tester.tap(find.text('Chiudi'));
    await tester.pump();
    expect(find.textContaining('fornitore esterno'), findsNothing);
  });
}
