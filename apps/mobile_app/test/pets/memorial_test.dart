import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/app/theme/app_theme.dart';
import 'package:vet_app_mobile/features/pets/application/memorial_service.dart';
import 'package:vet_app_mobile/features/pets/data/memorial_moments.dart';
import 'package:vet_app_mobile/features/pets/data/pet_demo_store.dart';
import 'package:vet_app_mobile/features/pets/data/pet_photo_repository.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_models.dart';
import 'package:vet_app_mobile/features/pets/presentation/pages/memorial_move_page.dart';
import 'package:vet_app_mobile/features/pets/presentation/pages/pet_memorial_page.dart';
import 'package:vet_app_mobile/features/pets/presentation/pages/pets_list_page.dart';
import 'package:vet_app_mobile/features/reminders/data/reminders_repository.dart';
import 'package:vet_app_mobile/features/reminders/domain/memorial_reminders.dart';
import 'package:vet_app_mobile/l10n/app_localizations.dart';

/// Ricordi (docs/product/17_ricordi_animali.md). Synthetic data only.
PetProfile _pet({
  String id = 'pet-moka',
  String name = 'Moka',
  String birth = '20 nov 2015',
  bool memorial = false,
  bool? consent,
}) =>
    PetProfile(
      id: id,
      name: name,
      species: 'Cane',
      breed: '',
      birthDateLabel: birth,
      sex: 'Femmina',
      weightLabel: '',
      medicalNote: '',
      healthBadge: '',
      nextVisitLabel: '',
      avatarEmoji: 'M',
      accentColor: Colors.white,
      identityColor: Colors.green,
      isMemorial: memorial,
      medicalRecordConsentGranted: consent,
    );

ReminderEntry _reminder(String id, {String petName = 'Moka', String? petId}) => ReminderEntry(
      id: id,
      petName: petName,
      petId: petId,
      title: 'Vaccino',
      kind: EventKind.spot,
      dueAt: DateTime(2026, 12, 1),
    );

Widget _app(Widget home) => MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('it'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    );

/// A phone-sized screen, and a tap after scrolling the target into view.
void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

class _Calls {
  final stoppedWalks = <String>[];
  final revoked = <String>[];
  final moved = <String>[];
  var restored = 0;

  MemorialService service() => MemorialService(
        store: PetDemoStore.instance,
        stopWalkOf: (id) async => stoppedWalks.add(id),
        revokeRecordsConsent: (id) async => revoked.add(id),
        onMoved: moved.add,
        onRestored: () => restored++,
      );
}

void main() {
  setUp(PetDemoStore.instance.reset);

  group('saved profile', () {
    test('the date of the loss and the three choices survive a reload', () {
      final pet = _pet(memorial: true).copyWith(
        memorialDate: DateTime(2026, 11, 14),
        memorialBirthdayReminder: true,
        memorialPhotosReminder: true,
      );
      final row = PetDemoStore.instance.petToRow(pet, 'owner-1');
      expect(row['memorial_date_label'], '14 nov 2026');
      final back = PetDemoStore.instance.petFromRow(row)!;
      expect(back.isMemorial, isTrue);
      expect(back.memorialDate, DateTime(2026, 11, 14));
      expect(back.memorialBirthdayReminder, isTrue);
      expect(back.memorialWalksReminder, isFalse);
      expect(back.memorialPhotosReminder, isTrue);
    });

    test('the choices are left out of the write while the SQL has not been run', () {
      final row = PetDemoStore.instance.petToRow(_pet(), 'owner-1');
      expect(PetDemoStore.memorialReminderColumns.every(row.containsKey), isTrue);
    });

    test('by name, an active pet wins over a pet in Ricordi with the same name', () async {
      await PetDemoStore.instance.upsert(_pet(id: 'old', memorial: true));
      await PetDemoStore.instance.upsert(_pet(id: 'new'));
      expect(PetDemoStore.instance.byName('moka')!.id, 'new');
    });
  });

  group('reminders of a pet in Ricordi', () {
    final old = _pet(id: 'old', memorial: true);
    final alive = _pet(id: 'new');

    test('recognised by pet id, or by name when no active pet has that name', () {
      expect(reminderBelongsToMemorialPet(_reminder('a', petId: 'old'), [old, alive]), isTrue);
      expect(reminderBelongsToMemorialPet(_reminder('b', petId: 'new'), [old, alive]), isFalse);
      expect(reminderBelongsToMemorialPet(_reminder('c'), [old, alive]), isFalse);
      expect(reminderBelongsToMemorialPet(_reminder('d'), [old]), isTrue);
      expect(reminderBelongsToMemorialPet(_reminder('e', petName: 'Rex'), [old]), isFalse);
    });

    test('hidden, never deleted', () {
      final all = [_reminder('a', petId: 'old'), _reminder('b', petId: 'new')];
      expect(remindersOfActivePets(all, [old, alive]).map((r) => r.id), ['b']);
      expect(all, hasLength(2));
    });
  });

  group('MemorialService', () {
    test('moving stops the walk, switches the records consent off, keeps the choices', () async {
      final calls = _Calls();
      final pet = await PetDemoStore.instance.upsert(_pet(consent: true));
      final moved = await calls.service().moveToMemories(
            pet,
            lossDate: DateTime(2026, 11, 14, 18, 30),
            choices: const MemorialReminderChoices(birthday: true),
          );
      expect(moved.isMemorial, isTrue);
      expect(moved.memorialDate, DateTime(2026, 11, 14));
      expect(moved.memorialBirthdayReminder, isTrue);
      expect(moved.memorialWalksReminder, isFalse);
      expect(moved.medicalRecordConsentGranted, isFalse);
      expect(calls.stoppedWalks, ['pet-moka']);
      expect(calls.revoked, ['pet-moka']);
      expect(calls.moved, ['pet-moka']);
      expect(PetDemoStore.instance.list(), isEmpty);
      expect(PetDemoStore.instance.memorialPets().single.id, 'pet-moka');
    });

    test('no consent call when the chat never had it', () async {
      final calls = _Calls();
      final pet = await PetDemoStore.instance.upsert(_pet());
      await calls.service().moveToMemories(pet, lossDate: DateTime(2026, 11, 14));
      expect(calls.revoked, isEmpty);
    });

    test('bringing back clears the date and the memories, the consent stays off', () async {
      final calls = _Calls();
      final pet = await PetDemoStore.instance.upsert(_pet(consent: true));
      final moved = await calls.service().moveToMemories(
            pet,
            lossDate: DateTime(2026, 11, 14),
            choices: const MemorialReminderChoices(birthday: true, photos: true),
          );
      final back = await calls.service().restore(moved);
      expect(back.isMemorial, isFalse);
      expect(back.memorialDate, isNull);
      expect(back.memorialBirthdayReminder || back.memorialPhotosReminder, isFalse);
      expect(back.medicalRecordConsentGranted, isFalse);
      expect(calls.restored, 1);
      expect(PetDemoStore.instance.list().single.id, 'pet-moka');
    });
  });

  group('photos for a memory', () {
    PetPhotoEntry photo(String id, DateTime? takenAt) => PetPhotoEntry(
          id: id,
          petId: 'pet-moka',
          storagePath: 'o/pet-moka/$id.jpg',
          createdAt: DateTime(2026, 1, 1),
          isProfile: false,
          takenAt: takenAt,
        );

    test('around past birthdays, on this day, during a walk', () {
      final photos = [
        photo('b1', DateTime(2024, 11, 21, 10)),
        photo('b2', DateTime(2023, 11, 10, 10)),
        photo('d1', DateTime(2025, 11, 20, 10)),
        photo('none', null),
      ];
      final birthday = DateTime(2026, 11, 20);
      expect(photosAroundAnniversary(photos, birthday).map((p) => p.id), ['b1', 'd1']);
      expect(photosOnThisDay(photos, birthday).map((p) => p.id), ['d1']);
    });
  });

  group('move flow', () {
    testWidgets('date, then the memories asked gently, all off', (tester) async {
      _phone(tester);
      final calls = _Calls();
      final pet = await PetDemoStore.instance.upsert(_pet());
      PetProfile? result;
      await tester.pumpWidget(_app(Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<PetProfile>(
                MaterialPageRoute(
                  builder: (_) => MemorialMovePage(
                    pet: pet,
                    service: calls.service(),
                    loadMoments: (_) async => const MemorialMoments(),
                    today: DateTime(2026, 11, 16),
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Ci dispiace tanto per Moka.'), findsOneWidget);
      expect(find.text('Data della perdita'), findsOneWidget);
      expect(find.text('16 novembre 2026'), findsOneWidget);

      await _tap(tester, find.text('Continua'));

      expect(find.text('Vuoi che Quokka ti aiuti a ricordare?'), findsOneWidget);
      // Birth date known: birthday offered. No favourite walk or dated photo:
      // those two are not shown at all.
      expect(find.byKey(const ValueKey('memorial-switch-birthday')), findsOneWidget);
      expect(find.byKey(const ValueKey('memorial-switch-walks')), findsNothing);
      expect(find.byKey(const ValueKey('memorial-switch-photos')), findsNothing);
      final birthday = tester.widget<SwitchListTile>(
        find.byKey(const ValueKey('memorial-switch-birthday')),
      );
      expect(birthday.value, isFalse);

      await _tap(tester, find.byKey(const ValueKey('memorial-switch-birthday')));
      await _tap(tester, find.byKey(const ValueKey('memorial-confirm')));

      expect(result?.isMemorial, isTrue);
      expect(result?.memorialDate, DateTime(2026, 11, 16));
      expect(result?.memorialBirthdayReminder, isTrue);
      expect(calls.moved, ['pet-moka']);
    });

    testWidgets('nothing to remember: the second step is skipped', (tester) async {
      _phone(tester);
      final calls = _Calls();
      final pet = await PetDemoStore.instance.upsert(_pet(birth: 'mag 2020'));
      await tester.pumpWidget(_app(MemorialMovePage(
        pet: pet,
        service: calls.service(),
        loadMoments: (_) async => const MemorialMoments(),
      )));
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Continua'));
      expect(find.text('Vuoi che Quokka ti aiuti a ricordare?'), findsNothing);
      expect(calls.moved, ['pet-moka']);
    });
  });

  group('Animali list', () {
    testWidgets('Ricordi is a quiet row at the bottom, not a button at the top', (tester) async {
      _phone(tester);
      await PetDemoStore.instance.upsert(_pet(id: 'old', name: 'Briciola', memorial: true));
      await PetDemoStore.instance.upsert(_pet(id: 'new', name: 'Rex'));
      await tester.pumpWidget(_app(const PetsListPage()));
      await tester.pumpAndSettle();

      expect(find.text('Rex'), findsOneWidget);
      expect(find.text('Briciola'), findsNothing);
      expect(find.byKey(const ValueKey('memories-row')), findsOneWidget);
      expect(find.text('Gli animali che hanno condiviso la tua strada'), findsOneWidget);
      expect(find.byTooltip('Ricordi'), findsNothing);
      final rexY = tester.getTopLeft(find.text('Rex')).dy;
      final rowY = tester.getTopLeft(find.byKey(const ValueKey('memories-row'))).dy;
      expect(rowY, greaterThan(rexY));
    });

    testWidgets('only memories left: no pressure to add a pet', (tester) async {
      _phone(tester);
      await PetDemoStore.instance.upsert(_pet(id: 'old', name: 'Briciola', memorial: true));
      await tester.pumpWidget(_app(const PetsListPage()));
      await tester.pumpAndSettle();
      expect(find.text('Nessun animale nella lista'), findsOneWidget);
      expect(find.byKey(const ValueKey('memories-row')), findsOneWidget);
    });

    testWidgets('no memories, no row', (tester) async {
      _phone(tester);
      await PetDemoStore.instance.upsert(_pet(id: 'new', name: 'Rex'));
      await tester.pumpWidget(_app(const PetsListPage()));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('memories-row')), findsNothing);
    });
  });

  group('memorial page', () {
    Future<void> open(WidgetTester tester, PetProfile pet, _Calls calls) async {
      await tester.pumpWidget(_app(PetMemorialPage(
        pet: pet,
        service: calls.service(),
        loadMoments: (_) async => const MemorialMoments(),
        today: DateTime(2026, 11, 16),
      )));
      await tester.pumpAndSettle();
    }

    testWidgets('dates, memory switches, and the registry note only with a microchip',
        (tester) async {
      _phone(tester);
      final pet = (await PetDemoStore.instance.upsert(_pet(memorial: true)))
          .copyWith(memorialDate: DateTime(2026, 11, 14), microchipNumber: '380260000000001');
      await open(tester, pet, _Calls());
      expect(find.textContaining('al 14 nov 2026'), findsOneWidget);
      expect(find.byKey(const ValueKey('memorial-switch-birthday')), findsOneWidget);
      await tester.scrollUntilVisible(find.textContaining('anagrafe'), 200);
      expect(find.textContaining('Se Moka era iscritta all'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await open(tester, pet.copyWith(clearMicrochipNumber: true), _Calls());
      expect(find.textContaining('anagrafe'), findsNothing);
    });

    testWidgets('bring back asks first, then restores', (tester) async {
      _phone(tester);
      final calls = _Calls();
      final pet = await PetDemoStore.instance
          .upsert(_pet(memorial: true).copyWith(memorialDate: DateTime(2026, 11, 14)));
      await open(tester, pet, calls);
      // At the very bottom of a lazy list: scroll down to it first.
      await tester.scrollUntilVisible(find.byKey(const ValueKey('memorial-restore')), 300);
      await _tap(tester, find.byKey(const ValueKey('memorial-restore')));
      expect(find.text('Riportare Moka tra gli animali?'), findsOneWidget);
      await _tap(tester, find.widgetWithText(FilledButton, 'Riporta tra gli animali'));
      expect(calls.restored, 1);
      expect(PetDemoStore.instance.list().single.isMemorial, isFalse);
    });
  });
}
