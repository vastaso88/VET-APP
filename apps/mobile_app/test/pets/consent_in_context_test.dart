import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/pets/data/medical_record_consent_remote_data_source.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_models.dart';
import 'package:vet_app_mobile/features/pets/presentation/widgets/medical_record_consent_card.dart';
import 'package:vet_app_mobile/l10n/app_localizations.dart';
import 'package:vet_app_mobile/shared/types/result.dart';

class _FakeRemote extends MedicalRecordConsentRemoteDataSource {
  final List<bool> calls = [];

  @override
  Future<Result<bool>> setGranted({required String petId, required bool granted}) async {
    calls.add(granted);
    return Result.success(granted);
  }
}

PetProfile _pet({bool? consent}) => PetProfile(
      id: 'p-1',
      name: 'Thor',
      species: 'Cane',
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
      medicalRecordConsentGranted: consent,
    );

Future<void> _open(WidgetTester tester, PetProfile pet, _FakeRemote remote) async {
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('it'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: MedicalRecordConsentCard(pet: pet, remote: remote)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('turning it on shows what it is first, and saves only after «Attiva»', (tester) async {
    final remote = _FakeRemote();
    await _open(tester, _pet(), remote);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.textContaining('fornitori di intelligenza artificiale'), findsOneWidget);
    expect(find.textContaining('Puoi spegnerlo quando vuoi'), findsOneWidget);
    expect(find.text('Leggi come viene usata'), findsWidgets);
    expect(remote.calls, isEmpty, reason: 'nothing recorded yet');

    await tester.tap(find.byKey(const ValueKey('consent-activate-yes')));
    await tester.pumpAndSettle();

    expect(remote.calls, [true]);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  testWidgets('«Non ora» records nothing and leaves the switch off', (tester) async {
    final remote = _FakeRemote();
    await _open(tester, _pet(), remote);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('consent-activate-not-now')));
    await tester.pumpAndSettle();

    expect(remote.calls, isEmpty);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets('turning it off is one tap, with no question', (tester) async {
    final remote = _FakeRemote();
    await _open(tester, _pet(consent: true), remote);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('consent-activate-yes')), findsNothing);
    expect(remote.calls, [false]);
  });

  testWidgets('the whole text opens from the question', (tester) async {
    await _open(tester, _pet(), _FakeRemote());

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('consent-read-how')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Anthropic'), findsOneWidget);
  });
}
