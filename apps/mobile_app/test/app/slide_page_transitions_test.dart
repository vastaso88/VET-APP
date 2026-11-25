import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vet_app_mobile/app/theme/app_theme.dart';

Widget _app({bool reduceMotion = false}) => MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('nuova')),
              ),
            ),
            child: const Text('vecchia'),
          ),
        ),
      ),
    );

Finder _page(String text) =>
    find.ancestor(of: find.text(text), matching: find.byType(Scaffold)).first;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('the new page slides over the old one, nothing fades', (tester) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.text('vecchia'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    expect(tester.getTopLeft(_page('nuova')).dx, greaterThan(0));
    expect(tester.getTopLeft(_page('vecchia')).dx, 0, reason: 'the old page stays still');
    for (final text in ['nuova', 'vecchia']) {
      for (final fade in tester.widgetList<FadeTransition>(
        find.ancestor(of: _page(text), matching: find.byType(FadeTransition)),
      )) {
        expect(fade.opacity.value, 1, reason: text);
      }
    }

    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.getTopLeft(_page('nuova')).dx, 0);
    await tester.pumpAndSettle();
    expect(find.text('vecchia'), findsNothing);
  });

  testWidgets('with "reduce motion" the page is there at once', (tester) async {
    await tester.pumpWidget(_app(reduceMotion: true));
    await tester.tap(find.text('vecchia'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(tester.getTopLeft(_page('nuova')).dx, 0);
    await tester.pumpAndSettle();
  });
}
