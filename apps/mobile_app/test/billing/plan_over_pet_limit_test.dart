import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/app/theme/app_theme.dart';
import 'package:vet_app_mobile/features/billing/data/billing_demo_store.dart';
import 'package:vet_app_mobile/features/billing/data/subscription_remote_data_source.dart';
import 'package:vet_app_mobile/features/billing/domain/billing_models.dart';
import 'package:vet_app_mobile/features/billing/domain/subscription_status.dart';
import 'package:vet_app_mobile/features/billing/presentation/plan_over_pet_limit.dart';
import 'package:vet_app_mobile/features/pets/data/pet_demo_store.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_models.dart';
import 'package:vet_app_mobile/l10n/app_localizations.dart';
import 'package:vet_app_mobile/shared/errors/app_network_error.dart';
import 'package:vet_app_mobile/shared/types/result.dart';

/// Choosing a plan with fewer places than the owner has pets says so first (synthetic
/// users, round 2, 2026-11-16). Nothing is deleted or moved. Synthetic data only.
class _FakeSource implements SubscriptionRemoteDataSource {
  _FakeSource(this.status);

  final SubscriptionStatus status;

  @override
  Future<Result<SubscriptionStatus>> fetchStatus() async => Result.success(status);

  @override
  Future<Result<SubscriptionStatus>> selectPlan(PlanTier plan) async =>
      Result.failure(const AppNetworkError(code: 'no', message: 'no'));
}

SubscriptionStatus _status({bool testPeriod = false}) {
  PlanLimits limits(int pets) =>
      PlanLimits(maxPets: pets, maxChatsPerPet: 2, dailyQuestions: 9, maxDevices: 2);
  return SubscriptionStatus(
    trialEndsAt: DateTime.now().add(const Duration(days: 9)),
    plan: null,
    isDeveloper: false,
    hasAccess: true,
    testPeriod: testPeriod,
    limits: limits(8),
    planLimits: {
      PlanTier.plus: limits(4),
      PlanTier.pro: limits(8),
      PlanTier.ultra: limits(15),
    },
  );
}

PetProfile _pet(String id) => PetProfile(
      id: id,
      name: 'Pet $id',
      species: 'Cane',
      breed: '',
      birthDateLabel: '',
      sex: 'Femmina',
      weightLabel: '',
      medicalNote: '',
      healthBadge: '',
      nextVisitLabel: '',
      avatarEmoji: 'P',
      accentColor: Colors.white,
      identityColor: Colors.green,
    );

Widget _app(Future<void> Function(BuildContext) onTap, {Locale locale = const Locale('it')}) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(onPressed: () => onTap(context), child: const Text('go')),
        ),
      ),
    ),
  );
}

Future<bool?> _ask(
  WidgetTester tester,
  PlanTier tier, {
  required int pets,
  Future<void> Function()? whileOpen,
}) async {
  bool? answer;
  await tester.pumpWidget(_app((context) async {
    answer = await confirmPlanFitsPets(context, tier, petCount: pets);
  }));
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
  if (whileOpen != null) await whileOpen();
  return answer;
}

void main() {
  setUp(() async {
    PetDemoStore.instance.reset();
    await BillingDemoStore.instance.syncFromBackend(dataSource: _FakeSource(_status()));
  });
  tearDown(BillingDemoStore.instance.reset);

  testWidgets('with room for the pets it says nothing and the change goes on', (tester) async {
    final answer = await _ask(tester, PlanTier.plus, pets: 4); // exactly the places

    expect(find.byKey(const ValueKey('plan-over-pets')), findsNothing);
    expect(answer, isTrue);
  });

  testWidgets('more pets than places: calm text with the numbers, nothing is deleted',
      (tester) async {
    await _ask(tester, PlanTier.plus, pets: 7, whileOpen: () async {
      final dialog = find.byKey(const ValueKey('plan-over-pets'));
      expect(dialog, findsOneWidget);
      final text =
          tester.widget<Text>(find.descendant(of: dialog, matching: find.byType(Text)).first);
      expect(text.data, startsWith('Hai 7 animali e il piano Plus ne consente 4.'));
      expect(text.data, contains('Non cancelliamo e non spostiamo niente'));
      expect(text.data, contains('finché non ne avrai meno di 4'));
      expect(text.data, isNot(contains('€')));
      expect(find.text('Cambia piano'), findsOneWidget);
    });
  });

  testWidgets('"Cambia piano" goes on, "Annulla" does not choose anything', (tester) async {
    final goOn = await _ask(tester, PlanTier.plus, pets: 7, whileOpen: () async {
      await tester.tap(find.text('Cambia piano'));
      await tester.pumpAndSettle();
    });
    expect(goOn, isTrue);

    final stop = await _ask(tester, PlanTier.plus, pets: 7, whileOpen: () async {
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();
    });
    expect(stop, isFalse);
  });

  testWidgets('the plan above has room: no warning for Ultra', (tester) async {
    final answer = await _ask(tester, PlanTier.ultra, pets: 7);

    expect(find.byKey(const ValueKey('plan-over-pets')), findsNothing);
    expect(answer, isTrue);
  });

  testWidgets('during a public test nothing changes, so nothing is said', (tester) async {
    await BillingDemoStore.instance
        .syncFromBackend(dataSource: _FakeSource(_status(testPeriod: true)));

    final answer = await _ask(tester, PlanTier.plus, pets: 7);

    expect(find.byKey(const ValueKey('plan-over-pets')), findsNothing);
    expect(answer, isTrue);
  });

  testWidgets('limits not known yet: the server decides, no guess here', (tester) async {
    BillingDemoStore.instance.reset();

    final answer = await _ask(tester, PlanTier.plus, pets: 7);

    expect(find.byKey(const ValueKey('plan-over-pets')), findsNothing);
    expect(answer, isTrue);
  });

  testWidgets('user B starts from his own pets, whatever user A had', (tester) async {
    for (var i = 0; i < 7; i++) {
      await PetDemoStore.instance.upsert(_pet('a$i'));
    }
    PetDemoStore.instance.reset(); // signing out clears the account's pets

    bool? answer;
    await tester.pumpWidget(_app((context) async {
      answer = await confirmPlanFitsPets(context, PlanTier.plus); // the store's own count
    }));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('plan-over-pets')), findsNothing);
    expect(answer, isTrue);
  });

  testWidgets('by default it counts the active pets on this phone', (tester) async {
    for (var i = 0; i < 5; i++) {
      await PetDemoStore.instance.upsert(_pet('p$i'));
    }
    await tester.pumpWidget(_app((context) async {
      await confirmPlanFitsPets(context, PlanTier.plus);
    }));

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('plan-over-pets')), findsOneWidget);
    expect(find.textContaining('Hai 5 animali'), findsOneWidget);
  });

  for (final language in ['it', 'en', 'es', 'de', 'fr']) {
    test('the new texts exist and carry their values in $language', () {
      final l10n = lookupAppLocalizations(Locale(language));

      final warning = l10n.billingPlanOverPetsWarning(7, 4, 'Plus');
      expect(warning, allOf(contains('7'), contains('4'), contains('Plus')));
      expect(warning, isNot(contains('{')));
      expect(l10n.billingPlanOverPetsConfirm, isNotEmpty);
    });
  }
}
