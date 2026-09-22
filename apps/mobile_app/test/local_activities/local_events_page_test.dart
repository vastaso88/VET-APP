import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/features/local_events/presentation/pages/local_events_page.dart';

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
  });

  testWidgets('shows the seeded service in "Servizi nella zona" (no date)', (tester) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(const MaterialApp(home: LocalEventsPage()));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Ambulatorio veterinario Navigli'), findsOneWidget);
    expect(find.text('Servizi nella zona'), findsOneWidget);
  });

  testWidgets('shows seeded dated events in "In programma"', (tester) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(const MaterialApp(home: LocalEventsPage()));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('In programma'), findsOneWidget);
    expect(find.text('Fiera cinofila regionale'), findsOneWidget);
    expect(find.text('Giornata vaccinazioni gratuite'), findsOneWidget);
  });

  testWidgets('tapping an activity opens its detail page', (tester) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(const MaterialApp(home: LocalEventsPage()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('Ambulatorio veterinario Navigli'));
    await tester.pumpAndSettle();

    expect(find.text('Navigli, Milano'), findsOneWidget);
  });
}
