import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Quick start: nothing that waits on the network may run before `runApp`,
/// or a slow connection keeps the owner on a blank screen (the account
/// language sync alone can wait twice 5 s; the SDK's logout request has no
/// time limit at all).
///
/// Every `await` before the first frame must be one of these local steps. A
/// new one goes here only after checking it never waits on the network.
const _localStepsBeforeFirstFrame = {
  'CrashReporting.instance.initialize', // saved consent + SDK start, no request
  'UnitSettingsStore.instance.ensureLoaded',
  'LanguageStore.instance.ensureLoaded', // device preference only
  'SystemChrome.setPreferredOrientations',
  'Supabase.initialize', // restores the session from disk
  'RememberMeStore.read',
  // Test network only (docs/collaudo): null in every normal build, so nothing
  // waits; only lib/main_collaudo.dart passes it (automatic sign-in of a
  // synthetic account on the test twin).
  'afterSupabaseReady',
};

void main() {
  test('bootstrap awaits only local steps before the first frame', () {
    final source = File('lib/app/bootstrap.dart').readAsStringSync();
    final beforeFirstFrame = source.substring(0, source.indexOf('runApp('));

    final awaited = RegExp(r'await\s+([\w.]+)')
        .allMatches(beforeFirstFrame)
        .map((match) => match.group(1)!)
        .toSet();

    expect(awaited.difference(_localStepsBeforeFirstFrame), isEmpty);
  });
}
