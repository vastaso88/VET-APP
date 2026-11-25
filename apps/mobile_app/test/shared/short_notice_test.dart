import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/l10n/app_localizations.dart';
import 'package:vet_app_mobile/shared/widgets/short_notice.dart';

Future<void> _open(WidgetTester tester, ShortNotice notice) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            key: const ValueKey('go'),
            onPressed: () => showShortNoticeOnce(context, notice),
            child: const Text('vai'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('go')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('an acknowledgement shows the text once, then never again', (tester) async {
    await _open(tester, ShortNotice.firstWalk);
    expect(find.textContaining('ultime 3 passeggiate'), findsOneWidget);
    expect(find.text('Ho capito'), findsOneWidget);
    expect(find.text('Informativa'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('short-notice-ok')));
    await tester.pumpAndSettle();

    await _open(tester, ShortNotice.firstWalk);
    expect(find.textContaining('ultime 3 passeggiate'), findsNothing);
  });

  testWidgets('each activity has its own notice', (tester) async {
    await _open(tester, ShortNotice.recordDocument);
    await tester.tap(find.byKey(const ValueKey('short-notice-ok')));
    await tester.pumpAndSettle();

    await _open(tester, ShortNotice.firstWalk);
    expect(find.textContaining('ultime 3 passeggiate'), findsOneWidget);
  });

  test('the chat has no short notice of its own any more: its screen says it all', () {
    expect(
      ShortNotice.values.map((notice) => notice.id),
      ['record_document', 'first_walk', 'marketplace'],
    );
  });

  testWidgets('the Mercatino notice links to the Terms, not to the privacy notice', (tester) async {
    await _open(tester, ShortNotice.marketplace);
    expect(find.textContaining('solo per maggiorenni'), findsOneWidget);
    expect(find.text('Regole'), findsOneWidget);
    expect(find.text('Informativa'), findsNothing);
  });

  testWidgets('signing out empties what was acknowledged', (tester) async {
    await _open(tester, ShortNotice.firstWalk);
    await tester.tap(find.byKey(const ValueKey('short-notice-ok')));
    await tester.pumpAndSettle();
    expect(await ShortNoticeStore.instance.wasSeen(ShortNotice.firstWalk), isTrue);

    await ShortNoticeStore.instance.clear();
    expect(await ShortNoticeStore.instance.wasSeen(ShortNotice.firstWalk), isFalse);
  });
}
