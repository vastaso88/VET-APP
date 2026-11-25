import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/features/account/presentation/pages/delete_account_page.dart';
import 'package:vet_app_mobile/features/age/data/account_age_remote_data_source.dart';
import 'package:vet_app_mobile/features/age/data/age_store.dart';
import 'package:vet_app_mobile/features/age/domain/age_status.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';
import 'package:vet_app_mobile/shared/types/result.dart';

/// A backend that answers with one fixed age status.
class _AgeBackend implements AccountAgeRemoteDataSource {
  _AgeBackend(this.band);

  final AgeBand band;

  AgeStatus get _status => AgeStatus(
        band: band,
        marketplaceAllowed: band == AgeBand.adult,
        guardianRequired: false,
        guardianConfirmed: false,
        paidPlanAllowed: band == AgeBand.adult,
      );

  @override
  Future<Result<AgeStatus>> fetch() async => Result.success(_status);

  @override
  Future<Result<AgeStatus>> declare(DateTime birthDate) async => Result.success(_status);

  @override
  Future<Result<AgeStatus>> confirmGuardian() async => Result.success(_status);
}

Widget _app() {
  AppLocaleHolder.current = const Locale('it');
  return MaterialApp(
    locale: const Locale('it'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: const DeleteAccountPage(),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(AgeStore.restoreDefault);

  testWidgets('the page is the deletion, at once: password and confirmation, no pause', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsOneWidget);
    // The pause of the account does not exist any more (owner, 25 November 2026).
    expect(find.textContaining('pausa'), findsNothing);
    expect(find.text('Cosa vuoi fare con il tuo account?'), findsNothing);
  });

  testWidgets('a closed account (under the minimum age) sees the same deletion page', (
    tester,
  ) async {
    AgeStore.useForTest(_AgeBackend(AgeBand.underMinimum));
    await AgeStore.instance.refresh();
    expect(AgeStore.instance.status.band, AgeBand.underMinimum);

    await tester.pumpWidget(_app());
    await tester.pump();

    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.textContaining('pausa'), findsNothing);
  });
}
