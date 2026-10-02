import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/walk_session.dart';
import 'dog_walks_repository.dart';

/// Persists the in-progress walk to disk periodically so it survives the
/// app process being killed mid-walk (owner report, 2026-09-29: navigating
/// away lost the walk entirely - this is the other half of that fix, the
/// part ActiveWalkController's app-lifetime singleton alone can't cover).
/// Same shared_preferences technique as LocationPreferenceStore, reusing
/// DogWalksRepository's row shape rather than inventing a second one.
class ActiveWalkRecoveryStore {
  const ActiveWalkRecoveryStore();

  static const _storageKey = 'vet_app.active_walk_recovery';

  Future<void> save(WalkSession walk) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
          _storageKey, jsonEncode(DogWalksRepository.toRow(walk)));
    } catch (_) {
      // Best-effort: losing the periodic snapshot just means a kill mid-walk
      // recovers from an older point, not a crash.
    }
  }

  Future<void> clear() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_storageKey);
    } catch (_) {
      // Nothing to do differently on failure - see save() above.
    }
  }

  /// Null when there is nothing to recover, or the saved snapshot no longer
  /// looks like an in-progress walk (already ended by another path before
  /// the app was killed, or corrupt).
  Future<WalkSession?> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_storageKey);
      if (raw == null || raw.isEmpty) return null;

      final walk =
          DogWalksRepository.fromRow(jsonDecode(raw) as Map<String, dynamic>);
      if (walk == null || walk.status != WalkStatus.inProgress) return null;
      return walk;
    } catch (_) {
      return null;
    }
  }
}
