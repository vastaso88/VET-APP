import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Quick start: nothing that waits on the network may run before `runApp`,
/// or a slow connection keeps the owner on a blank screen (the account
/// language sync alone can wait twice 5 s).
void main() {
  test('bootstrap awaits no account round-trip before the first frame', () {
    final source = File('lib/app/bootstrap.dart').readAsStringSync();
    final beforeFirstFrame = source.substring(0, source.indexOf('runApp('));

    for (final networkCall in [
      'await LanguageStore.instance.syncAfterAuthentication',
      'await Supabase.instance.client.auth.getUser',
      'await Supabase.instance.client.auth.updateUser',
    ]) {
      expect(beforeFirstFrame, isNot(contains(networkCall)), reason: networkCall);
    }
  });
}
