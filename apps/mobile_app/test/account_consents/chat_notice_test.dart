import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/app/router/app_router.dart';
import 'package:vet_app_mobile/features/account_consents/application/chat_notice.dart';
import 'package:vet_app_mobile/features/account_consents/data/account_consents_remote_data_source.dart';
import 'package:vet_app_mobile/features/account_consents/domain/account_consent_models.dart';
import 'package:vet_app_mobile/features/account_consents/presentation/pages/emergency_notice_gate_page.dart';
import 'package:vet_app_mobile/features/auth/presentation/pages/legal_text_page.dart';
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

/// The screen of the AI provider accepted on this phone (see ChatNotice).
const _provider = 'vet_app.chat_ai_provider';

Future<bool> _providerSeen() async =>
    (await SharedPreferences.getInstance()).getBool(_provider) ?? false;

Future<void> _accept(WidgetTester tester) async {
  await tester.tap(find.byType(CheckboxListTile));
  await tester.pump();
  await tester.tap(find.byType(FilledButton));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  // What one test found out about the server must not stop the next from asking it.
  tearDown(ChatNotice.clear);

  testWidgets('the first chat asks, once, and the answer is recorded', (tester) async {
    final backend = _Backend();
    final open = _pump(tester, backend);

    await open();
    expect(find.byType(EmergencyNoticeGatePage), findsOneWidget);
    await _accept(tester);
    expect(backend.set, [_notice]);
    expect(await _providerSeen(), isTrue);
    expect(find.byType(EmergencyNoticeGatePage), findsNothing);

    // The second chat: no question, no wait for the server (a check may run behind it).
    expect(await open(), isTrue);
    expect(find.byType(EmergencyNoticeGatePage), findsNothing);
    expect(backend.declared, ['v1']);
  });

  group('the AI provider: everybody sees the screen once', () {
    testWidgets('who had accepted on this phone sees it, nothing is recorded again',
        (tester) async {
      SharedPreferences.setMockInitialValues({'vet_app.chat_notice_accepted': 'v1'});
      final backend = _Backend(accepted: 'v1');
      final open = _pump(tester, backend);
      await open();
      expect(find.byType(EmergencyNoticeGatePage), findsOneWidget);
      // The server has nothing to say about it: shown without waiting for it.
      expect(backend.fetches, 0);
      await _accept(tester);
      expect(backend.set, isEmpty);

      expect(await open(), isTrue);
      expect(find.byType(EmergencyNoticeGatePage), findsNothing);
    });

    testWidgets('who had accepted with no network sees it, and the acceptance still waits',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'vet_app.chat_notice_accepted': 'v1',
        'vet_app.chat_notice_pending_version': 'v1',
      });
      final backend = _Backend(offline: true);
      final open = _pump(tester, backend);
      await open();
      await _accept(tester);
      expect(await open(), isTrue);
      expect(find.byType(EmergencyNoticeGatePage), findsNothing);

      backend.offline = false;
      await ChatNotice.submitPending(backend);
      expect(backend.declared, ['v1']);
    });

    testWidgets('who had accepted on another phone sees it once, nothing is recorded again',
        (tester) async {
      final backend = _Backend(accepted: 'v1');
      final open = _pump(tester, backend);
      await open();
      expect(find.byType(EmergencyNoticeGatePage), findsOneWidget);
      await _accept(tester);
      expect(backend.set, isEmpty);

      expect(await open(), isTrue);
      expect(find.byType(EmergencyNoticeGatePage), findsNothing);
    });

    testWidgets('"Non accetto" closes the chat and takes nothing back', (tester) async {
      SharedPreferences.setMockInitialValues({'vet_app.chat_notice_accepted': 'v1'});
      final backend = _Backend(accepted: 'v1');
      final open = _pump(tester, backend);
      await open();
      await tester.tap(find.text('Non accetto'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Il resto dell'), findsOneWidget);
      expect(backend.set, isEmpty);
      expect(await _providerSeen(), isFalse);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('vet_app.chat_notice_accepted'), 'v1');
      // Asked again at the next chat.
      await open();
      expect(find.byType(EmergencyNoticeGatePage), findsOneWidget);
    });

    testWidgets('seen here and accepted on another phone: nothing to ask', (tester) async {
      SharedPreferences.setMockInitialValues({_provider: true});
      expect(await _pump(tester, _Backend(accepted: 'v1'))(), isTrue);
      expect(find.byType(EmergencyNoticeGatePage), findsNothing);
    });

    testWidgets('a server out of reach shows it all the same and the chat opens', (tester) async {
      final backend = _Backend(offline: true);
      final open = _pump(tester, backend);
      await open();
      await _accept(tester);
      expect(await open(), isTrue);
    });

    testWidgets('a newer text accepted on this phone is shown again as the server words it',
        (tester) async {
      SharedPreferences.setMockInitialValues({'vet_app.chat_notice_accepted': 'v2'});
      final backend = _Backend(version: 'v2', text: 'testo nuovo del server', accepted: 'v2');
      final open = _pump(tester, backend);
      await open();
      expect(find.textContaining('testo nuovo del server'), findsOneWidget);
      await _accept(tester);
      expect(backend.set, isEmpty);
      expect(await open(), isTrue);
    });

    testWidgets('signing out forgets it, a refused version does not', (tester) async {
      final backend = _Backend();
      final open = _pump(tester, backend);
      await open();
      await _accept(tester);
      backend.version = 'v2';
      await ChatNotice.submitPending(backend);
      expect(await _providerSeen(), isTrue);

      await ChatNotice.clear();
      expect(await _providerSeen(), isFalse);
    });
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

    // In the place of the app's own text, next to who answers: not a word of the old one.
    final shown = tester.widget<Text>(find.textContaining('testo nuovo del server')).data!;
    expect(shown, startsWith("Ti risponde un'intelligenza artificiale"));
    expect(shown, endsWith('nell\'informativa. testo nuovo del server'));
    expect(find.textContaining('Non aspettare la risposta'), findsNothing);
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

    expect(find.textContaining('secondo testo'), findsOneWidget);
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

    testWidgets('title, texts in view, box NOT pre-ticked, "Accetto" off', (tester) async {
      await page(tester);
      expect(find.text('Prima della tua prima chat'), findsOneWidget);
      // Who answers and where the questions go, and the short version of the emergencies: on
      // the page itself, not behind a link.
      expect(find.textContaining('Anthropic, il nostro fornitore di IA'), findsOneWidget);
      expect(find.textContaining('Non aspettare la risposta dell'), findsOneWidget);
      expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value, isFalse);
      expect(find.text('Accetto e inizio la chat'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
      expect(find.text('Leggi il testo completo nei Termini di Servizio'), findsOneWidget);
    });

    testWidgets('"Leggi l\'informativa" opens the privacy notice', (tester) async {
      await page(tester);
      await tester.tap(find.text("Leggi l'informativa"));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      final legal = tester.widget<LegalTextPage>(find.byType(LegalTextPage));
      expect(legal.consentKey, AccountConsentKeys.privacyPolicy);
    });

    testWidgets('"Non accetto" is as big as "Accetto e inizio la chat"', (tester) async {
      await page(tester);
      expect(
        tester.getSize(find.byType(OutlinedButton)),
        tester.getSize(find.byType(FilledButton)),
      );
    });
  });
}
