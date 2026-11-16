import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/l10n/app_localizations.dart';
import 'package:vet_app_mobile/shared/widgets/short_notice.dart';

bool? _answer;

Future<void> _open(WidgetTester tester, ShortNotice notice) async {
  _answer = null;
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            key: const ValueKey('go'),
            onPressed: () async => _answer = await showShortNoticeOnce(context, notice),
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
    expect(_answer, isTrue);

    await _open(tester, ShortNotice.firstWalk);
    expect(find.textContaining('ultime 3 passeggiate'), findsNothing);
    expect(_answer, isTrue);
  });

  testWidgets('each activity has its own notice', (tester) async {
    await _open(tester, ShortNotice.recordDocument);
    await tester.tap(find.byKey(const ValueKey('short-notice-ok')));
    await tester.pumpAndSettle();

    await _open(tester, ShortNotice.chatAi);
    expect(find.textContaining('intelligenza artificiale'), findsOneWidget);
  });

  testWidgets('the photo and voice notice can be cancelled and then comes back', (tester) async {
    await _open(tester, ShortNotice.chatMedia);
    expect(find.text('Continua'), findsOneWidget);
    expect(find.text('Annulla'), findsOneWidget);
    expect(find.text('Informativa'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('short-notice-cancel')));
    await tester.pumpAndSettle();
    expect(_answer, isFalse);

    await _open(tester, ShortNotice.chatMedia);
    await tester.tap(find.byKey(const ValueKey('short-notice-ok')));
    await tester.pumpAndSettle();
    expect(_answer, isTrue);
  });

  testWidgets('the Mercatino notice links to the Terms, not to the privacy notice', (tester) async {
    await _open(tester, ShortNotice.marketplace);
    expect(find.textContaining('solo per maggiorenni'), findsOneWidget);
    expect(find.text('Regole'), findsOneWidget);
    expect(find.text('Informativa'), findsNothing);
  });

  testWidgets('signing out empties what was acknowledged', (tester) async {
    await _open(tester, ShortNotice.chatAi);
    await tester.tap(find.byKey(const ValueKey('short-notice-ok')));
    await tester.pumpAndSettle();
    expect(await ShortNoticeStore.instance.wasSeen(ShortNotice.chatAi), isTrue);

    await ShortNoticeStore.instance.clear();
    expect(await ShortNoticeStore.instance.wasSeen(ShortNotice.chatAi), isFalse);
  });
}
