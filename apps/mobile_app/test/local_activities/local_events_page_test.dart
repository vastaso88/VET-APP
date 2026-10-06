import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/features/local_events/presentation/pages/local_events_page.dart';
import 'package:vet_app_mobile/features/location/data/location_preference_store.dart';
import 'package:vet_app_mobile/features/location/domain/coordinates.dart';

/// The page has a map preview plus two list sections, taller than the
/// default 800x600 test surface - same fix as chat_feature_test.dart's
/// _useTallSurface.
Future<void> _useTallSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(400, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  // Seeds the in-memory SharedPreferences implementation so
  // LocationPreferenceStore.ensureLoaded() resolves on its normal path
  // instead of paying a one-off real-platform-channel setup cost the
  // first time it's ever touched in this isolate (that extra cost is what
  // made the very first test of this file flaky before this fix).
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    // The real app calls this once in app/bootstrap.dart before runApp();
    // this test pumps LocalEventsPage() directly, bypassing bootstrap, so
    // DateFormat('d MMM', 'it_IT') would otherwise throw the first time an
    // activity actually has a startsAt to format.
    await initializeDateFormatting('it_IT');
    // The page has no default city any more: it needs a Località. A saved
    // home near the seeded demo activities stands in for the user's.
    await LocationPreferenceStore.instance.update(
      const UserLocationPreference(
        mode: LocationMode.homeResidence,
        home: Coordinates(latitude: 45.4642, longitude: 9.1900),
      ),
    );
  });

  testWidgets('shows the seeded service in "Servizi nella zona" (no date)', (tester) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(const MaterialApp(home: LocalEventsPage()));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Ambulatorio veterinario Navigli'), findsOneWidget);
    expect(find.text('Servizi nella zona'), findsOneWidget);
    // No backend in this build: the page says so, and never asks to sign in.
    expect(find.text('Anteprima senza backend: i luoghi mostrati sono dati di esempio.'),
        findsOneWidget);
    expect(find.textContaining('Accedi per vedere'), findsNothing);
    expect(find.text('Riprova'), findsNothing);
  });

  testWidgets('dated events are not part of the page', (tester) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(const MaterialApp(home: LocalEventsPage()));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Vicino a me'), findsOneWidget);
    expect(find.text('In programma'), findsNothing);
    expect(find.text('Fiera cinofila regionale'), findsNothing);
    expect(find.text('Giornata vaccinazioni gratuite'), findsNothing);
    expect(find.text('Eventi'), findsNothing);
  });

  testWidgets('tapping an activity opens its detail page', (tester) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(const MaterialApp(home: LocalEventsPage()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('Ambulatorio veterinario Navigli'));
    await tester.pumpAndSettle();

    expect(find.text('Navigli, Milano'), findsOneWidget);
  });
}
