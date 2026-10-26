import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// News reach the app only through our backend's GET /news: the client never
/// calls a news or RSS service itself (a re-merge once brought back Google
/// News through rss2json).
void main() {
  final sources = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList();

  test('no news or RSS host appears in the app code', () {
    for (final file in sources) {
      final text = file.readAsStringSync();
      for (final host in ['news.google.', 'rss2json', 'feeds.feedburner']) {
        expect(text, isNot(contains(host)), reason: '${file.path} mentions $host');
      }
    }
  });

  test('the backend repository is the only news repository', () {
    final implementations = <String>[];
    for (final file in sources) {
      final matches = RegExp(r'class (\w+)[^{]*\b(?:implements|extends) PetNewsRepository\b')
          .allMatches(file.readAsStringSync());
      implementations.addAll(matches.map((match) => match.group(1)!));
    }
    expect(implementations, ['BackendPetNewsRepository']);
  });
}
