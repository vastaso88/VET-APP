import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vet_app_mobile/app/theme/app_theme.dart';
import 'package:vet_app_mobile/features/billing/data/billing_demo_store.dart';
import 'package:vet_app_mobile/features/billing/data/plan_access_refusal.dart';
import 'package:vet_app_mobile/features/billing/data/subscription_remote_data_source.dart';
import 'package:vet_app_mobile/features/billing/domain/billing_models.dart';
import 'package:vet_app_mobile/features/billing/domain/subscription_status.dart';
import 'package:vet_app_mobile/features/billing/presentation/widgets/plan_feature_list.dart';
import 'package:vet_app_mobile/features/pets/application/memorial_service.dart';
import 'package:vet_app_mobile/features/pets/data/memorial_moments.dart';
import 'package:vet_app_mobile/features/pets/data/pet_demo_store.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_models.dart';
import 'package:vet_app_mobile/features/pets/presentation/pages/memorial_move_page.dart';
import 'package:vet_app_mobile/features/pets/presentation/pages/pet_memorial_page.dart';
import 'package:vet_app_mobile/l10n/app_localizations.dart';
import 'package:vet_app_mobile/shared/errors/app_network_error.dart';
import 'package:vet_app_mobile/shared/types/result.dart';

/// Pets in Ricordi do not take a place of the plan; bringing one back needs a
/// free place (owner decision 2026-11-16). Synthetic data only.
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

typedef _Plan = ({int? limit, String? upgradePlan});

class _Restores {
  var count = 0;

  MemorialService service(_Plan plan) => MemorialService(
        store: PetDemoStore.instance,
        stopWalkOf: (_) async {},
        revokeRecordsConsent: (_) async {},
        onMoved: (_) {},
        onRestored: () => count++,
        planLimit: () => plan,
      );
}

const _planRefusal = PostgrestException(
  message: 'plan_limit_reached',
  code: 'PT403',
  details: 'pets',
  hint: '2',
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

SubscriptionStatus _status({
  PlanTier? plan,
  bool testPeriod = false,
  int maxPets = 2,
  bool hasAccess = true,
}) {
  final limits = PlanLimits(maxPets: maxPets, maxChatsPerPet: 2, dailyQuestions: 9, maxDevices: 2);
  return SubscriptionStatus(
    trialEndsAt: DateTime.now().add(const Duration(days: 9)),
    plan: plan,
    isDeveloper: false,
    hasAccess: hasAccess,
    testPeriod: testPeriod,
    limits: limits,
    planLimits: {for (final tier in PlanTier.values) tier: limits},
  );
}

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

void main() {
  setUp(PetDemoStore.instance.reset);
  tearDown(() {
    PetDemoStore.instance.debugUpsertRow = null;
    BillingDemoStore.instance.reset();
  });

  group('the plan needs a free place to bring a pet back', () {
    test('with every place taken the return is refused before anything changes', () async {
      final store = PetDemoStore.instance;
      await store.upsert(_pet('a', name: 'Rex'));
      await store.upsert(_pet('b', name: 'Luna'));
      final memorial = await store.upsert(_pet('m', memorial: true));
      final restores = _Restores();

      await expectLater(
        restores.service((limit: 2, upgradePlan: 'Pro')).restore(memorial),
        throwsA(isA<PetLimitBlocksRestore>()
            .having((e) => e.limit, 'limit', 2)
            .having((e) => e.upgradePlan, 'upgradePlan', 'Pro')),
      );

      expect(store.list().map((p) => p.id), ['b', 'a']);
      expect(store.memorialPets().single.id, 'm', reason: 'it is still in Ricordi');
      expect(restores.count, 0, reason: 'nothing was refreshed or scheduled');
    });

    test('pets in Ricordi take no place: they never block a return', () async {
      final store = PetDemoStore.instance;
      await store.upsert(_pet('a'));
      await store.upsert(_pet('m1', memorial: true));
      await store.upsert(_pet('m2', memorial: true));
      final memorial = await store.upsert(_pet('m3', memorial: true));

      final back = await _Restores().service((limit: 2, upgradePlan: null)).restore(memorial);

      expect(back.isMemorial, isFalse);
      expect(store.list().length, 2);
      expect(store.memorialPets().length, 2);
    });

    test('one place left is enough, none left is not', () async {
      final store = PetDemoStore.instance;
      await store.upsert(_pet('a'));
      final first = await store.upsert(_pet('m1', memorial: true));
      final second = await store.upsert(_pet('m2', memorial: true));
      final service = _Restores().service((limit: 2, upgradePlan: null));

      await service.restore(first); // 1 of 2 places used -> fits
      await expectLater(service.restore(second), throwsA(isA<PetLimitBlocksRestore>()));
    });

    test('with no known limit (a developer account, or not loaded yet) the server decides',
        () async {
      final store = PetDemoStore.instance;
      for (var i = 0; i < 5; i++) {
        await store.upsert(_pet('a$i'));
      }
      final memorial = await store.upsert(_pet('m', memorial: true));

      final back = await _Restores().service((limit: null, upgradePlan: null)).restore(memorial);

      expect(back.isMemorial, isFalse);
    });
  });

  group('the plan to suggest', () {
    Future<PetLimitBlocksRestore> blockedWith(SubscriptionStatus status) async {
      await BillingDemoStore.instance.syncFromBackend(dataSource: _FakeSource(status));
      final store = PetDemoStore.instance;
      await store.upsert(_pet('a'));
      await store.upsert(_pet('b'));
      final memorial = await store.upsert(_pet('m', memorial: true));
      try {
        await MemorialService(
          store: store,
          stopWalkOf: (_) async {},
          revokeRecordsConsent: (_) async {},
          onMoved: (_) {},
          onRestored: () {},
        ).restore(memorial);
      } on PetLimitBlocksRestore catch (blocked) {
        return blocked;
      }
      fail('the return should have been refused');
    }

    test('Plus is pointed to Pro and Pro to Ultra', () async {
      expect((await blockedWith(_status(plan: PlanTier.plus))).upgradePlan, 'Pro');
      PetDemoStore.instance.reset();
      expect((await blockedWith(_status(plan: PlanTier.pro))).upgradePlan, 'Ultra');
    });

    test('Ultra, the free trial and the public test have none to suggest', () async {
      expect((await blockedWith(_status(plan: PlanTier.ultra))).upgradePlan, isNull);
      PetDemoStore.instance.reset();
      expect((await blockedWith(_status())).upgradePlan, isNull, reason: 'the free trial');
      PetDemoStore.instance.reset();
      final test = await blockedWith(_status(plan: PlanTier.pro, testPeriod: true));
      expect(test.upgradePlan, isNull, reason: 'plans are not offered during the public test');
      expect(test.limit, 2);
    });
  });

  group('the server refuses (the app count was out of date)', () {
    test('the pet goes back to Ricordi, nothing is left flagged, the owner is told', () async {
      final store = PetDemoStore.instance;
      final memorial = await store.upsert(_pet('m', memorial: true));
      final restores = _Restores();
      store.debugUpsertRow = (row) async {
        if (row['is_memorial'] == false) throw _planRefusal;
      };

      await expectLater(
        // The app thinks there is room (no limit known): the server says no.
        restores.service((limit: null, upgradePlan: 'Pro')).restore(memorial),
        throwsA(isA<PetLimitBlocksRestore>().having((e) => e.upgradePlan, 'upgradePlan', 'Pro')),
      );

      expect(store.memorialPets().single.id, 'm');
      expect(store.list(), isEmpty);
      expect(store.isUnsynced('m'), isFalse, reason: 'not "brought back but not synced"');
      expect(restores.count, 0);
    });

    test('any other failure is undone here and says so: the pet stays in Ricordi', () async {
      final store = PetDemoStore.instance;
      final memorial = await store.upsert(_pet('m', memorial: true));
      store.debugUpsertRow = (row) async {
        throw const PostgrestException(message: 'boom', code: '500');
      };

      await expectLater(
        _Restores().service((limit: null, upgradePlan: null)).restore(memorial),
        throwsA(isA<PetSyncException>()),
      );

      expect(store.memorialPets().single.id, 'm');
      expect(store.list(), isEmpty);
      expect(store.isUnsynced('m'), isFalse);
    });

    test('a refused new pet is still flagged, as before (no revert without a return)', () async {
      final store = PetDemoStore.instance;
      store.debugUpsertRow = (row) async => throw _planRefusal;

      await store.upsert(_pet('new'));

      expect(store.list().single.id, 'new');
      expect(store.isUnsynced('new'), isTrue);
    });

    test('the revert applies only when the caller asks for it (a return)', () async {
      final store = PetDemoStore.instance;
      final active = await store.upsert(_pet('a'));
      store.debugUpsertRow = (row) async => throw _planRefusal;

      final saved = await store.upsert(active, revertOnPlanLimit: _pet('a', memorial: true));

      expect(saved.isMemorial, isTrue, reason: 'the caller asked for this revert');
      expect(store.list(), isEmpty);
    });
  });

  group('what the owner reads', () {
    testWidgets('a full plan: a dialog says the pet stays, why, and the two ways out',
        (tester) async {
      _phone(tester);
      final store = PetDemoStore.instance;
      await store.upsert(_pet('a', name: 'Rex'));
      await store.upsert(_pet('b', name: 'Luna'));
      final memorial = await store.upsert(_pet('m', memorial: true));
      await tester.pumpWidget(_app(PetMemorialPage(
        pet: memorial,
        service: _Restores().service((limit: 2, upgradePlan: 'Pro')),
        loadMoments: (_) async => const MemorialMoments(),
        today: DateTime(2026, 11, 16),
      )));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const ValueKey('memorial-restore')));
      await tester.tap(find.byKey(const ValueKey('memorial-restore')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Riporta tra gli animali'));
      await tester.pumpAndSettle();

      final dialog = find.byKey(const ValueKey('memorial-restore-blocked'));
      expect(dialog, findsOneWidget, reason: 'a dialog, not a snackbar that vanishes');
      final text = tester.widget<Text>(find.descendant(of: dialog, matching: find.byType(Text)).first);
      expect(text.data, startsWith('Moka resta nei Ricordi: non si perde niente.'),
          reason: 'the reassurance comes first');
      expect(text.data, contains('il tuo piano ne consente 2 e sono tutti occupati'));
      expect(text.data, contains('Puoi liberare un posto oppure passare al piano Pro'));
      expect(text.data, contains('Impostazioni → Abbonamento e pagamenti'));
      expect(find.byType(PetMemorialPage), findsOneWidget, reason: 'it did not close');
      expect(find.textContaining('è di nuovo tra i tuoi animali'), findsNothing);
      expect(store.memorialPets().single.id, 'm');

      await tester.tap(find.descendant(of: dialog, matching: find.text('OK')));
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);
      expect(find.byType(PetMemorialPage), findsOneWidget);
    });

    testWidgets('without a plan above it says how to free a place, and offers no purchase',
        (tester) async {
      _phone(tester);
      final store = PetDemoStore.instance;
      await store.upsert(_pet('a', name: 'Rex'));
      final memorial = await store.upsert(_pet('m', memorial: true));
      await tester.pumpWidget(_app(PetMemorialPage(
        pet: memorial,
        service: _Restores().service((limit: 1, upgradePlan: null)),
        loadMoments: (_) async => const MemorialMoments(),
        today: DateTime(2026, 11, 16),
      )));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const ValueKey('memorial-restore')));
      await tester.tap(find.byKey(const ValueKey('memorial-restore')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Riporta tra gli animali'));
      await tester.pumpAndSettle();

      final dialog = find.byKey(const ValueKey('memorial-restore-blocked'));
      expect(find.textContaining('sposta nei Ricordi un animale che non c\'è più'), findsOneWidget);
      expect(find.textContaining('passare al piano'), findsNothing);
      expect(find.textContaining('credit'), findsNothing);
      expect(find.descendant(of: dialog, matching: find.byType(TextButton)), findsOneWidget,
          reason: 'one button, OK: nothing to buy');
      expect(find.descendant(of: dialog, matching: find.byType(FilledButton)), findsNothing);
    });

    testWidgets('the move window says only that a way back needs a free place', (tester) async {
      _phone(tester);
      final pet = await PetDemoStore.instance.upsert(_pet('a', name: 'Rex'));
      await tester.pumpWidget(_app(MemorialMovePage(
        pet: pet,
        service: _Restores().service((limit: null, upgradePlan: null)),
        loadMoments: (_) async => const MemorialMoments(),
      )));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('memorial-return-needs-place')), findsOneWidget);
      expect(
        find.text('Se un giorno vorrai riportare Rex tra gli animali, servirà un posto libero nel tuo piano.'),
        findsOneWidget,
      );
      // Nothing about what counts or does not count where the loss is being entered.
      expect(find.textContaining('contano'), findsNothing);
      expect(find.byKey(const ValueKey('memorial-not-counted')), findsNothing);
    });

    testWidgets('with no plan and no trial the way back is to choose a plan', (tester) async {
      _phone(tester);
      await BillingDemoStore.instance.syncFromBackend(
        dataSource: _FakeSource(_status(hasAccess: false)),
      );
      final pet = await PetDemoStore.instance.upsert(_pet('a', name: 'Rex'));
      await tester.pumpWidget(_app(MemorialMovePage(
        pet: pet,
        service: _Restores().service((limit: null, upgradePlan: null)),
        loadMoments: (_) async => const MemorialMoments(),
      )));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('memorial-return-needs-place')), findsOneWidget);
      expect(
        find.text(
            'Se un giorno vorrai riportare Rex tra gli animali, dovrai scegliere un piano con un posto libero.'),
        findsOneWidget,
      );
      // "a free place in your plan" would be wrong for someone who has no plan.
      expect(find.textContaining('nel tuo piano'), findsNothing);
    });

    testWidgets('with a plan, a trial or a public test the sentence is the usual one',
        (tester) async {
      _phone(tester);
      for (final status in [
        _status(plan: PlanTier.plus),
        _status(), // the free trial: access, no plan
        _status(plan: PlanTier.pro, testPeriod: true),
      ]) {
        await BillingDemoStore.instance.syncFromBackend(dataSource: _FakeSource(status));
        final pet = await PetDemoStore.instance.upsert(_pet('a', name: 'Rex'));
        await tester.pumpWidget(_app(MemorialMovePage(
          pet: pet,
          service: _Restores().service((limit: null, upgradePlan: null)),
          loadMoments: (_) async => const MemorialMoments(),
        )));
        await tester.pumpAndSettle();

        expect(
          find.text(
              'Se un giorno vorrai riportare Rex tra gli animali, servirà un posto libero nel tuo piano.'),
          findsOneWidget,
        );
        expect(find.textContaining('dovrai scegliere un piano'), findsNothing);
      }
    });

    testWidgets('a plan says it next to the number of pets, and only there', (tester) async {
      const limits = PlanLimits(maxPets: 8, maxChatsPerPet: 4, dailyQuestions: 16, maxDevices: 3);
      await tester.pumpWidget(_app(Scaffold(
        body: PlanFeatureList(features: PlanFeature.forLimits(limits)),
      )));

      expect(find.text('Fino a 8 animali'), findsOneWidget);
      expect(find.byKey(const ValueKey('pets-memorial-note')), findsOneWidget);
      expect(find.text('Gli animali nei Ricordi non contano.'), findsOneWidget);
      expect(find.text('Fino a 4 chat per animale'), findsOneWidget);
    });

    test('the pets limit message says that pets in Ricordi do not count; others do not', () {
      const pets = PlanAccessRefusal(PlanRefusalKind.planLimitReached, limitKind: 'pets');
      const chats =
          PlanAccessRefusal(PlanRefusalKind.planLimitReached, limitKind: 'chats_per_pet');
      const unknown = PlanAccessRefusal(PlanRefusalKind.planLimitReached);

      expect(pets.message, contains('Ricordi'));
      expect(pets.message, contains('non contano'));
      expect(pets.message, contains('Passa a un piano superiore'));
      expect(chats.message, isNot(contains('Ricordi')));
      expect(unknown.message, chats.message, reason: 'every other limit keeps its text');
    });

    for (final language in ['it', 'en', 'es', 'de', 'fr']) {
      test('the new texts exist and carry their values in $language', () {
        final l10n = lookupAppLocalizations(Locale(language));

        expect(l10n.billingPetsMemorialNote, isNotEmpty);
        expect(l10n.billingPlanLimitPets, isNotEmpty);
        expect(l10n.memorialMoveReturnNeedsPlace('Moka'), contains('Moka'));
        expect(l10n.memorialMoveReturnNeedsPlan('Moka'), allOf(contains('Moka'), isNot(contains('{'))));
        final upgrade = l10n.memorialRestoreBlockedUpgrade('Moka', 8, 'Ultra');
        expect(upgrade, allOf(contains('Moka'), contains('8'), contains('Ultra')));
        final full = l10n.memorialRestoreBlockedFull('Moka', 8);
        expect(full, allOf(contains('Moka'), contains('8')));
        expect(upgrade, isNot(contains('{')), reason: 'no placeholder left over');
        expect(full, isNot(contains('{')));
        expect(upgrade, startsWith('Moka'), reason: 'the pet stays: said first');
        expect(full, startsWith('Moka'));
      });
    }
  });
}
