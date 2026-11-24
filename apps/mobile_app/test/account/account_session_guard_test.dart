import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/app/router/app_router.dart';
import 'package:vet_app_mobile/features/account/application/account_session_guard.dart';
import 'package:vet_app_mobile/features/account/data/account_pause_remote_data_source.dart';
import 'package:vet_app_mobile/features/account/data/device_registry.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';
import 'package:vet_app_mobile/shared/errors/app_network_error.dart';
import 'package:vet_app_mobile/shared/types/result.dart';

int cleared = 0;

Future<void> _clear() async => cleared++;

int signedOut = 0;

Future<void> _signOut() async => signedOut++;

class _Backend implements AccountPauseRemoteDataSource {
  _Backend({this.sessionCode, this.notice});

  /// The code the session check fails with; null = the account is fine.
  final String? sessionCode;
  final PauseNotice? notice;
  int acknowledged = 0;
  int sessionChecks = 0;

  @override
  Future<Result<void>> checkSession() async {
    sessionChecks++;
    if (sessionCode == null) return Result.success(null);
    return Result.failure(AppNetworkError(code: sessionCode!));
  }

  @override
  Future<Result<PauseNotice?>> fetchNotice() async => Result.success(notice);

  @override
  Future<Result<void>> acknowledgeNotice() async {
    acknowledged++;
    return Result.success(null);
  }
}

Widget _app(Future<void> Function(BuildContext context) onStart, {List<String>? visited}) {
  AppLocaleHolder.current = const Locale('it');
  return MaterialApp(
    locale: const Locale('it'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    onGenerateRoute: (settings) {
      visited?.add(settings.name ?? '');
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => Scaffold(body: Text('route ${settings.name}')),
      );
    },
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(onPressed: () => onStart(context), child: const Text('go')),
      ),
    ),
  );
}

class _Registry implements DeviceRegistryClient {
  _Registry(this.active);
  final bool active;
  bool? claimed;

  @override
  Future<bool> register({required bool claim}) async {
    claimed = claim;
    return active;
  }
}

void main() {
  setUp(() {
    DeviceRegistry.pendingNotice = false;
    cleared = 0;
    signedOut = 0;
  });

  group('an account refused by the backend from another device', () {
    testWidgets('paused: signed out, told why, sent to the sign-in page', (tester) async {
      final visited = <String>[];
      SessionOutcome? outcome;
      await tester.pumpWidget(
        _app((context) async {
          outcome = await checkAccountSession(
            context,
            dataSource: _Backend(sessionCode: kAccountPausedCode),
            clearLocalTraces: _clear,
            signOut: _signOut,
          );
        }, visited: visited),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(outcome, SessionOutcome.paused);
      expect(cleared, 1); // the notices and caches of this phone went
      expect(signedOut, 1);
      expect(visited, contains(AppRouter.auth));
      expect(find.textContaining('messo in pausa da un altro dispositivo'), findsOneWidget);
    });

    testWidgets('waiting to be erased: stays put and lets the restore page take over', (
      tester,
    ) async {
      final visited = <String>[];
      SessionOutcome? outcome;
      await tester.pumpWidget(
        _app((context) async {
          outcome = await checkAccountSession(
            context,
            dataSource: _Backend(sessionCode: kAccountDeactivatedCode),
            clearLocalTraces: _clear,
          );
        }, visited: visited),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(outcome, SessionOutcome.deactivated);
      expect(cleared, 1);
      expect(signedOut, 0); // still signed in: the restore page is the way back
      expect(visited, isNot(contains(AppRouter.auth)));
    });

    testWidgets('a fine account, or any other failure, changes nothing', (tester) async {
      final visited = <String>[];
      final outcomes = <SessionOutcome>[];
      await tester.pumpWidget(
        _app((context) async {
          outcomes.add(
            await checkAccountSession(context, dataSource: _Backend(), clearLocalTraces: _clear),
          );
          if (!context.mounted) return;
          outcomes.add(
            await checkAccountSession(
              context,
              dataSource: _Backend(sessionCode: 'account_pause_timeout'),
              clearLocalTraces: _clear,
            ),
          );
        }, visited: visited),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(outcomes, [SessionOutcome.ok, SessionOutcome.ok]);
      expect(cleared, 0);
      expect(visited, isNot(contains(AppRouter.auth)));
    });
  });

  group('"the pause is over"', () {
    testWidgets('with a plan: says so once and tells the backend', (tester) async {
      final backend = _Backend(notice: const PauseNotice(hasAccess: true));
      await tester.pumpWidget(_app((context) => showPauseEndedIfAny(context, dataSource: backend)));

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.text('La pausa è finita'), findsOneWidget);
      expect(find.textContaining('di nuovo attivo'), findsOneWidget);
      expect(find.textContaining('Non hai un piano'), findsNothing);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(backend.acknowledged, 1);
    });

    testWidgets('without a plan: also gives the new day the data would be erased', (
      tester,
    ) async {
      final backend = _Backend(
        notice: PauseNotice(hasAccess: false, dataKeptUntil: DateTime(2027, 3, 14)),
      );
      await tester.pumpWidget(_app((context) => showPauseEndedIfAny(context, dataSource: backend)));

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Non hai un piano'), findsOneWidget);
      expect(find.textContaining('14'), findsWidgets);
    });

    testWidgets('nothing to say: no dialog, nothing acknowledged', (tester) async {
      final backend = _Backend();
      await tester.pumpWidget(_app((context) => showPauseEndedIfAny(context, dataSource: backend)));

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(backend.acknowledged, 0);
    });
  });

  group('a phone whose place was taken while the app stayed open', () {
    testWidgets('is signed out at once, told why and sent to the sign-in page', (tester) async {
      final visited = <String>[];
      final registry = _Registry(false);
      bool? out;
      await tester.pumpWidget(
        _app((context) async {
          out = await checkDeviceStillActive(
            context,
            registry: registry,
            clearLocalTraces: _clear,
            signOut: _signOut,
          );
        }, visited: visited),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(out, isTrue);
      expect(registry.claimed, isFalse); // it asks, it does not take a place
      expect(cleared, 1);
      expect(signedOut, 1);
      expect(DeviceRegistry.pendingNotice, isTrue); // the sign-in page shows the notice
      expect(visited, contains(AppRouter.auth));
    });

    testWidgets('a phone that still has its place is left alone', (tester) async {
      final visited = <String>[];
      bool? out;
      await tester.pumpWidget(
        _app((context) async {
          out = await checkDeviceStillActive(
            context,
            registry: _Registry(true),
            clearLocalTraces: _clear,
            signOut: _signOut,
          );
        }, visited: visited),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(out, isFalse);
      expect(cleared + signedOut, 0);
      expect(DeviceRegistry.pendingNotice, isFalse);
      expect(visited, isNot(contains(AppRouter.auth)));
    });
  });
}
