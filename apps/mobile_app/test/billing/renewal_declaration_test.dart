import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vet_app_mobile/app/theme/app_theme.dart';
import 'package:vet_app_mobile/design_system/app_text_scaler.dart';
import 'package:vet_app_mobile/design_system/responsive.dart';
import 'package:vet_app_mobile/features/billing/domain/billing_models.dart';
import 'package:vet_app_mobile/features/billing/domain/renewal_terms.dart';
import 'package:vet_app_mobile/features/billing/domain/store_subscription.dart';
import 'package:vet_app_mobile/features/billing/presentation/widgets/store_plan_offers.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';

/// The automatic renewal declared where the owner pays, and the limits of the
/// plans (owner decisions of 25 November 2026). The reviewed texts are the copy
/// the backend tests use too.
final _reviewed = (jsonDecode(
  File('../../tests/fixtures/billing_texts_2026_11_25.json').readAsStringSync(),
) as Map<String, dynamic>)
    .map((key, value) => MapEntry(key, (value as Map<String, dynamic>).cast<String, String>()));

const _languages = ['it', 'en', 'es', 'de', 'fr'];

AppLocalizations _l10n(String language) => lookupAppLocalizations(Locale(language));

const _prices = {PlanTier.plus: '45,99 €', PlanTier.pro: '85,99 €', PlanTier.ultra: '155,99 €'};

const _limits = {
  PlanTier.plus: PlanLimits(maxPets: 4, maxChatsPerPet: 2, dailyQuestions: 9, maxDevices: 2),
  PlanTier.pro: PlanLimits(
      maxPets: 8, maxChatsPerPet: 4, dailyQuestions: 40, maxDevices: 3, dailyQuestionsPerChat: 15),
  PlanTier.ultra: PlanLimits(
      maxPets: 15, maxChatsPerPet: 6, dailyQuestions: 80, maxDevices: 5, dailyQuestionsPerChat: 20),
};

StoreSubscription _subscription({String store = 'google', bool grantsAccess = true}) =>
    StoreSubscription(
      store: store,
      productId: 'quokka_pro',
      plan: 'pro',
      period: 'yearly',
      state: 'active',
      expiresAt: DateTime.utc(2027, 3, 10),
      autoRenew: true,
      grantsAccess: grantsAccess,
    );

Widget _offers({
  BillingCycle cycle = BillingCycle.yearly,
  StoreSubscription? current,
  String storeName = 'Google',
  Map<PlanTier, String> prices = _prices,
  ValueChanged<PlanTier>? onBuy,
  ValueChanged<BillingCycle>? onCycleChanged,
  bool busy = false,
}) =>
    StorePlanOffers(
      cycle: cycle,
      onCycleChanged: onCycleChanged ?? (_) {},
      priceFor: (tier) => prices[tier],
      featuresFor: (tier) => PlanFeature.forLimits(_limits[tier]!, tier: tier),
      current: current,
      storeName: storeName,
      busy: busy,
      onBuy: onBuy ?? (_) {},
      today: DateTime(2026, 11, 25),
    );

/// The same text scaling the app applies in app.dart.
Widget _app(Widget child, {String language = 'it'}) {
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
    home: Scaffold(
      body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: child),
    ),
  );
}

void _screen(WidgetTester tester, Size size, [double scale = 1]) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  tearDown(() => AppLocaleHolder.current = const Locale('it'));

  group('the words are the reviewed ones', () {
    for (final language in _languages) {
      test(language, () {
        final l10n = _l10n(language);
        String text(String key) => _reviewed[key]![language]!;
        String filled(String key, String price, String date) =>
            text(key).replaceAll('{price}', price).replaceAll('{date}', date);

        expect(l10n.renewMonthly('8,59 €', 'X'), filled('renewMonthly', '8,59 €', 'X'));
        expect(l10n.renewYearly('85,99 €', 'X'), filled('renewYearly', '85,99 €', 'X'));
        expect(l10n.renewCancelLine('Apple'),
            text('renewCancelLine').replaceAll('{store}', 'Apple'));
        expect(l10n.subscribeButton, text('subscribeButton'));
        expect(l10n.cancelButton, text('cancelButton'));
        expect(l10n.cancelButtonNote, text('cancelButtonNote'));
        // The words are the reviewed ones; the numbers are the server's.
        expect(l10n.planLimitsPro(15, 40), text('planLimitsPro'));
        expect(l10n.planLimitsUltra(20, 80, 5), text('planLimitsUltra'));
      });
    }
  });

  group('the first renewal', () {
    test('is the same day a month or a year later', () {
      final day = DateTime(2026, 11, 25);
      expect(firstRenewalDate(day, BillingCycle.monthly), DateTime(2026, 12, 25));
      expect(firstRenewalDate(day, BillingCycle.yearly), DateTime(2027, 11, 25));
    });

    test('falls on the last day of a shorter month, and crosses the year', () {
      expect(firstRenewalDate(DateTime(2027, 1, 31), BillingCycle.monthly), DateTime(2027, 2, 28));
      expect(firstRenewalDate(DateTime(2028, 1, 31), BillingCycle.monthly), DateTime(2028, 2, 29));
      expect(firstRenewalDate(DateTime(2028, 2, 29), BillingCycle.yearly), DateTime(2029, 2, 28));
      expect(
          firstRenewalDate(DateTime(2026, 12, 15), BillingCycle.monthly), DateTime(2027, 1, 15));
    });
  });

  testWidgets('price, period and date stand right above a button that says you pay',
      (tester) async {
    _screen(tester, const Size(400, 3000));
    await tester.pumpWidget(_app(_offers()));

    expect(find.text('Abbonati e paga'), findsNWidgets(3));
    expect(find.widgetWithText(FilledButton, 'Pro'), findsNothing,
        reason: 'the plan name is the title of the card, never the button');
    expect(find.textContaining('Annuale ·'), findsNothing, reason: 'replaced, not added');
    for (final tier in PlanTier.values) {
      final card = find.byKey(ValueKey('store-plan-${tier.name}'));
      final sentence = find.descendant(
        of: card,
        matching: find.text(
          '${_prices[tier]} all\'anno (imposte secondo lo store del tuo paese). Il piano si '
          'rinnova da solo ogni anno, il 25/11/2027, finché non lo disdici.',
        ),
      );
      expect(sentence, findsOneWidget);
      final button = find.descendant(of: card, matching: find.byType(FilledButton));
      final gap = tester.getTopLeft(button).dy - tester.getBottomLeft(sentence).dy;
      expect(gap, inInclusiveRange(0, 16), reason: 'nothing between the sentence and the button');
    }
  });

  testWidgets('a monthly plan says the month and its date', (tester) async {
    _screen(tester, const Size(400, 3000));
    await tester.pumpWidget(_app(_offers(cycle: BillingCycle.monthly)));

    expect(find.textContaining('al mese'), findsNWidgets(3));
    expect(find.textContaining('ogni mese, il 25/12/2026'), findsNWidgets(3));
    expect(find.textContaining('all\'anno'), findsNothing);

    final chosen = <BillingCycle>[];
    await tester.pumpWidget(_app(_offers(onCycleChanged: chosen.add)));
    await tester.tap(find.text('Mensile'));
    expect(chosen, [BillingCycle.monthly]);
  });

  for (final store in ['Google', 'Apple']) {
    testWidgets('how to cancel and who handles the payment is said once: $store', (tester) async {
      _screen(tester, const Size(400, 3000));
      await tester.pumpWidget(_app(_offers(storeName: store)));

      expect(
        find.text(_reviewed['renewCancelLine']!['it']!.replaceAll('{store}', store)),
        findsOneWidget,
      );
      final lastButton = tester.getBottomLeft(find.byType(FilledButton).last).dy;
      final line = tester.getTopLeft(find.byKey(const ValueKey('renewal-cancel-line'))).dy;
      expect(line, greaterThan(lastButton), reason: 'one line under the plans');
    });
  }

  testWidgets('the button buys the plan of its card, and waits while a purchase runs',
      (tester) async {
    _screen(tester, const Size(400, 3000));
    final bought = <PlanTier>[];
    await tester.pumpWidget(_app(_offers(onBuy: bought.add)));
    await tester.tap(find.descendant(
      of: find.byKey(const ValueKey('store-plan-ultra')),
      matching: find.byType(FilledButton),
    ));
    expect(bought, [PlanTier.ultra]);

    await tester.pumpWidget(_app(_offers(onBuy: bought.add, busy: true)));
    await tester.tap(find.byType(FilledButton).first);
    expect(bought, [PlanTier.ultra]);
  });

  testWidgets('a plan the store does not sell here is not shown', (tester) async {
    _screen(tester, const Size(400, 3000));
    await tester.pumpWidget(_app(_offers(prices: {PlanTier.pro: '85,99 €'})));
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byKey(const ValueKey('store-plan-plus')), findsNothing);
  });

  testWidgets('moving from a paid plan to another writes no date: the store works it out',
      (tester) async {
    _screen(tester, const Size(400, 3000));
    await tester.pumpWidget(_app(_offers(current: _subscription())));

    // The plan in use has no button; the others do.
    final current = find.byKey(const ValueKey('store-plan-pro'));
    expect(find.descendant(of: current, matching: find.byType(FilledButton)), findsNothing);
    expect(find.text('Abbonati e paga'), findsNWidgets(2));
    expect(find.textContaining('25/11/2027'), findsNothing);
    expect(find.text('Annuale · 155,99 €'), findsOneWidget);
    // The renewal and how to cancel are still said.
    expect(find.textContaining('si rinnova automaticamente'), findsOneWidget);
    expect(find.byKey(const ValueKey('renewal-cancel-line')), findsOneWidget);
  });

  testWidgets('a plan given by the team, or one that has ended, is a new purchase', (tester) async {
    _screen(tester, const Size(400, 3000));
    await tester.pumpWidget(_app(_offers(current: _subscription(store: 'admin_test'))));
    expect(find.textContaining('25/11/2027'), findsNWidgets(2));

    await tester.pumpWidget(_app(_offers(current: _subscription(grantsAccess: false))));
    expect(find.textContaining('25/11/2027'), findsNWidgets(3));
  });

  group('no overflow at 320 px with large text', () {
    for (final language in _languages) {
      for (final cycle in BillingCycle.values) {
        testWidgets('$language ${cycle.name}', (tester) async {
          _screen(tester, const Size(320, 568), 1.3);
          await tester.pumpWidget(_app(_offers(cycle: cycle), language: language));
          expect(tester.takeException(), isNull);
          expect(find.text(_reviewed['subscribeButton']![language]!), findsNWidgets(3));
          expect(
            find.text(_reviewed['planLimitsUltra']![language]!),
            findsOneWidget,
          );
          // Whole width on a narrow phone: the button is never squeezed.
          expect(tester.getSize(find.byType(FilledButton).first).width, greaterThan(200));
        });
      }
    }
  });

  group('the limits of the plans', () {
    List<String> lines(PlanTier tier, PlanLimits limits) =>
        [for (final f in PlanFeature.forLimits(limits, tier: tier)) f.label];

    test('Pro says its questions per chat and per day', () {
      expect(lines(PlanTier.pro, _limits[PlanTier.pro]!), [
        'Fino a 8 animali',
        'Fino a 4 chat per animale',
        '15 domande per chat · 40 al giorno',
        'Fino a 3 dispositivi',
      ]);
    });

    test('Ultra says its devices in the same line, once', () {
      expect(lines(PlanTier.ultra, _limits[PlanTier.ultra]!), [
        'Fino a 15 animali',
        'Fino a 6 chat per animale',
        '20 domande per chat · 80 al giorno · 5 dispositivi',
      ]);
    });

    test('Plus is unchanged', () {
      expect(lines(PlanTier.plus, _limits[PlanTier.plus]!), [
        'Fino a 4 animali',
        'Fino a 2 chat per animale',
        'Fino a 9 domande al giorno',
        'Fino a 2 dispositivi',
      ]);
    });

    test('the numbers are the server\'s, whatever they are', () {
      const changed = PlanLimits(
          maxPets: 9, maxChatsPerPet: 5, dailyQuestions: 41, maxDevices: 4, dailyQuestionsPerChat: 17);
      expect(lines(PlanTier.pro, changed), contains('17 domande per chat · 41 al giorno'));
      expect(lines(PlanTier.ultra, changed),
          contains('17 domande per chat · 41 al giorno · 4 dispositivi'));
    });

    test('a server that does not know the limit per chat keeps the old lines', () {
      const old = PlanLimits(maxPets: 8, maxChatsPerPet: 4, dailyQuestions: 16, maxDevices: 3);
      expect(lines(PlanTier.pro, old),
          containsAll(['Fino a 16 domande al giorno', 'Fino a 3 dispositivi']));
      expect(lines(PlanTier.ultra, old),
          containsAll(['Fino a 16 domande al giorno', 'Fino a 3 dispositivi']));
    });

    test('the limit per chat is read from the server\'s answer', () {
      Map<String, dynamic> json(Object? perChat) => {
            'max_pets': 8,
            'max_chats_per_pet': 4,
            'daily_questions': 40,
            'max_devices': 3,
            'daily_questions_per_chat': perChat,
          };
      expect(PlanLimits.fromJson(json(15)).dailyQuestionsPerChat, 15);
      expect(PlanLimits.fromJson(json(null)).dailyQuestionsPerChat, isNull);
      expect(PlanLimits.fromJson(json(0)).dailyQuestionsPerChat, isNull);
      expect(PlanLimits.fromJson(json('x')).dailyQuestionsPerChat, isNull);
    });
  });
}
