import 'dart:async';
import 'dart:collection';

/// Runs keyed jobs with at most [maxConcurrent] in flight, and never twice for
/// the same key at the same time.
///
/// Why it exists (performance pass, 2026-11-16): a gallery day with 30 photos
/// used to start 30 downloads at once, and the same photo asked by an avatar, a
/// grid tile and a cover started three. On a phone connection that made every
/// tile as slow as the last one. Here a second request for a key already
/// running (or waiting) shares its result, and the waiting jobs start newest
/// first: what the owner scrolled to last is what is on screen now.
class KeyedFetchQueue<T> {
  KeyedFetchQueue({this.maxConcurrent = 6}) : assert(maxConcurrent > 0);

  final int maxConcurrent;

  final Map<String, Future<T?>> _shared = {};
  final List<_Waiting<T>> _waiting = [];
  int _running = 0;

  /// Jobs started and not yet finished.
  int get running => _running;

  /// Jobs accepted and not yet started.
  int get waiting => _waiting.length;

  /// Result of [job] for [key]. A failing job completes with null (a photo
  /// that cannot be fetched shows its placeholder, it never throws into a
  /// widget) and is forgotten, so the next ask tries again.
  Future<T?> run(String key, Future<T?> Function() job) {
    final shared = _shared[key];
    if (shared != null) return shared;
    final waiting = _Waiting<T>(key, job);
    _waiting.add(waiting);
    // A block body on purpose: an arrow returning `_shared.remove(key)` would
    // hand whenComplete this very future to wait on, and it would never finish.
    final result = waiting.completer.future.whenComplete(() {
      _shared.remove(key);
    });
    _shared[key] = result;
    _pump();
    return result;
  }

  void _pump() {
    while (_running < maxConcurrent && _waiting.isNotEmpty) {
      final next = _waiting.removeLast();
      _running++;
      unawaited(_start(next));
    }
  }

  Future<void> _start(_Waiting<T> waiting) async {
    try {
      waiting.completer.complete(await waiting.job());
    } catch (_) {
      waiting.completer.complete(null);
    } finally {
      _running--;
      _pump();
    }
  }
}

class _Waiting<T> {
  _Waiting(this.key, this.job);

  final String key;
  final Future<T?> Function() job;
  final Completer<T?> completer = Completer<T?>();
}

/// A map that forgets its least recently used entries past [maxEntries].
/// Keeps the photos held in memory bounded: the session cache used to keep
/// every full-size photo ever shown.
class LruCache<V> {
  LruCache(this.maxEntries) : assert(maxEntries > 0);

  final int maxEntries;
  final LinkedHashMap<String, V> _entries = LinkedHashMap<String, V>();

  int get length => _entries.length;

  V? get(String key) {
    final value = _entries.remove(key);
    if (value == null) return null;
    _entries[key] = value;
    return value;
  }

  void put(String key, V value) {
    _entries.remove(key);
    _entries[key] = value;
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  void remove(String key) => _entries.remove(key);

  void removeWhere(bool Function(String key) test) =>
      _entries.removeWhere((key, _) => test(key));

  void clear() => _entries.clear();
}
