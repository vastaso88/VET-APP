import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vet_app_mobile/app/router/app_router.dart';
import 'package:vet_app_mobile/app/splash/app_preloader.dart';
import 'package:vet_app_mobile/app/splash/splash_messages.dart';
import 'package:vet_app_mobile/app/splash/splash_page.dart';

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

    expect(splashMessages.length, inInclusiveRange(8, 10));

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
    await tester.pump(const Duration(seconds: 3));
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

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('ROUTE:${AppRouter.paywall}'), findsOneWidget);
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

    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('ROUTE:${AppRouter.auth}'), findsNothing);

    await tester.pump(const Duration(milliseconds: 700));
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
