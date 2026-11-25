import 'package:flutter/foundation.dart';
import 'package:vet_app_mobile/features/chat/data/system_dictation.dart';

/// A phone's speech recognition driven by the test: no microphone, no plugin.
class FakeDictation implements Dictation {
  FakeDictation({
    this.available = true,
    this.permission = true,
    this.access = DictationAccess.ready,
    this.startError,
  });

  bool available;

  /// Null: not known, like in a browser.
  bool? permission;

  /// What the system answers when the microphone is asked for.
  DictationAccess access;
  Object? startError;

  bool prepared = false;
  bool cancelled = false;
  bool stopped = false;
  int starts = 0;
  String? languageTag;
  VoidCallback? _onClosed;
  ValueChanged<DictationResult>? _onDone;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool?> hasPermission() async => permission;

  @override
  Future<DictationAccess> prepare() async {
    prepared = true;
    return access;
  }

  @override
  Future<void> start({
    required String languageTag,
    required VoidCallback onClosed,
    required ValueChanged<DictationResult> onDone,
  }) async {
    if (startError != null) throw startError!;
    starts++;
    this.languageTag = languageTag;
    _onClosed = onClosed;
    _onDone = onDone;
  }

  @override
  Future<void> stop() async {
    stopped = true;
    _onClosed?.call();
  }

  @override
  Future<void> cancel() async => cancelled = true;

  /// The phone closes the microphone by itself (a silence).
  void close() => _onClosed?.call();

  void hear(String words) => _onDone?.call(DictationResult(text: words));

  void fail(DictationProblem problem) => _onDone?.call(DictationResult(problem: problem));
}
