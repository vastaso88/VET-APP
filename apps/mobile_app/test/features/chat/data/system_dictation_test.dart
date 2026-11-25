import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:vet_app_mobile/features/chat/data/system_dictation.dart';

const _plugin = MethodChannel('plugin.csdcorp.com/speech_to_text');
const _app = MethodChannel('vetapp/app_navigation');

/// The phone's side of the speech plugin, as Android answers.
class _Phone {
  _Phone(this.tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_plugin, (call) async {
      calls.add(call.method);
      arguments[call.method] = call.arguments as Map<Object?, Object?>?;
      return switch (call.method) {
        'has_permission' => permission,
        'initialize' => notAvailable
            ? throw PlatformException(code: 'recognizerNotAvailable')
            : allowed,
        'listen' => listenError ? throw PlatformException(code: 'unknown') : true,
        _ => true,
      };
    });
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_plugin, null);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_app, null);
    });
  }

  final WidgetTester tester;
  final List<String> calls = [];
  final Map<String, Map<Object?, Object?>?> arguments = {};
  bool permission = true;
  bool allowed = true;
  bool notAvailable = false;
  bool listenError = false;

  Future<void> _tell(String method, Object argument) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      _plugin.name,
      _plugin.codec.encodeMethodCall(MethodCall(method, argument)),
      (_) {},
    );
    await tester.pump();
  }

  Future<void> status(String value) => _tell('notifyStatus', value);

  Future<void> error(String value) =>
      _tell('notifyError', jsonEncode({'errorMsg': value, 'permanent': true}));

  Future<void> words(String value, {bool last = false}) => _tell(
        'textRecognition',
        jsonEncode({
          'resultType': last ? 2 : 0,
          'alternates': [
            {'recognizedWords': value, 'confidence': 0.9},
          ],
        }),
      );
}

class _Listening {
  _Listening(this.dictation);

  final SystemDictation dictation;
  int closed = 0;
  final List<DictationResult> done = [];

  Future<void> start({String languageTag = 'it-IT'}) => dictation.start(
        languageTag: languageTag,
        onClosed: () => closed++,
        onDone: done.add,
      );
}

Future<(_Phone, SystemDictation)> _ready(WidgetTester tester) async {
  final phone = _Phone(tester);
  final dictation = SystemDictation(speech: SpeechToText.withMethodChannel());
  expect(await dictation.prepare(), DictationAccess.ready);
  return (phone, dictation);
}

void main() {
  group('is there a speech recognition on this phone', () {
    testWidgets('Android is asked, the microphone is not', (tester) async {
      final phone = _Phone(tester);
      final asked = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_app, (call) async {
        asked.add(call.method);
        return true;
      });
      final dictation = SystemDictation(speech: SpeechToText.withMethodChannel());

      expect(await dictation.isAvailable(), isTrue);
      expect(asked, ['speechRecognitionAvailable']);
      expect(phone.calls, isEmpty);
    });

    testWidgets('no, or no answer: no dictation, no error', (tester) async {
      _Phone(tester);
      final dictation = SystemDictation(speech: SpeechToText.withMethodChannel());
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_app, (_) async => false);
      expect(await dictation.isAvailable(), isFalse);

      // Nobody answers (an older native side): MissingPluginException.
      tester.binding.defaultBinaryMessenger.setMockMessageHandler(_app.name, (_) async => null);
      expect(await dictation.isAvailable(), isFalse);
    });
  });

  group('the permission', () {
    testWidgets('Bluetooth is never asked for', (tester) async {
      final (phone, _) = await _ready(tester);
      expect(phone.arguments['initialize'], containsPair('noBluetooth', true));
    });

    testWidgets('refused, or no recogniser after all', (tester) async {
      final phone = _Phone(tester)..allowed = false;
      var dictation = SystemDictation(speech: SpeechToText.withMethodChannel());
      expect(await dictation.prepare(), DictationAccess.refused);

      phone.notAvailable = true;
      dictation = SystemDictation(speech: SpeechToText.withMethodChannel());
      expect(await dictation.prepare(), DictationAccess.unavailable);
    });

    testWidgets('whether it was already given is asked without a dialog', (tester) async {
      final phone = _Phone(tester)..permission = false;
      final dictation = SystemDictation(speech: SpeechToText.withMethodChannel());
      expect(await dictation.hasPermission(), isFalse);
      expect(phone.calls, ['has_permission']);
    });
  });

  group('a dictation', () {
    testWidgets('a silence ends it: the final words, once, and the microphone is let go',
        (tester) async {
      final (phone, dictation) = await _ready(tester);
      final listening = _Listening(dictation);
      await listening.start();
      expect(phone.arguments['listen'], containsPair('localeId', 'it-IT'));
      // The plugin's own recognition, wherever the phone does it.
      expect(phone.arguments['listen'], containsPair('onDevice', false));

      await phone.status('listening');
      await phone.words('mangia');
      await phone.words('mangia poco');
      await phone.words('mangia poco da ieri', last: true);
      expect(listening.done.single.text, 'mangia poco da ieri');
      expect(listening.done.single.problem, isNull);
      expect(phone.calls.last, 'cancel');

      await phone.status('notListening');
      await phone.status('done');
      await tester.pump(SystemDictation.longest);
      expect(listening.done, hasLength(1));
    });

    testWidgets('stopped by the owner before any word arrived: the words still come',
        (tester) async {
      final (phone, dictation) = await _ready(tester);
      final listening = _Listening(dictation);
      await listening.start();
      await phone.status('listening');

      await dictation.stop();
      expect(listening.closed, 1);
      expect(phone.calls, contains('stop'));
      // Android says it is done before it hands over the words.
      await phone.status('notListening');
      await phone.status('doneNoResult');
      expect(listening.done, isEmpty);
      await phone.words('tossisce', last: true);

      expect(listening.closed, 1);
      expect(listening.done.single.text, 'tossisce');
    });

    testWidgets('a recognition that never marks its words as final (a browser)', (tester) async {
      final (phone, dictation) = await _ready(tester);
      final listening = _Listening(dictation);
      await listening.start();
      await phone.status('listening');
      await phone.words('zoppica');
      await phone.status('notListening');
      expect(listening.closed, 1);

      await tester.pump(SystemDictation.settle);
      expect(listening.done.single.text, 'zoppica');
    });

    testWidgets('nothing heard: told once, after a moment', (tester) async {
      final (phone, dictation) = await _ready(tester);
      final listening = _Listening(dictation);
      await listening.start();
      await phone.status('listening');
      await dictation.stop();
      await tester.pump(SystemDictation.settle);

      expect(listening.done.single.text, isEmpty);
      expect(listening.done.single.problem, DictationProblem.nothingHeard);
    });

    for (final (code, problem) in [
      ('error_no_match', DictationProblem.nothingHeard),
      ('error_speech_timeout', DictationProblem.nothingHeard),
      ('error_network', DictationProblem.nothingHeard),
      ('error_permission', DictationProblem.permission),
      ('not-allowed', DictationProblem.permission),
      ('error_busy', DictationProblem.microphone),
    ]) {
      testWidgets('$code is ${problem.name}', (tester) async {
        final (phone, dictation) = await _ready(tester);
        final listening = _Listening(dictation);
        await listening.start();
        await phone.status('listening');
        // Android closes first, and says why after.
        await phone.status('notListening');
        await phone.status('doneNoResult');
        await phone.error(code);

        expect(listening.done.single.problem, problem);
      });
    }

    testWidgets('what was heard before an error is not thrown away', (tester) async {
      final (phone, dictation) = await _ready(tester);
      final listening = _Listening(dictation);
      await listening.start();
      await phone.status('listening');
      await phone.words('ha mangiato un calzino');
      await phone.error('error_network');

      expect(listening.done.single.text, 'ha mangiato un calzino');
    });

    testWidgets('the microphone closes by itself after a long silence', (tester) async {
      final (phone, dictation) = await _ready(tester);
      final listening = _Listening(dictation);
      await listening.start();
      await phone.status('listening');
      await tester.pump(const Duration(seconds: 6));
      await phone.words('beve molto');
      await tester.pump(const Duration(seconds: 6));
      expect(phone.calls, isNot(contains('stop')));

      await tester.pump(const Duration(seconds: 2));
      expect(phone.calls, contains('stop'));
      await tester.pump(SystemDictation.settle);
      expect(listening.done.single.text, 'beve molto');
    });

    testWidgets('it is never open longer than two minutes', (tester) async {
      final (phone, dictation) = await _ready(tester);
      await _Listening(dictation).start();
      await phone.status('listening');
      for (var spoken = 0; spoken < 24; spoken++) {
        expect(phone.calls, isNot(contains('stop')));
        await tester.pump(const Duration(seconds: 5));
        await phone.words('parola $spoken');
      }
      expect(phone.calls, contains('stop'));
      await tester.pump(SystemDictation.settle);
    });

    testWidgets('cancelled (page left, signed out): nothing comes after', (tester) async {
      final (phone, dictation) = await _ready(tester);
      final listening = _Listening(dictation);
      await listening.start();
      await phone.status('listening');
      await phone.words('segreto');
      await dictation.cancel();
      expect(phone.calls.last, 'cancel');

      await phone.status('notListening');
      await phone.words('segreto', last: true);
      await tester.pump(SystemDictation.longest);
      expect(listening.closed, 0);
      expect(listening.done, isEmpty);
    });

    testWidgets('one that cannot start says so and leaves nothing behind', (tester) async {
      final (phone, dictation) = await _ready(tester);
      phone.listenError = true;
      final listening = _Listening(dictation);
      await expectLater(listening.start(), throwsA(anything));

      await tester.pump(SystemDictation.longest);
      expect(listening.done, isEmpty);
    });

    testWidgets('the next one has its own answer (the plugin keeps the first listeners)',
        (tester) async {
      final (phone, dictation) = await _ready(tester);
      final first = _Listening(dictation);
      await first.start();
      await phone.status('listening');
      await phone.words('prima', last: true);

      final second = _Listening(dictation);
      await second.start(languageTag: 'de-CH');
      expect(phone.arguments['listen'], containsPair('localeId', 'de-CH'));
      await phone.status('listening');
      await phone.status('notListening');
      await phone.error('error_no_match');

      expect(first.done.single.text, 'prima');
      expect(second.done.single.problem, DictationProblem.nothingHeard);
    });
  });

  test('the manifest: the microphone and the recognition service, no Bluetooth', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest,
        contains('<uses-permission android:name="android.permission.RECORD_AUDIO" />'));
    expect(manifest, contains('<action android:name="android.speech.RecognitionService" />'));
    expect(manifest, isNot(contains('android.permission.BLUETOOTH')));
    // The plugin of the old recorder is gone, and with it the audio sent to the server.
    expect(File('pubspec.yaml').readAsStringSync(), isNot(contains('  record:')));
  });
}
