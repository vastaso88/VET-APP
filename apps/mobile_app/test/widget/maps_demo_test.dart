import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/app/preview/maps_demo_page.dart';

/// Isolated widget test for the maps foundations demo harness
/// (docs/maps/): pumps MapsDemoPage() directly rather than the full app
/// shell, so it stays independent of splash/bootstrap/nav concerns. Only
/// asserts on the legend counts (seed data resolved correctly), not on
/// tile imagery, since the OSM tile layer does real network image
/// requests that flutter_test doesn't mock.
void main() {
  testWidgets('maps demo route renders seed data from all three features', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MapsDemoPage()));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Maps demo (fondamenta)'), findsOneWidget);
    expect(find.textContaining('Attività/eventi: 3'), findsOneWidget);
    expect(find.textContaining('Annunci mercatino: 1'), findsOneWidget);
    expect(find.textContaining('Percorsi passeggiata: 1'), findsOneWidget);
  });
}
