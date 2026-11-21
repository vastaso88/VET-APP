import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vet_app_mobile/app/theme/app_theme.dart';
import 'package:vet_app_mobile/features/billing/data/billing_demo_store.dart';
import 'package:vet_app_mobile/features/billing/data/plan_access_refusal.dart';
import 'package:vet_app_mobile/features/billing/data/subscription_remote_data_source.dart';
import 'package:vet_app_mobile/features/billing/domain/billing_models.dart';
import 'package:vet_app_mobile/features/billing/domain/subscription_status.dart';
import 'package:vet_app_mobile/features/pets/application/memorial_service.dart';
import 'package:vet_app_mobile/features/pets/data/memorial_moments.dart';
import 'package:vet_app_mobile/features/pets/data/pet_demo_store.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_models.dart';
import 'package:vet_app_mobile/features/pets/presentation/pages/memorial_move_page.dart';
import 'package:vet_app_mobile/features/pets/presentation/pages/pet_edit_page.dart';
import 'package:vet_app_mobile/l10n/app_localizations.dart';
import 'package:vet_app_mobile/shared/errors/app_network_error.dart';
import 'package:vet_app_mobile/shared/types/result.dart';

/// The cap on pets kept in Ricordi (owner decision 2026-11-16): a setting of the
/// backend that the app only reads and shows, never a number of its own.
/// Synthetic data only.
PetProfile _pet(String id, {bool memorial = false, String name = 'Moka'}) => PetProfile(
      id: id,
      name: name,
      species: 'Cane',
      breed: '',
      birthDateLabel: '',
      sex: 'Femmina',
      weightLabel: '',
      medicalNote: '',
      healthBadge: '',
      nextVisitLabel: '',
      avatarEmoji: 'M',
      accentColor: Colors.white,
      identityColor: Colors.green,
      isMemorial: memorial,
    );

class _Moves {
  final moved = <String>[];
  final walksStopped = <String>[];

  MemorialService service({int? cap}) => MemorialService(
        store: PetDemoStore.instance,
        stopWalkOf: (id) async => walksStopped.add(id),
        revokeRecordsConsent: (_) async {},
        onMoved: moved.add,
        onRestored: () {},
        planLimit: () => (limit: null, upgradePlan: null),
        memorialLimit: () => cap,
      );
}

const _memorialsRefusal = PostgrestException(
  message: 'plan_limit_reached',
  code: 'PT403',
  details: 'memorials',
  hint: '3',
);

class _FakeSource implements SubscriptionRemoteDataSource {
  _FakeSource(this.status);

  final SubscriptionStatus status;

  @override
  Future<Result<SubscriptionStatus>> fetchStatus() async => Result.success(status);

  @override
  Future<Result<SubscriptionStatus>> selectPlan(PlanTier plan) async =>
      Result.failure(const AppNetworkError(code: 'no', message: 'no'));
}

SubscriptionStatus _status({int? memorialCap}) => SubscriptionStatus(
      trialEndsAt: DateTime.now().add(const Duration(days: 9)),
      plan: PlanTier.plus,
      isDeveloper: false,
      hasAccess: true,
      maxMemorialPets: memorialCap,
    );

Map<String, dynamic> _json({Object? cap, bool withCap = true}) => {
      'subscription': {
        'trial_ends_at': DateTime.now().add(const Duration(days: 9)).toIso8601String(),
        'plan': 'plus',
      },
      'is_developer': false,
      'has_access': true,
      if (withCap) 'max_memorial_pets': cap,
    };

Widget _app(Widget home, {Locale locale = const Locale('it')}) => MaterialApp(
      theme: AppTheme.light(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    );

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _fillMemories(int count) async {
  for (var i = 0; i < count; i++) {
    await PetDemoStore.instance.upsert(_pet('m$i', memorial: true, name: 'Ricordo $i'));
  }
}

void main() {
  setUp(PetDemoStore.instance.reset);
  tearDown(() {
    PetDemoStore.instance.debugUpsertRow = null;
    BillingDemoStore.instance.reset();
  });

  group('the cap is the backend setting, never a number of the app', () {
    test('it is read from the status', () {
      final status = SubscriptionStatus.fromJson(_json(cap: 12));

      expect(status.maxMemorialPets, 12);
    });

    test('a missing, zero, negative or odd value reads as "not known"', () {
      expect(SubscriptionStatus.fromJson(_json(withCap: false)).maxMemorialPets, isNull);
      expect(SubscriptionStatus.fromJson(_json(cap: 0)).maxMemorialPets, isNull);
      expect(SubscriptionStatus.fromJson(_json(cap: -4)).maxMemorialPets, isNull);
      expect(SubscriptionStatus.fromJson(_json(cap: '30')).maxMemorialPets, isNull);
      expect(SubscriptionStatus.fromJson(_json(cap: null)).maxMemorialPets, isNull);
    });

    test('the billing store hands it to the rest of the app', () async {
      expect(BillingDemoStore.instance.memorialPetsMax, isNull, reason: 'not loaded yet');

      await BillingDemoStore.instance
          .syncFromBackend(dataSource: _FakeSource(_status(memorialCap: 12)));

      expect(BillingDemoStore.instance.memorialPetsMax, 12);
    });

    test('changing the number changes where the move stops (no literal in the app)', () async {
      await _fillMemories(5);
      final pet = await PetDemoStore.instance.upsert(_pet('a', name: 'Rex'));

      await expectLater(
        _Moves().service(cap: 5).moveToMemories(pet, lossDate: DateTime(2026, 11, 1)),
        throwsA(isA<MemoriesFullBlocksMove>().having((e) => e.limit, 'limit', 5)),
      );
      final moved =
          await _Moves().service(cap: 6).moveToMemories(pet, lossDate: DateTime(2026, 11, 1));

      expect(moved.isMemorial, isTrue);
      expect(PetDemoStore.instance.memorialPets().length, 6);
    });
  });

  group('moving a pet to Ricordi', () {
    test('with Ricordi full the move is refused before anything changes', () async {
      final store = PetDemoStore.instance;
      await _fillMemories(3);
      final pet = await store.upsert(_pet('a', name: 'Rex'));
      final moves = _Moves();

      await expectLater(
        moves.service(cap: 3).moveToMemories(pet, lossDate: DateTime(2026, 11, 1)),
        throwsA(isA<MemoriesFullBlocksMove>().having((e) => e.limit, 'limit', 3)),
      );

      expect(store.list().single.id, 'a', reason: 'still among the active pets');
      expect(store.list().single.isMemorial, isFalse);
      expect(store.memorialPets().length, 3);
      expect(moves.walksStopped, isEmpty, reason: 'a walk in progress is not closed');
      expect(moves.moved, isEmpty, reason: 'nothing was refreshed or scheduled');
    });

    test('one place left is enough, none left is not', () async {
      await _fillMemories(2);
      final first = await PetDemoStore.instance.upsert(_pet('a', name: 'Rex'));
      final second = await PetDemoStore.instance.upsert(_pet('b', name: 'Luna'));
      final service = _Moves().service(cap: 3);

      await service.moveToMemories(first, lossDate: DateTime(2026, 11, 1)); // 3rd of 3
      await expectLater(
        service.moveToMemories(second, lossDate: DateTime(2026, 11, 1)),
        throwsA(isA<MemoriesFullBlocksMove>()),
      );
    });

    test('active pets take no place of Ricordi', () async {
      final store = PetDemoStore.instance;
      for (var i = 0; i < 5; i++) {
        await store.upsert(_pet('a$i', name: 'Attivo $i'));
      }

      final moved = await _Moves()
          .service(cap: 2)
          .moveToMemories(store.byId('a0')!, lossDate: DateTime(2026, 11, 1));

      expect(moved.isMemorial, isTrue);
    });

    test('deleting one from Ricordi frees a place', () async {
      final store = PetDemoStore.instance;
      await _fillMemories(3);
      final pet = await store.upsert(_pet('a', name: 'Rex'));
      final service = _Moves().service(cap: 3);
      await expectLater(
        service.moveToMemories(pet, lossDate: DateTime(2026, 11, 1)),
        throwsA(isA<MemoriesFullBlocksMove>()),
      );

      await store.delete('m0');
      final moved = await service.moveToMemories(pet, lossDate: DateTime(2026, 11, 1));

      expect(moved.isMemorial, isTrue);
      expect(store.memorialPets().length, 3);
    });

    test('with no known cap (not loaded yet) the server decides', () async {
      await _fillMemories(40);
      final pet = await PetDemoStore.instance.upsert(_pet('a', name: 'Rex'));

      final moved =
          await _Moves().service().moveToMemories(pet, lossDate: DateTime(2026, 11, 1));

      expect(moved.isMemorial, isTrue);
    });

    test('user B starts from zero, whatever user A has in Ricordi', () async {
      final store = PetDemoStore.instance;
      await _fillMemories(3); // user A is at the cap
      expect(store.memorialPets().length, 3);

      store.reset(); // signing out clears the account's pets (bootstrap.dart `signedOut`)
      final petOfB = await store.upsert(_pet('b1', name: 'Pallina'));
      final moved = await _Moves()
          .service(cap: 3)
          .moveToMemories(petOfB, lossDate: DateTime(2026, 11, 1));

      expect(moved.isMemorial, isTrue);
      expect(store.memorialPets().map((pet) => pet.id), ['b1']);
    });

    test('asked early, the check changes nothing and says how many Ricordi holds', () async {
      await _fillMemories(3);
      final moves = _Moves();

      expect(
        () => moves.service(cap: 3).ensureRoomInMemories(),
        throwsA(isA<MemoriesFullBlocksMove>().having((e) => e.limit, 'limit', 3)),
      );
      expect(() => moves.service(cap: 4).ensureRoomInMemories(), returnsNormally);
      expect(() => moves.service().ensureRoomInMemories(), returnsNormally);
    });
  });

  group('the server refuses (the app count was out of date)', () {
    test('the pet goes back among the active ones, unflagged, with the server number', () async {
      final store = PetDemoStore.instance;
      final pet = await store.upsert(_pet('a', name: 'Rex'));
      final moves = _Moves();
      store.debugUpsertRow = (row) async {
        if (row['is_memorial'] == true) throw _memorialsRefusal;
      };

      await expectLater(
        // The app thinks there is room (no cap known): the server says no.
        moves.service().moveToMemories(pet, lossDate: DateTime(2026, 11, 1)),
        throwsA(isA<MemoriesFullBlocksMove>().having((e) => e.limit, 'limit', 3)),
      );

      expect(store.list().single.id, 'a');
      expect(store.memorialPets(), isEmpty);
      expect(store.isUnsynced('a'), isFalse, reason: 'not "moved but not synced"');
      expect(moves.moved, isEmpty);
      // Known and accepted: a walk in progress was closed (and saved) before the
      // server answered; the pet itself is untouched.
      expect(moves.walksStopped, ['a']);
    });

    test('any other failure is undone here and says so: the pet stays among the active ones',
        () async {
      final store = PetDemoStore.instance;
      final pet = await store.upsert(_pet('a', name: 'Rex'));
      store.debugUpsertRow = (row) async {
        throw const PostgrestException(message: 'boom', code: '500');
      };

      await expectLater(
        _Moves().service().moveToMemories(pet, lossDate: DateTime(2026, 11, 1)),
        throwsA(isA<PetSyncException>()),
      );

      expect(store.list().single.id, 'a');
      expect(store.memorialPets(), isEmpty);
      expect(store.isUnsynced('a'), isFalse);
    });

    test('a refusal is recognised as the cap, with its own message and number', () {
      final refusal = planRefusalFromError(_memorialsRefusal)!;

      expect(refusal.kind, PlanRefusalKind.planLimitReached);
      expect(refusal.limitKind, 'memorials');
      expect(refusal.limit, 3);
    });
  });

  group('what the owner reads', () {
    testWidgets('from the pet page: a kind dialog, and the farewell flow never opens',
        (tester) async {
      _phone(tester);
      final store = PetDemoStore.instance;
      await BillingDemoStore.instance
          .syncFromBackend(dataSource: _FakeSource(_status(memorialCap: 3)));
      await _fillMemories(3);
      final pet = await store.upsert(_pet('a', name: 'Rex'));
      await tester.pumpWidget(_app(PetEditPage(pet: pet)));
      await tester.pumpAndSettle();

      final action = find.text('Sposta nei ricordi');
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();

      final dialog = find.byKey(const ValueKey('memorial-move-blocked'));
      expect(dialog, findsOneWidget);
      expect(find.byType(MemorialMovePage), findsNothing, reason: 'no date asked for nothing');
      final text =
          tester.widget<Text>(find.descendant(of: dialog, matching: find.byType(Text)).first);
      expect(
          text.data,
          startsWith('Per ora Rex resta tra i tuoi animali, con tutti i suoi dati: '
              'non si perde niente.'),
          reason: 'the reassurance comes first');
      expect(text.data, contains('Nei Ricordi c\'è posto per 3 animali'));
      expect(text.data, contains('adesso è tutto occupato'));
      // The real name of the button, and an invitation that is no push.
      expect(text.data, contains('«Elimina per sempre» nella pagina di un ricordo'));
      expect(text.data, contains('solo se e quando te la senti'));
      // While Ricordi is full the pet stays active: its reminders can be deleted (the
      // app has no "turn off", so the text does not promise one).
      expect(text.data,
          endsWith('Intanto, se i promemoria di Rex ti pesano, puoi eliminarli da Promemoria.'));
      expect(text.data, isNot(contains('spegner')));
      expect(text.data, isNot(contains('spostarne un altro')), reason: 'it is about this pet');
      expect(text.data, isNot(contains('piano')), reason: 'a plan does not buy more Ricordi');
      expect(find.descendant(of: dialog, matching: find.byType(TextButton)), findsOneWidget,
          reason: 'one button, OK');
      expect(find.descendant(of: dialog, matching: find.byType(FilledButton)), findsNothing);

      await tester.tap(find.descendant(of: dialog, matching: find.text('OK')));
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);
      expect(find.byType(PetEditPage), findsOneWidget);
      expect(store.list().single.isMemorial, isFalse);
    });

    testWidgets('with room left the flow opens as before', (tester) async {
      _phone(tester);
      final store = PetDemoStore.instance;
      await BillingDemoStore.instance
          .syncFromBackend(dataSource: _FakeSource(_status(memorialCap: 4)));
      await _fillMemories(3);
      final pet = await store.upsert(_pet('a', name: 'Rex'));
      await tester.pumpWidget(_app(PetEditPage(pet: pet)));
      await tester.pumpAndSettle();

      final action = find.text('Sposta nei ricordi');
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('memorial-move-blocked')), findsNothing);
      expect(find.byType(MemorialMovePage), findsOneWidget);
    });

    testWidgets('from the move window, when only the server knew: the same dialog, then back',
        (tester) async {
      _phone(tester);
      final store = PetDemoStore.instance;
      final pet = await store.upsert(_pet('a', name: 'Rex'));
      store.debugUpsertRow = (row) async {
        if (row['is_memorial'] == true) throw _memorialsRefusal;
      };
      await tester.pumpWidget(_app(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => MemorialMovePage(
                    pet: pet,
                    service: _Moves().service(),
                    loadMoments: (_) async => const MemorialMoments(),
                  ),
                )),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Continua'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continua'));
      await tester.pumpAndSettle();

      final dialog = find.byKey(const ValueKey('memorial-move-blocked'));
      expect(dialog, findsOneWidget);
      expect(find.textContaining('Nei Ricordi c\'è posto per 3 animali'), findsOneWidget);
      expect(store.list().single.isMemorial, isFalse);
      expect(store.isUnsynced('a'), isFalse);

      await tester.tap(find.descendant(of: dialog, matching: find.text('OK')));
      await tester.pumpAndSettle();
      expect(find.byType(MemorialMovePage), findsNothing, reason: 'back to the pet');
      expect(find.text('open'), findsOneWidget);
    });

    test('the message of a refusal that reaches the generic path says Ricordi, not the plan', () {
      const memorials =
          PlanAccessRefusal(PlanRefusalKind.planLimitReached, limitKind: 'memorials');
      const pets = PlanAccessRefusal(PlanRefusalKind.planLimitReached, limitKind: 'pets');

      expect(memorials.message, startsWith('Nei Ricordi non c\'è più posto.'));
      expect(memorials.message, contains('«Elimina per sempre»'));
      expect(memorials.message, isNot(contains('piano')));
      expect(memorials.message, isNot(pets.message));
    });

    for (final language in ['it', 'en', 'es', 'de', 'fr']) {
      test('the new texts exist and carry their values in $language', () {
        final l10n = lookupAppLocalizations(Locale(language));

        final blocked = l10n.memorialMoveBlockedFull('Moka', 30);
        expect(blocked, allOf(contains('Moka'), contains('30')));
        expect(blocked, isNot(contains('{')), reason: 'no placeholder left over');
        // The way to free a place names the button as the app writes it.
        expect(blocked, contains(l10n.petsMemoriesRemoveAction));
        expect(l10n.billingPlanLimitMemorials, contains(l10n.petsMemoriesRemoveAction));
        expect(l10n.billingPlanLimitMemorials, isNot(contains('{')));
      });
    }
  });
}
