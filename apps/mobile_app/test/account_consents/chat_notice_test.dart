import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/app/router/app_router.dart';
import 'package:vet_app_mobile/features/account_consents/application/chat_notice.dart';
import 'package:vet_app_mobile/features/account_consents/data/account_consents_remote_data_source.dart';
import 'package:vet_app_mobile/features/account_consents/domain/account_consent_models.dart';
import 'package:vet_app_mobile/features/account_consents/presentation/pages/emergency_notice_gate_page.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';
import 'package:vet_app_mobile/shared/errors/app_network_error.dart';
import 'package:vet_app_mobile/shared/types/result.dart';

const _notice = AccountConsentKeys.emergencyNotice;

class _Backend implements AccountConsentsRemoteDataSource {
  _Backend({
    this.knows = true,
    this.accepted,
    this.offline = false,
    this.version = 'v1',
    this.text = 'urgenze',
  });

  /// What the server's catalogue holds now for the text.
  String version;
  String text;

  /// The versions each acceptance declared.
  final List<String?> declared = [];

  /// False: an older server, without this text in its catalogue.
  bool knows;
  String? accepted;
  bool offline;
  int fetches = 0;
  final List<String> set = [];

  AccountConsentsSnapshot get _snapshot => AccountConsentsSnapshot(
        decisions: {
          if (accepted != null)
            _notice: ConsentDecision(
              granted: true,
              version: accepted!,
              decidedAt: DateTime(2026, 11, 24),
            ),
        },
        catalog: {if (knows) _notice: ConsentCatalogEntry(version: version, text: text)},
      );

  @override
  Future<Result<AccountConsentsSnapshot>> fetch() async {
    fetches++;
    if (offline) return Result.failure(const AppNetworkError(code: 'consent_offline'));
    return Result.success(_snapshot);
  }

  @override
  Future<Result<AccountConsentsSnapshot>> setConsent({
    required String consentKey,
    required bool granted,
    String? shownVersion,
  }) async {
    if (offline || !knows) return Result.failure(const AppNetworkError(code: 'consent_http_400'));
    if (shownVersion != null && shownVersion != version) {
      return Result.failure(const AppNetworkError(code: kConsentVersionMismatchCode));
    }
    declared.add(shownVersion);
    set.add(consentKey);
    return Result.success(_snapshot);
  }
}

Future<bool?> Function() _pump(WidgetTester tester, _Backend backend) {
  bool? result;
  AppLocaleHolder.current = const Locale('it');
  return () async {
    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: AppRouter.scaffoldMessengerKey,
        locale: const Locale('it'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  result = await ChatNotice.ensure(context, dataSource: backend),
              child: const Text('chat'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('chat'));
    await tester.pumpAndSettle();
    return result;
  };
}

Future<void> _accept(WidgetTester tester) async {
  await tester.tap(find.byType(CheckboxListTile));
  await tester.pump();
  await tester.tap(find.byType(FilledButton));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the first chat asks, once, and the answer is recorded', (tester) async {
    final backend = _Backend();
    final open = _pump(tester, backend);

    await open();
    expect(find.byType(EmergencyNoticeGatePage), findsOneWidget);
    await _accept(tester);
    expect(backend.set, [_notice]);
    expect(find.byType(EmergencyNoticeGatePage), findsNothing);

    // The second chat: no question, no wait for the server (a check may run behind it).
    expect(await open(), isTrue);
    expect(find.byType(EmergencyNoticeGatePage), findsNothing);
    expect(backend.declared, ['v1']);
  });

  testWidgets('accepted on another phone: not asked again', (tester) async {
    expect(await _pump(tester, _Backend(accepted: 'v1'))(), isTrue);
    expect(find.byType(EmergencyNoticeGatePage), findsNothing);
  });

  testWidgets('an older version of the text is asked again', (tester) async {
    await _pump(tester, _Backend(accepted: 'v0'))();
    expect(find.byType(EmergencyNoticeGatePage), findsOneWidget);
  });

  testWidgets('a server that does not know the text never keeps the owner out', (tester) async {
    final backend = _Backend(knows: false);
    final open = _pump(tester, backend);
    await open();
    await _accept(tester);
    expect(await open(), isTrue); // in, although nothing could be recorded

    // Recorded as soon as the server knows it, once.
    backend.knows = true;
    await ChatNotice.submitPending(backend);
    await ChatNotice.submitPending(backend);
    expect(backend.set, [_notice]);
  });

  testWidgets('a newer text in the catalogue is the one shown, with its own version', (tester) async {
    final backend = _Backend(version: 'v2', text: 'testo nuovo del server');
    final open = _pump(tester, backend);
    await open();

    expect(find.text('testo nuovo del server'), findsOneWidget);
    await _accept(tester);
    expect(backend.declared, ['v2']);
  });

  testWidgets('a text that changed while it was read is asked again with the new one', (tester) async {
    // The first read says v1; by the time the answer arrives the server holds v2.
    final backend = _Backend();
    final open = _pump(tester, backend);
    await open();
    backend
      ..version = 'v2'
      ..text = 'secondo testo';
    await _accept(tester);

    expect(find.text('secondo testo'), findsOneWidget);
    await _accept(tester);
    expect(backend.declared, ['v2']);
  });

  testWidgets('a refused version never closes the chat and is not sent as another one', (tester) async {
    final backend = _Backend();
    final open = _pump(tester, backend);
    await open();
    backend
      ..version = 'v2'
      ..offline = true; // the catalogue cannot be read again either
    await _accept(tester);
    backend.offline = false;

    // The chat opened. What was shown was v1: v1 is what is sent later, and the server refuses
    // it, so nothing is recorded under v2 and the next chat asks again with the new text.
    await ChatNotice.submitPending(backend);
    expect(backend.declared, isEmpty);
    await open();
    expect(find.byType(EmergencyNoticeGatePage), findsOneWidget);
  });

  testWidgets('with no network the acceptance stays on the phone', (tester) async {
    final backend = _Backend(offline: true);
    final open = _pump(tester, backend);
    await open();
    await _accept(tester);
    backend.offline = false;
    await ChatNotice.submitPending(backend);
    expect(backend.set, [_notice]);
  });

  testWidgets('"Non accetto" closes only the chat and says so', (tester) async {
    final backend = _Backend();
    final open = _pump(tester, backend);
    await open();
    await tester.tap(find.text('Non accetto'));
    await tester.pumpAndSettle();

    expect(backend.set, isEmpty);
    expect(find.byType(EmergencyNoticeGatePage), findsNothing);
    expect(find.textContaining('Il resto dell'), findsOneWidget);
    // Asked again at the next chat.
    await open();
    expect(find.byType(EmergencyNoticeGatePage), findsOneWidget);
  });

  testWidgets('signing out forgets the answer of this account', (tester) async {
    final open = _pump(tester, _Backend());
    await open();
    await _accept(tester);
    await ChatNotice.clear();
    await _pump(tester, _Backend())();
    expect(find.byType(EmergencyNoticeGatePage), findsOneWidget);
  });

  test('what build 44 kept as a yes/no is sent with the text it showed', () async {
    SharedPreferences.setMockInitialValues({'vet_app.chat_notice_pending': true});
    final backend = _Backend();
    await ChatNotice.submitPending(backend);
    await ChatNotice.submitPending(backend);
    expect(backend.set, [_notice]); // once
  });

  group('the page (docs/compliance/22 §5)', () {
    Future<void> page(WidgetTester tester) async {
      AppLocaleHolder.current = const Locale('it');
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('it'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: EmergencyNoticeGatePage(),
        ),
      );
    }

    testWidgets('title, short text in view, box NOT pre-ticked, Continue off', (tester) async {
      await page(tester);
      expect(find.text('Quokka non gestisce le urgenze'), findsOneWidget);
      // The short version is on the page itself, not behind a link.
      expect(find.textContaining('Non aspettare la risposta dell'), findsOneWidget);
      expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value, isFalse);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
      expect(find.text('Leggi il testo completo nei Termini di Servizio'), findsOneWidget);
    });

    testWidgets('"Non accetto" is as big as "Continua"', (tester) async {
      await page(tester);
      expect(
        tester.getSize(find.byType(OutlinedButton)),
        tester.getSize(find.byType(FilledButton)),
      );
    });
  });
}
