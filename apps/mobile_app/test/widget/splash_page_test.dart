import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vet_app_mobile/app/router/app_router.dart';
import 'package:vet_app_mobile/app/splash/app_preloader.dart';
import 'package:vet_app_mobile/app/splash/splash_messages.dart';
import 'package:vet_app_mobile/app/splash/splash_page.dart';
import 'package:vet_app_mobile/design_system/tokens/app_colors.dart';
import 'package:vet_app_mobile/shared/widgets/pet_loader.dart';
import 'package:vet_app_mobile/shared/widgets/quokka_logo.dart';

Widget _harness(SplashPage splash) {
  return MaterialApp(
    home: splash,
    onGenerateRoute: (settings) => MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => Scaffold(body: Text('ROUTE:${settings.name}')),
    ),
  );
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('teaser texts rotate every 2.5 s', (tester) async {
    final gate = Completer<void>();
    await tester.pumpWidget(
      _harness(
        SplashPage(
          restoreSignedIn: () async => true,
          preload: () => gate.future,
          resolveDestination: () async => AppRouter.homeShell,
        ),
      ),
    );

    expect(find.text(splashMessages[0]), findsOneWidget);
    await tester.pump(splashMessageInterval);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(splashMessages[1]), findsOneWidget);
    expect(find.text(splashMessages[0]), findsNothing);
    await tester.pump(splashMessageInterval);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(splashMessages[2]), findsOneWidget);

    expect(splashMessages.length, inInclusiveRange(8, 12));

    gate.complete();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  });

  testWidgets('signed in: navigates only after the preload completes', (tester) async {
    final preload = Completer<void>();
    var preloadStarted = false;
    await tester.pumpWidget(
      _harness(
        SplashPage(
          restoreSignedIn: () async => true,
          preload: () {
            preloadStarted = true;
            return preload.future;
          },
          resolveDestination: () async => AppRouter.homeShell,
        ),
      ),
    );

    // Well past the minimum display time, but preload still pending.
    await tester.pump(splashMinDisplay + const Duration(seconds: 1));
    expect(preloadStarted, isTrue);
    expect(find.text('ROUTE:${AppRouter.homeShell}'), findsNothing);

    preload.complete();
    await tester.pump();
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('ROUTE:${AppRouter.homeShell}'), findsOneWidget);
  });

  testWidgets('signed in: subscription gate result (paywall) is honored', (tester) async {
    await tester.pumpWidget(
      _harness(
        SplashPage(
          restoreSignedIn: () async => true,
          preload: () async {},
          resolveDestination: () async => AppRouter.paywall,
        ),
      ),
    );

    await tester.pump(splashMinDisplay);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('ROUTE:${AppRouter.paywall}'), findsOneWidget);
  });

  testWidgets('warm start: opens the saved tab after the minimum time, once the preload is in',
      (tester) async {
    var preloadCalls = 0;
    var gateCalls = 0;
    final harness = MaterialApp(
      home: SplashPage(
        restoreSignedIn: () async => true,
        warmTab: () async => 2,
        preload: () async => preloadCalls++,
        resolveDestination: () async {
          gateCalls++;
          return AppRouter.homeShell;
        },
      ),
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => Scaffold(body: Text('ROUTE:${settings.name}:${settings.arguments}')),
      ),
    );
    await tester.pumpWidget(harness);

    // Never before the minimum time, whatever the preload does.
    await tester.pump(splashMinDisplay - const Duration(milliseconds: 500));
    expect(find.text('ROUTE:${AppRouter.homeShell}:2'), findsNothing);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.text('ROUTE:${AppRouter.homeShell}:2'), findsOneWidget);
    expect(preloadCalls, 1);
    expect(gateCalls, 1);
  });

  testWidgets('warm start: the opening screen waits for the calendar and the news', (tester) async {
    final preload = Completer<void>();
    await tester.pumpWidget(
      _harness(
        SplashPage(
          restoreSignedIn: () async => true,
          warmTab: () async => 0,
          preload: () => preload.future,
          resolveDestination: () async => AppRouter.homeShell,
        ),
      ),
    );

    await tester.pump(splashMinDisplay + const Duration(seconds: 2));
    expect(find.text('ROUTE:${AppRouter.homeShell}'), findsNothing);

    preload.complete();
    await tester.pump();
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('ROUTE:${AppRouter.homeShell}'), findsOneWidget);
  });

  testWidgets('no network: after the cap the Home opens anyway', (tester) async {
    final never = Completer<void>();
    await tester.pumpWidget(
      _harness(
        SplashPage(
          restoreSignedIn: () async => true,
          warmTab: () async => 0,
          preload: () => never.future,
          resolveDestination: () async => AppRouter.homeShell,
          maxWait: const Duration(seconds: 6),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 5));
    expect(find.text('ROUTE:${AppRouter.homeShell}'), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('ROUTE:${AppRouter.homeShell}'), findsOneWidget);
    never.complete();
  });

  testWidgets('the opening screen shows the logo, the animal token and the phrases', (tester) async {
    final gate = Completer<void>();
    await tester.pumpWidget(
      _harness(
        SplashPage(
          restoreSignedIn: () async => true,
          preload: () => gate.future,
          resolveDestination: () async => AppRouter.homeShell,
        ),
      ),
    );

    // The head sits where the native splash draws it: centred, 112 dp.
    expect(find.byType(QuokkaLogo), findsOneWidget);
    final head = tester.getRect(find.byType(QuokkaLogo));
    final screen = tester.getRect(find.byType(Scaffold).first);
    expect(head.size, const Size(splashHeadSize, splashHeadSize));
    expect(head.center.dx, closeTo(screen.center.dx, 0.5));
    expect(head.center.dy, closeTo(screen.center.dy, 0.5));
    // The name and the loader come under it.
    expect(find.byType(QuokkaWordmark), findsOneWidget);
    expect(tester.getRect(find.byType(QuokkaWordmark)).top, greaterThan(head.bottom));
    expect(tester.getRect(find.byType(PetLoader)).top,
        greaterThan(tester.getRect(find.byType(QuokkaWordmark)).bottom));
    expect(find.byType(PetLoader), findsOneWidget);
    expect(find.text(splashMessages[0]), findsOneWidget);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, AppColors.brandDeep);

    gate.complete();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  });

  testWidgets('warm start: a device revoked meanwhile lands on sign-in, not on the home',
      (tester) async {
    final gate = Completer<String>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: AppRouter.navigatorKey,
        home: SplashPage(
          restoreSignedIn: () async => true,
          warmTab: () async => 0,
          preload: () async {},
          resolveDestination: () => gate.future,
        ),
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Scaffold(body: Text('ROUTE:${settings.name}')),
        ),
      ),
    );
    await tester.pump(splashMinDisplay + const Duration(milliseconds: 100));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('ROUTE:${AppRouter.homeShell}'), findsOneWidget);

    // The gate signed the owner out (device revoked) and answers "sign in".
    gate.complete(AppRouter.auth);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.text('ROUTE:${AppRouter.auth}'), findsOneWidget);
    expect(find.text('ROUTE:${AppRouter.homeShell}'), findsNothing);
  });

  testWidgets('signed out: skips preload, goes to login after min display', (tester) async {
    var preloadCalls = 0;
    await tester.pumpWidget(
      _harness(
        SplashPage(
          restoreSignedIn: () async => false,
          preload: () async => preloadCalls++,
          resolveDestination: () async => AppRouter.homeShell,
        ),
      ),
    );

    await tester.pump(splashMinDisplay - const Duration(milliseconds: 500));
    expect(find.text('ROUTE:${AppRouter.auth}'), findsNothing);

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('ROUTE:${AppRouter.auth}'), findsOneWidget);
    expect(preloadCalls, 0);
  });

  test('AppPreloader runs tasks in parallel, tolerates failures and times out', () async {
    var started = 0;
    final slow = Completer<void>();
    final preloader = AppPreloader(
      timeout: const Duration(milliseconds: 100),
      tasks: [
        () async {
          started++;
          throw StateError('boom');
        },
        () {
          started++;
          return slow.future; // never completes within the timeout
        },
        () async => started++,
      ],
    );

    final stopwatch = Stopwatch()..start();
    await preloader.run();
    stopwatch.stop();

    expect(started, 3);
    expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    slow.complete();
  });
}
