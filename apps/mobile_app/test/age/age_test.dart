import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/features/age/data/account_age_remote_data_source.dart';
import 'package:vet_app_mobile/features/age/data/age_store.dart';
import 'package:vet_app_mobile/features/age/domain/age_status.dart';
import 'package:vet_app_mobile/features/account/presentation/pages/delete_account_page.dart';
import 'package:vet_app_mobile/features/age/presentation/pages/closed_account_page.dart';
import 'package:vet_app_mobile/features/age/presentation/pages/underage_notice_page.dart';
import 'package:vet_app_mobile/features/age/presentation/widgets/birth_date_form.dart';
import 'package:vet_app_mobile/features/age/presentation/widgets/marketplace_age_gate.dart';
import 'package:vet_app_mobile/features/auth/presentation/pages/register_page.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';
import 'package:vet_app_mobile/shared/errors/app_network_error.dart';
import 'package:vet_app_mobile/shared/types/result.dart';

AgeStatus _status(AgeBand band, {bool confirmed = false}) => AgeStatus(
      band: band,
      marketplaceAllowed: band == AgeBand.adult,
      guardianRequired: band == AgeBand.minor,
      guardianConfirmed: confirmed,
      paidPlanAllowed: band == AgeBand.adult || (band == AgeBand.minor && confirmed),
    );

/// A backend that remembers one declaration, like the real one.
class _FakeBackend implements AccountAgeRemoteDataSource {
  _FakeBackend({this.declared});

  AgeStatus? declared;
  int declareCalls = 0;
  bool offline = false;
  DateTime? lastDate;

  @override
  Future<Result<AgeStatus>> fetch() async => Result.success(declared ?? const AgeStatus.unknown());

  @override
  Future<Result<AgeStatus>> declare(DateTime birthDate) async {
    declareCalls++;
    if (offline) {
      return Result.failure(const AppNetworkError(code: 'account_age_timeout'));
    }
    if (declared != null) {
      return Result.failure(const AppNetworkError(code: 'age_already_declared'));
    }
    lastDate = birthDate;
    final years = ageOn(birthDate, DateTime.now());
    declared = _status(
      years < 14 ? AgeBand.underMinimum : (years < 18 ? AgeBand.minor : AgeBand.adult),
    );
    return Result.success(declared!);
  }

  @override
  Future<Result<AgeStatus>> confirmGuardian() async {
    declared = _status(AgeBand.minor, confirmed: true);
    return Result.success(declared!);
  }
}

class _ClosedBackend implements AccountAgeRemoteDataSource {
  @override
  Future<Result<AgeStatus>> fetch() async => Result.success(const AgeStatus.unknown());

  @override
  Future<Result<AgeStatus>> declare(DateTime birthDate) async =>
      Result.failure(const AppNetworkError(code: kUnderMinimumAgeCode));

  @override
  Future<Result<AgeStatus>> confirmGuardian() async =>
      Result.failure(const AppNetworkError(code: kUnderMinimumAgeCode));
}

Widget _app(Widget home) {
  AppLocaleHolder.current = const Locale('it');
  return MaterialApp(
    locale: const Locale('it'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: home,
  );
}

String _typed(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(AgeStore.restoreDefault);

  test('ageOn counts full years and changes exactly on the birthday', () {
    final today = DateTime(2026, 11, 8);
    expect(ageOn(DateTime(2012, 11, 9), today), 13);
    expect(ageOn(DateTime(2012, 11, 8), today), 14);
    expect(ageOn(DateTime(2008, 11, 8), today), 18);
  });

  group('AgeStore', () {
    test('declaring keeps the new status; a second time keeps what the backend holds', () async {
      AgeStore.useForTest(_FakeBackend());

      final first = await AgeStore.instance.declare(DateTime(1990, 5, 1));
      expect(first.isSuccess, isTrue);
      expect(AgeStore.instance.status.band, AgeBand.adult);

      final second = await AgeStore.instance.declare(DateTime(2015, 5, 1));
      expect(
        second.fold(onSuccess: (_) => null, onFailure: (e) => e.code),
        'age_already_declared',
      );
      expect(AgeStore.instance.status.band, AgeBand.adult);
    });

    test('a date that could not be sent is kept once and sent at the next start', () async {
      final backend = _FakeBackend()..offline = true;
      AgeStore.useForTest(backend);
      await AgeStore.instance.rememberPending(DateTime(1990, 5, 1));

      await AgeStore.instance.submitPending();
      expect(AgeStore.instance.status.band, AgeBand.unknown);

      backend.offline = false;
      await AgeStore.instance.refresh();
      expect(AgeStore.instance.status.band, AgeBand.adult);
      expect(backend.lastDate, DateTime(1990, 5, 1));

      final callsBefore = backend.declareCalls;
      await AgeStore.instance.refresh();
      expect(backend.declareCalls, callsBefore, reason: 'the pending date is sent only once');
    });

    test('sign-out wipes the status and any pending date', () async {
      AgeStore.useForTest(_FakeBackend());
      await AgeStore.instance.rememberPending(DateTime(1990, 5, 1));
      await AgeStore.instance.declare(DateTime(2000, 1, 1));

      await AgeStore.instance.reset();

      expect(AgeStore.instance.status.band, AgeBand.unknown);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getKeys(), isEmpty);
    });

    test('a 403 under_minimum_age from any route closes the account', () async {
      AgeStore.useForTest(_ClosedBackend());
      expect(AgeStore.instance.status.band, AgeBand.unknown);

      final result = await AgeStore.instance.confirmGuardian();

      expect(result.isFailure, isTrue);
      expect(AgeStore.instance.status.band, AgeBand.underMinimum);
    });
  });

  group('BirthDateForm', () {
    testWidgets('only a real, past date is accepted', (tester) async {
      DateTime? sent;
      await tester.pumpWidget(_app(Scaffold(body: BirthDateForm(onSubmit: (d) => sent = d))));

      await tester.tap(find.text('Continua'));
      await tester.pump();
      expect(find.text('Seleziona la data di nascita.'), findsOneWidget);
      expect(sent, isNull);

      await tester.enterText(
        find.byType(TextFormField),
        _typed(DateTime.now().add(const Duration(days: 40))),
      );
      await tester.tap(find.text('Continua'));
      await tester.pump();
      expect(sent, isNull);

      await tester.enterText(find.byType(TextFormField), '01/05/1990');
      await tester.tap(find.text('Continua'));
      await tester.pump();
      expect(sent, DateTime(1990, 5, 1));
    });
  });

  group('registration, first step', () {
    testWidgets('under 14: only the message, nothing is sent or saved', (tester) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final backend = _FakeBackend();
      AgeStore.useForTest(backend);
      await tester.pumpWidget(_app(const RegisterPage()));

      final child = DateTime.now().subtract(const Duration(days: 365 * 10));
      await tester.enterText(find.byType(TextFormField), _typed(child));
      await tester.tap(find.text('Continua'));
      await tester.pumpAndSettle();

      expect(find.byType(UnderageNoticePage), findsOneWidget);
      expect(find.text('Quokka è per chi ha almeno 14 anni'), findsOneWidget);
      expect(find.textContaining('nessun dato'), findsOneWidget);
      expect(backend.declareCalls, 0);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getKeys(), isEmpty);
    });

    testWidgets('14 or over: the registration form follows the date', (tester) async {
      tester.view.physicalSize = const Size(600, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_app(const RegisterPage()));

      await tester.enterText(find.byType(TextFormField), '01/05/1990');
      await tester.tap(find.text('Continua'));
      await tester.pumpAndSettle();

      expect(find.byType(UnderageNoticePage), findsNothing);
      // The form of step 2 has phone, name, e-mail and two passwords.
      expect(find.byType(TextFormField).evaluate().length, greaterThan(3));
    });
  });

  group('closed account page', () {
    testWidgets('offers deleting the account, writing to support and signing out', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      AgeStore.useForTest(_FakeBackend(declared: _status(AgeBand.underMinimum)));

      await tester.pumpWidget(_app(const ClosedAccountPage()));
      await tester.pumpAndSettle();

      expect(find.text('Quokka è per chi ha almeno 14 anni'), findsOneWidget);
      expect(find.textContaining("Puoi eliminare l'account e tutti i dati"), findsOneWidget);
      expect(find.textContaining('Dopo 30 giorni'), findsNothing);
      expect(find.text('Elimina account'), findsOneWidget);
      expect(find.text('Scarica i miei dati'), findsOneWidget);
      expect(find.text('Esci'), findsOneWidget);

      await tester.tap(find.text('Elimina account'));
      await tester.pumpAndSettle();
      expect(find.byType(DeleteAccountPage), findsOneWidget);
    });
  });

  group('Mercatino gate', () {
    Future<void> openGate(WidgetTester tester, AgeStatus? declared) async {
      AgeStore.useForTest(_FakeBackend(declared: declared));
      await tester.pumpWidget(
        _app(const MarketplaceAgeGate(child: Scaffold(body: Text('IL MERCATINO')))),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('an adult goes through', (tester) async {
      await openGate(tester, _status(AgeBand.adult));
      expect(find.text('IL MERCATINO'), findsOneWidget);
    });

    testWidgets('a minor is told it opens at 18', (tester) async {
      await openGate(tester, _status(AgeBand.minor));
      expect(find.text('IL MERCATINO'), findsNothing);
      expect(find.text('Il Mercatino è per chi ha almeno 18 anni'), findsOneWidget);
    });

    testWidgets('no date yet: the date is asked, and an adult answer opens the page', (
      tester,
    ) async {
      await openGate(tester, null);
      expect(find.text('IL MERCATINO'), findsNothing);

      await tester.enterText(find.byType(TextFormField), '01/05/1990');
      await tester.tap(find.text('Continua'));
      await tester.pumpAndSettle();
      expect(find.text('IL MERCATINO'), findsOneWidget);
    });
  });
}
