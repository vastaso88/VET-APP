import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vet_app_mobile/app/router/app_router.dart';
import 'package:vet_app_mobile/features/billing/data/plan_access_refusal.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';

void main() {
  setUp(() => AppLocaleHolder.current = const Locale('it'));

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
