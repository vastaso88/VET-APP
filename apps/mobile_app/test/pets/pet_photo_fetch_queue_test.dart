import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/pets/data/pet_photo_fetch_queue.dart';

void main() {
  group('KeyedFetchQueue', () {
    test('never runs more than maxConcurrent jobs at once', () async {
      final queue = KeyedFetchQueue<int>(maxConcurrent: 2);
      final gates = <Completer<int>>[];
      var peak = 0;

      final results = [
        for (var i = 0; i < 5; i++)
          queue.run('k$i', () {
            final gate = Completer<int>();
            gates.add(gate);
            peak = peak < queue.running ? queue.running : peak;
            return gate.future;
          }),
      ];
      await Future<void>.delayed(Duration.zero);
      expect(queue.running, 2);
      expect(queue.waiting, 3);

      // Finish jobs one at a time until all five ran.
      var finished = 0;
      while (finished < 5) {
        await Future<void>.delayed(Duration.zero);
        gates[finished].complete(finished);
        finished++;
        await Future<void>.delayed(Duration.zero);
      }
      // Every job ran exactly once (the waiting ones start newest first, so the
      // values come back in start order, not key order).
      expect(await Future.wait(results), unorderedEquals([0, 1, 2, 3, 4]));
      expect(peak, lessThanOrEqualTo(2));
    });

    test('asking twice for the same key shares one job', () async {
      final queue = KeyedFetchQueue<String>();
      var started = 0;
      final gate = Completer<String>();

      final first = queue.run('a', () {
        started++;
        return gate.future;
      });
      final second = queue.run('a', () {
        started++;
        return Future.value('other');
      });
      gate.complete('photo');

      expect(await first, 'photo');
      expect(await second, 'photo');
      expect(started, 1);
    });

    test('a finished key can be fetched again', () async {
      final queue = KeyedFetchQueue<int>();
      var calls = 0;

      expect(await queue.run('a', () async => ++calls), 1);
      expect(await queue.run('a', () async => ++calls), 2);
    });

    test('waiting jobs start newest first (what was scrolled to last is on screen)', () async {
      final queue = KeyedFetchQueue<int>(maxConcurrent: 1);
      final order = <String>[];
      final firstGate = Completer<int>();

      final all = [
        queue.run('first', () {
          order.add('first');
          return firstGate.future;
        }),
        for (final key in ['old', 'middle', 'newest'])
          queue.run(key, () async {
            order.add(key);
            return 0;
          }),
      ];
      firstGate.complete(0);
      await Future.wait(all);

      expect(order, ['first', 'newest', 'middle', 'old']);
    });

    test('a failing job answers null and the next ask tries again', () async {
      final queue = KeyedFetchQueue<int>();
      var calls = 0;

      expect(
        await queue.run('a', () async {
          calls++;
          throw StateError('offline');
        }),
        isNull,
      );
      expect(await queue.run('a', () async => ++calls), 2);
      expect(queue.running, 0);
    });
  });

  group('LruCache', () {
    test('forgets the least recently used entry past its capacity', () {
      final cache = LruCache<int>(2)
        ..put('a', 1)
        ..put('b', 2);
      expect(cache.get('a'), 1); // a is now the most recent
      cache.put('c', 3);

      expect(cache.get('b'), isNull);
      expect(cache.get('a'), 1);
      expect(cache.get('c'), 3);
      expect(cache.length, 2);
    });

    test('removeWhere and clear drop what they cover', () {
      final cache = LruCache<int>(5)
        ..put('owner/pet1/a', 1)
        ..put('owner/pet1/b', 2)
        ..put('owner/pet2/c', 3);

      cache.removeWhere((key) => key.startsWith('owner/pet1/'));
      expect(cache.length, 1);
      cache.clear();
      expect(cache.length, 0);
    });
  });
}
