import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// What came of asking for the microphone.
enum DictationAccess { ready, refused, unavailable, failed }

/// Why a dictation gave no text.
enum DictationProblem { nothingHeard, permission, microphone }

/// The end of a dictation: the words heard, or (empty) why there are none.
class DictationResult {
  const DictationResult({this.text = '', this.problem});

  final String text;
  final DictationProblem? problem;
}

/// Turning the owner's voice into text. The recognition belongs to the phone (Android,
/// iPhone) or to the browser: Quokka gets the text and never the audio, and the app itself
/// records and sends nothing (owner decision of 25 November 2026).
abstract class Dictation {
  /// Whether this phone or browser can recognise speech. Asks the owner nothing.
  Future<bool> isAvailable();

  /// Whether the microphone was already allowed; null where that is not known (a browser
  /// asks by itself when the listening starts).
  Future<bool?> hasPermission();

  /// Gets the recognition ready. Shows the system's permission dialog when it is needed.
  Future<DictationAccess> prepare();

  /// Starts listening in [languageTag] (`it-IT`). [onClosed]: the microphone closed and the
  /// last words are on their way. [onDone], once: the end. Throws when it cannot start.
  Future<void> start({
    required String languageTag,
    required VoidCallback onClosed,
    required ValueChanged<DictationResult> onDone,
  });

  /// Closes the microphone; what was heard arrives with `onDone`.
  Future<void> stop();

  /// Closes the microphone and drops what was heard: no callback comes after it.
  Future<void> cancel();
}

class SystemDictation implements Dictation {
  SystemDictation({SpeechToText? speech}) : _speech = speech ?? SpeechToText();

  static final SystemDictation instance = SystemDictation();

  static const _channel = MethodChannel('vetapp/app_navigation');

  /// With no new words for this long the microphone closes by itself (Android usually does
  /// it before; a browser never does).
  @visibleForTesting
  static const idle = Duration(seconds: 8);

  /// The microphone never stays open longer than this.
  @visibleForTesting
  static const longest = Duration(minutes: 2);

  /// Once the microphone is closed, the last words arrive within this time or not at all.
  @visibleForTesting
  static const settle = Duration(milliseconds: 2500);

  final SpeechToText _speech;
  _Session? _session;

  @override
  Future<bool> isAvailable() async {
    try {
      // In a browser this says whether it can recognise speech; it does not prompt.
      if (kIsWeb) return await _speech.hasPermission;
      return switch (defaultTargetPlatform) {
        // The plugin only tells after the microphone was granted: Android is asked directly.
        TargetPlatform.android =>
          await _channel.invokeMethod<bool>('speechRecognitionAvailable') ?? false,
        TargetPlatform.iOS => true,
        _ => false,
      };
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool?> hasPermission() async => kIsWeb ? null : await _speech.hasPermission;

  @override
  Future<DictationAccess> prepare() async {
    try {
      final ready = await _speech.initialize(options: [
        // Without this the plugin also asks for Bluetooth, which Quokka does not use.
        SpeechToText.androidNoBluetooth,
        // Chrome on Android repeats the phrases when they are put together.
        if (kIsWeb && defaultTargetPlatform == TargetPlatform.android)
          SpeechToText.webDoNotAggregate,
      ]);
      return ready ? DictationAccess.ready : DictationAccess.refused;
    } on PlatformException catch (error) {
      return error.code == 'recognizerNotAvailable'
          ? DictationAccess.unavailable
          : DictationAccess.failed;
    } catch (_) {
      return DictationAccess.failed;
    }
  }

  @override
  Future<void> start({
    required String languageTag,
    required VoidCallback onClosed,
    required ValueChanged<DictationResult> onDone,
  }) async {
    await cancel();
    final session = _Session(onClosed, onDone);
    _session = session;
    // The plugin is one object for the whole app and takes its listeners only the first time
    // it is initialised: they are set again for each dictation.
    _speech.statusListener = (status) => _onStatus(session, status);
    _speech.errorListener = (error) => _onError(session, error);
    session.longest = Timer(longest, stop);
    // In a browser the owner may still be answering its permission question.
    if (!kIsWeb) _armIdle(session);
    try {
      await _speech.listen(
        onResult: (result) => _onResult(session, result),
        listenOptions: SpeechListenOptions(
          localeId: languageTag,
          listenMode: ListenMode.dictation,
          autoPunctuation: true,
        ),
      );
    } catch (_) {
      session.drop();
      if (identical(_session, session)) _session = null;
      rethrow;
    }
    // Cancelled while it was starting (the page was left): the microphone must not stay open.
    if (session.done && _session == null) await _release();
  }

  @override
  Future<void> stop() async {
    final session = _session;
    if (session == null || session.done) return;
    _close(session);
    try {
      await _speech.stop();
    } catch (_) {
      // The words heard so far arrive when the settling time is over.
    }
  }

  @override
  Future<void> cancel() async {
    _session?.drop();
    _session = null;
    await _release();
  }

  /// The plugin's own microphone. Also after a natural end: Android keeps its "listening" flag
  /// a moment after the last words, and the next dictation would not start.
  Future<void> _release() async {
    try {
      await _speech.cancel();
    } catch (_) {}
  }

  void _onStatus(_Session session, String status) {
    if (session.done) return;
    if (status == SpeechToText.listeningStatus) {
      if (!session.closed) _armIdle(session);
      return;
    }
    // "notListening" or "done". Neither is the end: Android's final words come after, and
    // those of a browser are never marked as final.
    _close(session);
  }

  void _onResult(_Session session, SpeechRecognitionResult result) {
    if (session.done) return;
    final words = result.recognizedWords.trim();
    if (words.isNotEmpty) session.words = words;
    if (result.finalResult) {
      _finish(session, DictationProblem.nothingHeard);
    } else if (!session.closed) {
      _armIdle(session);
    }
  }

  void _onError(_Session session, SpeechRecognitionError error) {
    if (session.done) return;
    _finish(
      session,
      switch (error.errorMsg) {
        'error_permission' || 'not-allowed' || 'service-not-allowed' =>
          DictationProblem.permission,
        'error_audio_error' || 'error_busy' || 'error_client' || 'audio-capture' =>
          DictationProblem.microphone,
        _ => DictationProblem.nothingHeard,
      },
    );
  }

  void _armIdle(_Session session) {
    session.idle?.cancel();
    session.idle = Timer(idle, stop);
  }

  void _close(_Session session) {
    if (session.closed) return;
    session.closed = true;
    session.idle?.cancel();
    session.longest?.cancel();
    session.settle = Timer(settle, () => _finish(session, DictationProblem.nothingHeard));
    session.onClosed();
  }

  /// The end, once. [problem] counts only when no word was heard: what was heard before an
  /// error is never thrown away.
  void _finish(_Session session, DictationProblem problem) {
    if (session.done) return;
    session.drop();
    if (identical(_session, session)) _session = null;
    unawaited(_release());
    session.onDone(
      session.words.isEmpty
          ? DictationResult(problem: problem)
          : DictationResult(text: session.words),
    );
  }
}

class _Session {
  _Session(this.onClosed, this.onDone);

  final VoidCallback onClosed;
  final ValueChanged<DictationResult> onDone;

  Timer? idle;
  Timer? longest;
  Timer? settle;
  String words = '';
  bool closed = false;
  bool done = false;

  void drop() {
    done = true;
    idle?.cancel();
    longest?.cancel();
    settle?.cancel();
  }
}
