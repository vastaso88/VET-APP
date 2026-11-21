import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/pets/data/medical_record_consent_remote_data_source.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_models.dart';
import 'package:vet_app_mobile/features/pets/presentation/widgets/medical_record_consent_proposal.dart';
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
      breed: 'Meticcio / incrocio',
      birthDateLabel: '14 mag 2020',
      sex: 'Maschio',
      weightLabel: '23 kg',
      medicalNote: '',
      healthBadge: '',
      nextVisitLabel: '',
      avatarEmoji: 'T',
      accentColor: Colors.white,
      identityColor: Colors.green,
      medicalRecordConsentGranted: consent,
    );

Future<void> _open(WidgetTester tester, PetProfile pet, _FakeRemote remote) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            key: const ValueKey('go'),
            onPressed: () => proposeMedicalRecordConsent(context, pet, remote: remote),
            child: const Text('vai'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('go')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('"Più tardi" records nothing', (tester) async {
    final remote = _FakeRemote();
    await _open(tester, _pet(), remote);

    expect(find.text('Cartella clinica di Thor'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('consent-activate-not-now')));
    await tester.pumpAndSettle();

    expect(remote.calls, isEmpty);
  });

  testWidgets('"Attiva" records the consent for this animal', (tester) async {
    final remote = _FakeRemote();
    await _open(tester, _pet(), remote);

    await tester.tap(find.byKey(const ValueKey('consent-activate-yes')));
    await tester.pumpAndSettle();

    expect(remote.calls, [true]);
  });

  testWidgets('an animal that already has a decision is not asked again', (tester) async {
    final remote = _FakeRemote();
    await _open(tester, _pet(consent: false), remote);

    expect(find.text('Cartella clinica di Thor'), findsNothing);
    expect(remote.calls, isEmpty);
  });
}
