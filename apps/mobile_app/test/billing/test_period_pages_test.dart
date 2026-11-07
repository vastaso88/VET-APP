import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vet_app_mobile/app/theme/app_theme.dart';
import 'package:vet_app_mobile/features/billing/data/billing_demo_store.dart';
import 'package:vet_app_mobile/features/billing/data/subscription_remote_data_source.dart';
import 'package:vet_app_mobile/features/billing/domain/billing_models.dart';
import 'package:vet_app_mobile/features/billing/domain/subscription_status.dart';
import 'package:vet_app_mobile/features/billing/presentation/pages/billing_page.dart';
import 'package:vet_app_mobile/features/first_run/presentation/pages/plan_intro_page.dart';
import 'package:vet_app_mobile/l10n/app_localizations.dart';
import 'package:vet_app_mobile/shared/errors/app_network_error.dart';
import 'package:vet_app_mobile/shared/types/result.dart';

class _FakeSource implements SubscriptionRemoteDataSource {
  _FakeSource(this.status);

  final SubscriptionStatus status;

  @override
  Future<Result<SubscriptionStatus>> fetchStatus() async => Result.success(status);

  @override
  Future<Result<SubscriptionStatus>> selectPlan(PlanTier plan) async =>
      Result.failure(const AppNetworkError(code: 'no', message: 'no'));
}

SubscriptionStatus _status({bool testPeriod = false, bool hasAccess = true, PlanTier? plan}) {
  return SubscriptionStatus(
    trialEndsAt: DateTime.now().add(const Duration(days: 9)),
    plan: plan,
    isDeveloper: false,
    hasAccess: hasAccess,
    testPeriod: testPeriod,
    planLimits: const {
      PlanTier.plus: PlanLimits(maxPets: 4, maxChatsPerPet: 2, dailyQuestions: 12, maxDevices: 2),
      PlanTier.pro: PlanLimits(maxPets: 8, maxChatsPerPet: 4, dailyQuestions: 25, maxDevices: 3),
      PlanTier.ultra:
          PlanLimits(maxPets: 15, maxChatsPerPet: 6, dailyQuestions: 50, maxDevices: 3),
    },
  );
}

Future<void> _seed(SubscriptionStatus status) =>
    BillingDemoStore.instance.syncFromBackend(dataSource: _FakeSource(status));

Widget _app(Widget page) => MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('it'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: page,
    );

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  tearDown(() => _seed(_status()));

  group('during the public test', () {
    setUp(() => _seed(_status(testPeriod: true, plan: PlanTier.pro)));

    testWidgets('the subscription page says it is a test and offers no plan or payment',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(const BillingPage()));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('billing-test-period-banner')), findsOneWidget);
      expect(find.text('Periodo di test'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing, reason: 'no "Passa a ..." buttons');
      expect(find.textContaining('METODI DI PAGAMENTO'), findsNothing);
      expect(find.textContaining('CONFRONTA I PIANI'), findsNothing);
      expect(find.text('Aggiungi metodo di pagamento'), findsNothing);
    });

    testWidgets('the page shown after sign-up does not offer a trial or a choice of plan',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(const PlanIntroPage()));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('first-run-test-period')), findsOneWidget);
      expect(find.text('Inizia la prova gratuita'), findsNothing);
      expect(find.text('Scegli'), findsNothing);
      expect(find.text('Continua'), findsOneWidget);
    });
  });

  group('without the public test nothing changes', () {
    testWidgets('the subscription page still compares the plans and lists the payment methods',
        (tester) async {
      await _seed(_status());
      await tester.binding.setSurfaceSize(const Size(420, 2600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(const BillingPage()));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('billing-test-period-banner')), findsNothing);
      expect(find.textContaining('CONFRONTA I PIANI'), findsOneWidget);
      expect(find.byType(FilledButton), findsWidgets);
    });

    testWidgets('the page shown after sign-up still offers the trial and the plans',
        (tester) async {
      await _seed(_status());
      await tester.binding.setSurfaceSize(const Size(420, 2600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(const PlanIntroPage()));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('first-run-test-period')), findsNothing);
      expect(find.text('Inizia la prova gratuita'), findsOneWidget);
    });
  });
}
