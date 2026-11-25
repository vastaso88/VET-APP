import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vet_app_mobile/features/chat/data/chat_remote_data_source.dart'
    show chatMaxMessageLength;
import 'package:vet_app_mobile/features/chat/data/system_dictation.dart';
import 'package:vet_app_mobile/features/chat/presentation/widgets/chat_composer.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';

import 'fake_dictation.dart';

/// Owner decision of 25 November 2026: the phone turns the voice into text, the text joins
/// what is already written, and only the owner sends it.
Future<List<String>> _pump(WidgetTester tester, FakeDictation dictation) async {
  final sent = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ChatComposer(
          hintText: 'Scrivi',
          petName: 'Rex',
          dictation: dictation,
          onSend: (text, {attachmentId, attachmentImageBytes}) => sent.add(text),
        ),
      ),
    ),
  );
  await tester.pump();
  return sent;
}

Future<void> _tapMic(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.mic_none_rounded));
  await tester.pump();
  await tester.pump();
}

String _field(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppLocaleHolder.current = const Locale('it', 'IT');
  });
  tearDown(() => AppLocaleHolder.current = const Locale('it'));

  testWidgets('se il telefono non riconosce la voce il pulsante non c\'è, senza errori',
      (tester) async {
    await _pump(tester, FakeDictation(available: false));

    expect(find.byIcon(Icons.mic_none_rounded), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    // Il resto del campo resta com'è.
    expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
  });

  testWidgets('il testo riconosciuto si aggiunge a quello già scritto e lo invia la persona',
      (tester) async {
    final dictation = FakeDictation();
    final sent = await _pump(tester, dictation);
    await tester.enterText(find.byType(TextField), 'Rex ');

    await _tapMic(tester);
    expect(dictation.starts, 1);
    expect(dictation.languageTag, 'it-IT');
    expect(find.byIcon(Icons.stop_circle_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.stop_circle_rounded));
    await tester.pump();
    expect(dictation.stopped, isTrue);
    expect(find.text(ChatComposer.transcribingText), findsOneWidget);

    dictation.hear('mangia poco da ieri');
    await tester.pump();

    expect(_field(tester), 'Rex mangia poco da ieri');
    expect(sent, isEmpty);
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pump();
    expect(sent, ['Rex mangia poco da ieri']);
  });

  testWidgets('una seconda dettatura si aggiunge alla prima, e il testo resta nei limiti',
      (tester) async {
    final dictation = FakeDictation();
    await _pump(tester, dictation);

    await _tapMic(tester);
    dictation.hear('prima frase');
    await tester.pump();
    await _tapMic(tester);
    dictation.hear('seconda frase');
    await tester.pump();
    expect(_field(tester), 'prima frase seconda frase');

    await _tapMic(tester);
    dictation.hear('a' * (chatMaxMessageLength + 50));
    await tester.pump();
    expect(_field(tester).length, chatMaxMessageLength);
  });

  testWidgets('la lingua del riconoscimento è quella dell\'app, con il suo paese', (tester) async {
    AppLocaleHolder.current = const Locale('en', 'AU');
    final dictation = FakeDictation();
    await _pump(tester, dictation);

    await _tapMic(tester);

    expect(dictation.languageTag, 'en-AU');
  });

  testWidgets('mentre ascolta non si invia: le parole finirebbero nel messaggio dopo',
      (tester) async {
    final dictation = FakeDictation();
    final sent = await _pump(tester, dictation);
    await tester.enterText(find.byType(TextField), 'Rex');
    await _tapMic(tester);

    await tester.tap(find.byIcon(Icons.arrow_upward_rounded), warnIfMissed: false);
    await tester.pump();
    expect(sent, isEmpty);

    dictation.hear('tossisce');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    expect(sent, ['Rex tossisce']);
  });

  testWidgets('silenzio: niente testo e un messaggio breve', (tester) async {
    final dictation = FakeDictation();
    await _pump(tester, dictation);
    await tester.enterText(find.byType(TextField), 'Rex');
    await _tapMic(tester);

    dictation.close();
    await tester.pump();
    dictation.fail(DictationProblem.nothingHeard);
    await tester.pump();

    expect(_field(tester), 'Rex');
    expect(find.text('Non sono riuscito a trascrivere il messaggio vocale.'), findsOneWidget);
    expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
  });

  testWidgets('se il microfono non parte mostra un messaggio invece di rompere l\'app',
      (tester) async {
    final dictation = FakeDictation(startError: Exception('listen failed'));
    await _pump(tester, dictation);

    await _tapMic(tester);

    expect(find.text('Non riesco ad avviare il microfono. Riprova.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Back to idle: the mic can be tapped again.
    expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
  });

  testWidgets('senza permesso prima si spiega a cosa serve; rifiutato dal sistema: messaggio',
      (tester) async {
    final dictation = FakeDictation(permission: false, access: DictationAccess.refused);
    await _pump(tester, dictation);

    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    await tester.pumpAndSettle();

    // Prima della richiesta di sistema: perché, chi riconosce la voce e cosa succede se si
    // rifiuta.
    expect(find.text('Usare il microfono?'), findsOneWidget);
    expect(find.textContaining('dettare i messaggi nella chat'), findsOneWidget);
    expect(find.textContaining('A Quokka arriva solo il testo, mai l\'audio'), findsOneWidget);
    expect(find.textContaining('Google o Apple'), findsOneWidget);
    expect(find.textContaining('scrivere i messaggi con la tastiera'), findsOneWidget);
    expect(dictation.prepared, isFalse);

    await tester.tap(find.text('Continua'));
    await tester.pumpAndSettle();

    expect(dictation.prepared, isTrue);
    expect(find.text('Serve il permesso per usare il microfono.'), findsOneWidget);
    expect(dictation.starts, 0);
  });

  testWidgets('"Non ora" non fa partire nessuna richiesta di sistema', (tester) async {
    final dictation = FakeDictation(permission: false);
    await _pump(tester, dictation);

    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Non ora'));
    await tester.pumpAndSettle();

    expect(dictation.prepared, isFalse);
    expect(dictation.starts, 0);
    // Si può riprovare: il microfono torna disponibile.
    expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
  });

  testWidgets('con il permesso già dato non compare nessuna spiegazione', (tester) async {
    final dictation = FakeDictation();
    await _pump(tester, dictation);

    await _tapMic(tester);

    expect(find.text('Usare il microfono?'), findsNothing);
    expect(dictation.starts, 1);
  });

  testWidgets('nel browser, che non dice se il permesso c\'è, si spiega una volta sola',
      (tester) async {
    final dictation = FakeDictation(permission: null);
    await _pump(tester, dictation);

    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Usare il microfono?'), findsOneWidget);
    await tester.tap(find.text('Continua'));
    // Not pumpAndSettle: the dot pulses while it listens.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(dictation.starts, 1);
    dictation.hear('ciao');
    await tester.pump();

    await _tapMic(tester);
    await tester.pump();
    expect(find.text('Usare il microfono?'), findsNothing);
    expect(dictation.starts, 2);
  });

  testWidgets('se il riconoscimento non c\'è davvero il pulsante sparisce, senza errori',
      (tester) async {
    final dictation = FakeDictation(access: DictationAccess.unavailable);
    await _pump(tester, dictation);

    await _tapMic(tester);

    expect(find.byIcon(Icons.mic_none_rounded), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('due tocchi in fretta aprono una sola spiegazione', (tester) async {
    final dictation = FakeDictation(permission: false);
    await _pump(tester, dictation);

    final mic = tester.widget<IconButton>(
      find.ancestor(of: find.byIcon(Icons.mic_none_rounded), matching: find.byType(IconButton)),
    );
    mic.onPressed!();
    mic.onPressed!();
    await tester.pumpAndSettle();

    expect(find.text('Usare il microfono?'), findsOneWidget);
  });

  testWidgets('quando l\'app esce dallo schermo il microfono si chiude', (tester) async {
    final dictation = FakeDictation();
    await _pump(tester, dictation);
    await _tapMic(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();

    expect(dictation.stopped, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('lasciando la pagina l\'ascolto si interrompe e nulla arriva dopo', (tester) async {
    final dictation = FakeDictation();
    await _pump(tester, dictation);
    await _tapMic(tester);

    await tester.pumpWidget(const SizedBox());
    expect(dictation.cancelled, isTrue);
    dictation.hear('troppo tardi');
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
