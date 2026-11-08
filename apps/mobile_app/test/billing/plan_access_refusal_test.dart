import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vet_app_mobile/app/router/app_router.dart';
import 'package:vet_app_mobile/features/billing/data/billing_demo_store.dart';
import 'package:vet_app_mobile/features/billing/data/plan_access_refusal.dart';
import 'package:vet_app_mobile/features/billing/data/subscription_remote_data_source.dart';
import 'package:vet_app_mobile/features/billing/domain/billing_models.dart';
import 'package:vet_app_mobile/features/billing/domain/subscription_status.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';
import 'package:vet_app_mobile/shared/errors/app_network_error.dart';
import 'package:vet_app_mobile/shared/types/result.dart';

class _FakeStatusSource implements SubscriptionRemoteDataSource {
  _FakeStatusSource({required this.hasAccess, this.fails = false});

  final bool hasAccess;
  final bool fails;
  int calls = 0;

  @override
  Future<Result<SubscriptionStatus>> fetchStatus() async {
    calls++;
    if (fails) {
      return Result.failure(const AppNetworkError(code: 'down', message: 'down'));
    }
    return Result.success(
      SubscriptionStatus(
        trialEndsAt: DateTime(2026, 1, 1),
        plan: null,
        isDeveloper: false,
        hasAccess: hasAccess,
      ),
    );
  }

  @override
  Future<Result<SubscriptionStatus>> selectPlan(PlanTier plan) => throw UnimplementedError();
}

void main() {
  setUp(() {
    AppLocaleHolder.current = const Locale('it');
    BillingDemoStore.instance.reset();
  });
  tearDown(() => BillingDemoStore.instance.reset());

  group('backend answers (HTTP)', () {
    test('402 subscription_required', () {
      final refusal = planRefusalFromHttp(402, '{"code":"subscription_required"}');
      expect(refusal?.kind, PlanRefusalKind.subscriptionRequired);
    });

    test('402 with only the old "detail" text still counts', () {
      final refusal = planRefusalFromHttp(
        402,
        '{"detail":"subscription_required: la prova gratuita è terminata."}',
      );
      expect(refusal?.kind, PlanRefusalKind.subscriptionRequired);
    });

    test('403 plan_limit_reached carries what ran out', () {
      final refusal = planRefusalFromHttp(
        403,
        '{"code":"plan_limit_reached","kind":"pets","detail":"plan_limit_reached: x"}',
      );
      expect(refusal?.kind, PlanRefusalKind.planLimitReached);
      expect(refusal?.limitKind, 'pets');
    });

    test('a 403 without the plan code, a 500 and a non-JSON body are not refusals', () {
      expect(planRefusalFromHttp(403, '{"code":"forbidden"}'), isNull);
      expect(planRefusalFromHttp(500, '{"code":"subscription_required"}'), isNull);
      expect(planRefusalFromHttp(402, '<html>502 Bad Gateway</html>'), isNull);
    });
  });

  group('direct Supabase writes (PostgREST)', () {
    test('PT402 subscription_required', () {
      const error = PostgrestException(
        message: 'subscription_required',
        code: 'PT402',
        details: 'trial ended',
      );
      expect(planRefusalFromError(error)?.kind, PlanRefusalKind.subscriptionRequired);
    });

    test('PT403 plan_limit_reached reads the kind and the limit', () {
      const error = PostgrestException(
        message: 'plan_limit_reached',
        code: 'PT403',
        details: 'pets',
        hint: '8',
      );
      final refusal = planRefusalFromError(error);
      expect(refusal?.kind, PlanRefusalKind.planLimitReached);
      expect(refusal?.limitKind, 'pets');
      expect(refusal?.limit, 8);
    });

    test('a row-level-security refusal (42501) is not a plan refusal', () {
      const error = PostgrestException(
        message: 'new row violates row-level security policy',
        code: '42501',
      );
      expect(planRefusalFromError(error), isNull);
    });

    test('other errors are not refusals', () {
      expect(planRefusalFromError(StateError('offline')), isNull);
      expect(planRefusalFromError(const PostgrestException(message: 'x', code: '23505')), isNull);
    });
  });

  group('Storage pet-photos', () {
    const forbidden = StorageException('new row violates row-level security', statusCode: '403');

    test('403 with a lapsed account is subscription_required', () {
      final refusal = planRefusalFromError(forbidden, storagePetPhotos: true, hasAccess: false);
      expect(refusal?.kind, PlanRefusalKind.subscriptionRequired);
    });

    test('403 while the account has access stays an ordinary failure', () {
      expect(planRefusalFromError(forbidden, storagePetPhotos: true, hasAccess: true), isNull);
    });

    test('other buckets and other statuses are never a plan refusal', () {
      expect(planRefusalFromError(forbidden, hasAccess: false), isNull);
      expect(
        planRefusalFromError(
          const StorageException('gone', statusCode: '404'),
          storagePetPhotos: true,
          hasAccess: false,
        ),
        isNull,
      );
    });
  });

  group('Storage 403 refreshes the account state once before deciding', () {
    const forbidden = StorageException('new row violates row-level security', statusCode: '403');

    Future<PlanAccessRefusal?> resolveWith(_FakeStatusSource source) => resolvePlanRefusal(
          forbidden,
          storagePetPhotos: true,
          refreshStatus: () => BillingDemoStore.instance.syncFromBackend(dataSource: source),
        );

    test('an expired trial the app did not know about reaches the paywall', () async {
      final source = _FakeStatusSource(hasAccess: false);
      // Nothing loaded yet: the app still believes the account has access.
      expect(BillingDemoStore.instance.hasAccess, isTrue);

      final refusal = await resolveWith(source);

      expect(refusal?.kind, PlanRefusalKind.subscriptionRequired);
      expect(source.calls, 1);
    });

    test('an account that really has access stays an ordinary failure', () async {
      final source = _FakeStatusSource(hasAccess: true);

      expect(await resolveWith(source), isNull);
      expect(source.calls, 1);
    });

    test('an unreachable backend stays an ordinary failure', () async {
      expect(await resolveWith(_FakeStatusSource(hasAccess: false, fails: true)), isNull);
    });

    test('a failing refresh never throws', () async {
      final refusal = await resolvePlanRefusal(
        forbidden,
        storagePetPhotos: true,
        refreshStatus: () async => throw StateError('boom'),
      );
      expect(refusal, isNull);
    });

    test('only a 403 on pet-photos triggers the refresh', () async {
      var refreshed = 0;
      Future<void> refresh() async => refreshed++;
      await resolvePlanRefusal(forbidden, refreshStatus: refresh);
      await resolvePlanRefusal(
        const StorageException('gone', statusCode: '404'),
        storagePetPhotos: true,
        refreshStatus: refresh,
      );
      await resolvePlanRefusal(StateError('offline'), storagePetPhotos: true, refreshStatus: refresh);
      expect(refreshed, 0);
    });

    test('a PostgREST refusal needs no refresh', () async {
      var refreshed = 0;
      final refusal = await resolvePlanRefusal(
        const PostgrestException(message: 'subscription_required', code: 'PT402'),
        refreshStatus: () async => refreshed++,
      );
      expect(refusal?.kind, PlanRefusalKind.subscriptionRequired);
      expect(refreshed, 0);
    });
  });

  group('shared texts', () {
    test('the messages are the ones the chat already used', () {
      const sub = PlanAccessRefusal(PlanRefusalKind.subscriptionRequired);
      const limit = PlanAccessRefusal(PlanRefusalKind.planLimitReached, limitKind: 'pets');
      expect(sub.message, appL10n.billingPaywallTitle);
      expect(limit.message, appL10n.billingPlanLimitReached);
    });
  });

  group('acting on a refusal', () {
    Future<void> pumpApp(WidgetTester tester) => tester.pumpWidget(
          MaterialApp(
            navigatorKey: AppRouter.navigatorKey,
            scaffoldMessengerKey: AppRouter.scaffoldMessengerKey,
            onGenerateRoute: (settings) => MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => Scaffold(body: Text('page ${settings.name}')),
            ),
          ),
        );

    testWidgets('subscription_required replaces the stack with the paywall', (tester) async {
      await pumpApp(tester);
      handlePlanRefusal(const PostgrestException(message: 'subscription_required', code: 'PT402'));
      await tester.pumpAndSettle();
      expect(find.text('page ${AppRouter.paywall}'), findsOneWidget);
    });

    testWidgets('plan_limit_reached shows the limit message and stays put', (tester) async {
      await pumpApp(tester);
      handlePlanRefusal(
        const PostgrestException(
          message: 'plan_limit_reached',
          code: 'PT403',
          details: 'pets',
          hint: '1',
        ),
        showMessage: true,
      );
      await tester.pumpAndSettle();
      expect(find.text(appL10n.billingPlanLimitReached), findsOneWidget);
      expect(find.text('page ${AppRouter.paywall}'), findsNothing);
    });

    testWidgets('an unrelated error does nothing and returns null', (tester) async {
      await pumpApp(tester);
      expect(handlePlanRefusal(StateError('offline'), showMessage: true), isNull);
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    });
  });
}
