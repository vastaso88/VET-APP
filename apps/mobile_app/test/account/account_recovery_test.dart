import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/account/data/account_deletion_remote_data_source.dart';
import 'package:vet_app_mobile/features/account/presentation/pages/restore_account_page.dart';
import 'package:vet_app_mobile/features/auth/presentation/pages/auth_placeholder_page.dart';
import 'package:vet_app_mobile/features/auth/presentation/pages/login_page.dart';
import 'package:vet_app_mobile/features/auth/presentation/pages/recover_account_page.dart';
import 'package:vet_app_mobile/features/auth/presentation/pages/reset_password_page.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';
import 'package:vet_app_mobile/shared/errors/app_network_error.dart';
import 'package:vet_app_mobile/shared/types/result.dart';

class _Backend implements AccountDeletionRemoteDataSource {
  _Backend({this.failWith});

  final String? failWith;
  int cancelCalls = 0;
  int deleteNowCalls = 0;

  @override
  Future<Result<void>> deleteNow() async {
    deleteNowCalls++;
    if (failWith != null) return Result.failure(AppNetworkError(code: failWith!));
    return Result.success(null);
  }

  int pauseCalls = 0;

  @override
  Future<Result<DateTime?>> pause() async {
    pauseCalls++;
    return Result.success(null);
  }

  @override
  Future<Result<DeletionStatus>> fetch() async =>
      Result.success(const DeletionStatus(pending: true, graceDays: 30));

  @override
  Future<Result<DeletionStatus>> cancel() async {
    cancelCalls++;
    if (failWith != null) return Result.failure(AppNetworkError(code: failWith!));
    return Result.success(const DeletionStatus(pending: false, graceDays: 30));
  }
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

void main() {
  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('the first screen has a small "Recupera account" link under the two buttons', (
    tester,
  ) async {
    tall(tester);
    await tester.pumpWidget(_app(const AuthPlaceholderPage()));

    expect(find.text('Nuovo account'), findsOneWidget);
    expect(find.text('Recupera account'), findsOneWidget);

    await tester.tap(find.text('Recupera account'));
    await tester.pumpAndSettle();
    expect(find.byType(RecoverAccountPage), findsOneWidget);
  });

  testWidgets('"Recupera account" leads to the ordinary sign-in and to the password reset', (
    tester,
  ) async {
    tall(tester);
    await tester.pumpWidget(_app(const RecoverAccountPage()));

    await tester.tap(find.text('Reimposta la password'));
    await tester.pumpAndSettle();
    expect(find.byType(ResetPasswordPage), findsOneWidget);

    Navigator.of(tester.element(find.byType(ResetPasswordPage))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accedi con la stessa e-mail'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
  });

  group('the page of an account waiting to be erased', () {
    final status = DeletionStatus(
      pending: true,
      graceDays: 30,
      purgeAfter: DateTime(2026, 12, 16),
    );

    testWidgets('shows the day and offers cancelling or signing out', (tester) async {
      tall(tester);
      await tester.pumpWidget(_app(RestoreAccountPage(status: status, dataSource: _Backend())));

      expect(find.text('Il tuo account è in eliminazione'), findsOneWidget);
      expect(find.textContaining('16/12/2026'), findsOneWidget);
      expect(find.text("Annulla l'eliminazione"), findsOneWidget);
      expect(find.text('Esci'), findsOneWidget);
    });

    testWidgets('an old sign-in is told to sign in again, nothing else changes', (tester) async {
      tall(tester);
      final backend = _Backend(failWith: 'reauth_required');
      await tester.pumpWidget(_app(RestoreAccountPage(status: status, dataSource: backend)));

      await tester.tap(find.text("Annulla l'eliminazione"));
      await tester.pumpAndSettle();

      expect(backend.cancelCalls, 1);
      expect(find.textContaining('accesso recente'), findsOneWidget);
      expect(find.text("Annulla l'eliminazione"), findsOneWidget);
    });

    testWidgets('"Elimina subito" asks first, and an old sign-in is told to sign in again', (
      tester,
    ) async {
      tall(tester);
      final backend = _Backend(failWith: 'reauth_required');
      await tester.pumpWidget(_app(RestoreAccountPage(status: status, dataSource: backend)));

      await tester.ensureVisible(find.text('Elimina subito'));
      await tester.tap(find.text('Elimina subito'));
      await tester.pumpAndSettle();
      expect(find.textContaining("Cancelliamo subito l'account"), findsOneWidget);
      expect(backend.deleteNowCalls, 0, reason: 'nothing is erased before the confirmation');

      await tester.tap(find.text('Elimina subito').last);
      await tester.pumpAndSettle();

      expect(backend.deleteNowCalls, 1);
      expect(find.textContaining('accesso recente'), findsOneWidget);
    });

    testWidgets('cancelling the confirmation erases nothing', (tester) async {
      tall(tester);
      final backend = _Backend();
      await tester.pumpWidget(_app(RestoreAccountPage(status: status, dataSource: backend)));

      await tester.ensureVisible(find.text('Elimina subito'));
      await tester.tap(find.text('Elimina subito'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();

      expect(backend.deleteNowCalls, 0);
    });

    testWidgets('any other failure says so and lets the owner retry', (tester) async {
      tall(tester);
      await tester.pumpWidget(
        _app(RestoreAccountPage(status: status, dataSource: _Backend(failWith: 'boom'))),
      );

      await tester.tap(find.text("Annulla l'eliminazione"));
      await tester.pumpAndSettle();

      expect(find.textContaining('Non sono riuscito ad annullare'), findsOneWidget);
    });
  });
}
