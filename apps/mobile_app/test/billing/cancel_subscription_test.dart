import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/app/theme/app_theme.dart';
import 'package:vet_app_mobile/design_system/app_text_scaler.dart';
import 'package:vet_app_mobile/design_system/responsive.dart';
import 'package:vet_app_mobile/features/billing/data/billing_demo_store.dart';
import 'package:vet_app_mobile/features/billing/domain/billing_models.dart';
import 'package:vet_app_mobile/features/billing/domain/store_subscription.dart';
import 'package:vet_app_mobile/features/billing/domain/subscription_status.dart';
import 'package:vet_app_mobile/features/billing/presentation/pages/billing_page.dart';
import 'package:vet_app_mobile/features/billing/presentation/pages/paywall_page.dart';
import 'package:vet_app_mobile/features/billing/presentation/widgets/cancel_subscription_section.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';

/// «Disdici l'abbonamento» (owner decision of 25 November 2026): at the top of
/// Abbonamento e pagamenti, in sight without scrolling, one tap to the store.
const _button = ValueKey('cancel-subscription');

StoreSubscription _subscription({
  String store = 'google',
  String state = 'active',
  bool autoRenew = true,
  bool grantsAccess = true,
}) =>
    StoreSubscription(
      store: store,
      productId: 'quokka_pro',
      plan: 'pro',
      period: 'yearly',
      state: state,
      expiresAt: DateTime.utc(2027, 11, 25),
      autoRenew: autoRenew,
      grantsAccess: grantsAccess,
    );

SubscriptionStatus _status(StoreSubscription? subscription, {bool testPeriod = false}) =>
    SubscriptionStatus(
      trialEndsAt: DateTime.utc(2026, 1, 1),
      plan: subscription == null ? null : PlanTier.pro,
      isDeveloper: false,
      hasAccess: true,
      testPeriod: testPeriod,
      storeSubscription: subscription,
    );

void _seed(StoreSubscription? subscription) =>
    BillingDemoStore.instance.applyStatus(_status(subscription));

/// The same text scaling the app applies in app.dart.
Widget _app(Widget page, {String language = 'it'}) {
  AppLocaleHolder.current = Locale(language);
  return MaterialApp(
    theme: AppTheme.light(),
    locale: Locale(language),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    builder: (context, child) {
      final mq = MediaQuery.of(context);
      final factor = (mq.size.width / referenceScreenWidth).clamp(0.85, 1.35);
      return MediaQuery(
        data: mq.copyWith(textScaler: AppTextScaler(system: mq.textScaler, appFactor: factor)),
        child: child!,
      );
    },
    home: page,
  );
}

void _screen(WidgetTester tester, Size size, double scale) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
}

String _l10nNotice() => lookupAppLocalizations(const Locale('it')).billingAccountStatusNotice;

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() {
    BillingDemoStore.instance.reset();
    AppLocaleHolder.current = const Locale('it');
  });

  group('on the subscription page, on the first screen of the smallest phone', () {
    for (final language in ['it', 'de', 'fr', 'en', 'es']) {
      testWidgets(language, (tester) async {
        _screen(tester, const Size(320, 568), 1.3);
        _seed(_subscription());
        await tester.pumpWidget(_app(const BillingPage(), language: language));
        await tester.pump(const Duration(milliseconds: 400));

        expect(tester.takeException(), isNull);
        final l10n = lookupAppLocalizations(Locale(language));
        final button = find.byKey(_button);
        expect(find.descendant(of: button, matching: find.text(l10n.cancelButton)), findsOneWidget);
        final rect = tester.getRect(button);
        expect(rect.bottom, lessThanOrEqualTo(568), reason: 'in sight without scrolling');
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320));
        expect(rect.height, greaterThanOrEqualTo(48), reason: 'a full-size target');
        final note = tester.getRect(find.text(l10n.cancelButtonNote));
        expect(note.top, greaterThanOrEqualTo(rect.bottom), reason: 'the note is under the button');
        expect(note.bottom, lessThanOrEqualTo(568));
      });
    }
  });

  testWidgets('it has the same weight as the button that buys a plan', (tester) async {
    _seed(_subscription());
    await tester.pumpWidget(_app(const BillingPage()));
    await tester.pump(const Duration(milliseconds: 400));
    final button = tester.widget(find.byKey(_button));
    expect(button, isA<FilledButton>());
    expect((button as FilledButton).style, isNull, reason: 'the theme\'s own, like the others');
  });

  testWidgets('the status that arrives after the page is open shows it, and a cancelled one hides it',
      (tester) async {
    await tester.pumpWidget(_app(const BillingPage()));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(_button), findsNothing);

    _seed(_subscription());
    await tester.pump();
    expect(find.byKey(_button), findsOneWidget);

    _seed(_subscription(state: 'canceled', autoRenew: false));
    await tester.pump();
    expect(find.byKey(_button), findsNothing);
    // What the app says then, without proposing the purchase of the same plan again.
    expect(find.text('Rinnovo disattivato: attivo fino al 25/11/2027'), findsOneWidget);
  });

  group('shown for every store subscription that will be charged again', () {
    for (final store in ['apple', 'google']) {
      for (final state in ['active', 'in_grace_period', 'billing_retry', 'on_hold', 'paused']) {
        test('$store $state', () {
          expect(_subscription(store: store, state: state).renews, isTrue);
        });
      }
    }
  });

  group('nothing to cancel', () {
    final cases = <String, StoreSubscription?>{
      'no subscription': null,
      'already cancelled': _subscription(state: 'canceled', autoRenew: false),
      'renewal off': _subscription(autoRenew: false),
      'expired': _subscription(state: 'expired', grantsAccess: false),
      'refunded': _subscription(state: 'refunded', grantsAccess: false),
      'revoked': _subscription(state: 'revoked', grantsAccess: false),
      'replaced': _subscription(state: 'replaced', grantsAccess: false),
      'payment not completed': _subscription(state: 'pending', grantsAccess: false),
      'given by the team': _subscription(store: 'admin_test'),
    };
    for (final entry in cases.entries) {
      testWidgets(entry.key, (tester) async {
        _seed(entry.value);
        await tester.pumpWidget(_app(const Scaffold(body: CancelSubscriptionSection())));
        expect(find.byKey(_button), findsNothing);
        expect(find.byType(Text), findsNothing);
      });
    }
  });

  testWidgets('one tap opens the store of that subscription, with no question in between',
      (tester) async {
    final opened = <StoreSubscription>[];
    _seed(_subscription(store: 'apple'));
    await tester.pumpWidget(_app(Scaffold(
      body: CancelSubscriptionSection(openStore: (subscription) async {
        opened.add(subscription);
        return true;
      }),
    )));
    await tester.tap(find.byKey(_button));
    await tester.pumpAndSettle();
    expect(opened.single.store, 'apple');
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });

  for (final broken in [false, true]) {
    testWidgets('a store page that does not open is said (${broken ? 'error' : 'refused'})',
        (tester) async {
      _seed(_subscription());
      await tester.pumpWidget(_app(Scaffold(
        body: CancelSubscriptionSection(openStore: (_) async {
          if (broken) throw StateError('no browser');
          return false;
        }),
      )));
      await tester.tap(find.byKey(_button));
      await tester.pump();
      expect(find.text('Non sono riuscito ad aprire la pagina. Riprova più tardi.'), findsOneWidget);
    });
  }

  testWidgets('who paid in a store is not sent to the site by the phone app', (tester) async {
    final notice = _l10nNotice();
    await tester.pumpWidget(_app(const BillingPage()));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.scrollUntilVisible(find.text(notice), 200);
    expect(find.text(notice), findsOneWidget);

    for (final subscription in [
      _subscription(),
      _subscription(state: 'canceled', autoRenew: false),
      _subscription(state: 'expired', grantsAccess: false),
    ]) {
      _seed(subscription);
      await tester.pump();
      expect(find.text(notice), findsNothing);
    }
    _seed(_subscription(store: 'admin_test'));
    await tester.pump();
    expect(find.text(notice), findsOneWidget);
  });

  testWidgets('who cannot use the app because a payment failed finds it on the plans page too',
      (tester) async {
    _screen(tester, const Size(400, 4000), 1);
    _seed(_subscription(state: 'on_hold', grantsAccess: false));
    await tester.pumpWidget(_app(const PaywallPage()));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(_button), findsOneWidget);
  });

  testWidgets('during the public test nobody pays and there is nothing to cancel', (tester) async {
    BillingDemoStore.instance.applyStatus(_status(null, testPeriod: true));
    await tester.pumpWidget(_app(const BillingPage()));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(_button), findsNothing);
  });
}
