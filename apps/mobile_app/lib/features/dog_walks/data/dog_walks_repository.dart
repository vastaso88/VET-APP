import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/router/app_router.dart';
import '../../../../shared/config/app_runtime_config_loader.dart';
import '../../location/domain/coordinates.dart';
import '../domain/walk_retention.dart';
import '../domain/walk_session.dart';

/// Surfaces a failed Supabase write instead of only swallowing it (owner
/// report, 2026-10-01: a silently-failed upsert/delete looked like the app
/// just not responding to the tap). Uses AppRouter's global
/// scaffoldMessengerKey rather than threading a BuildContext through every
/// repository method - same idea as its navigatorKey.
void _notifySyncFailure(String action, Object error) {
  debugPrint('DogWalksRepository: $action failed against Supabase: $error');
  AppRouter.scaffoldMessengerKey.currentState?.showSnackBar(
    const SnackBar(content: Text('Sincronizzazione non riuscita: modifica salvata solo sul telefono')),
  );
}

/// Pure merge logic behind `DogWalksRepository.loadWalks` - pulled out so
/// the "a pending local write/delete must win over stale remote" behavior
/// is testable without a real or fake Supabase client (2026-10-01).
List<WalkSession> mergeRemoteAndLocalWalks({
  required List<WalkSession> remote,
  required List<WalkSession> local,
  required Map<String, WalkSession> localById,
  required Set<String> unsyncedIds,
  required Set<String> pendingDeleteIds,
}) {
  final merged = <String, WalkSession>{};
  for (final walk in remote) {
    if (pendingDeleteIds.contains(walk.id)) {
      continue;
    }
    final pendingLocal = unsyncedIds.contains(walk.id) ? localById[walk.id] : null;
    merged[walk.id] = pendingLocal ?? walk;
  }
  for (final walk in local) {
    merged.putIfAbsent(walk.id, () => walk);
  }
  return merged.values.toList();
}

/// Same shape as RemindersRepository: an optional Supabase client, a
/// session-lifetime local list as demo/no-backend fallback, defensive
/// row parsing that skips anything malformed rather than crashing.
class DogWalksRepository {
  DogWalksRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  static final List<WalkSession> _localWalks = List<WalkSession>.of(_seedWalks);

  /// Ids whose most recent `saveWalk` upsert failed against Supabase -
  /// until it succeeds, [loadWalks] must trust the local copy over remote
  /// for that id, even though remote already has *a* row there.
  static final Set<String> _unsyncedIds = {};

  /// Ids deleted locally whose Supabase delete failed - until it succeeds,
  /// [loadWalks] must not let the still-present remote row resurrect them.
  static final Set<String> _pendingDeleteIds = {};

  /// Remote is the source of truth when configured, but a write can fail
  /// silently (network blip, stale auth token, or - as found 2026-10-01 - a
  /// column the live table doesn't have yet because a migration hadn't run)
  /// and `saveWalk`/`deleteWalk` apply best-effort rather than surfacing
  /// that to the owner. Blindly trusting whatever remote last returned for
  /// an id both features had already touched turned every such failure into
  /// a silent revert: a "removed favorite" or a "deleted walk" would come
  /// straight back on the next reload because remote still had the old row
  /// (owner report, 2026-10-01). [_unsyncedIds]/[_pendingDeleteIds] are what
  /// actually fix that - a local write/delete stays authoritative for its
  /// id until it's confirmed synced, no matter what remote says in the
  /// meantime. A walk local has never heard of stays exactly as remote
  /// reports it; a local-only walk remote hasn't seen yet (offline, or
  /// remote not configured) is added back in (owner report, 2026-09-29).
  Future<List<WalkSession>> loadWalks(String ownerId) async {
    final remote = await _tryLoadRemoteWalks(ownerId);
    final local = _localWalks.where((walk) => walk.ownerId == ownerId).toList();
    final localById = {for (final walk in local) walk.id: walk};

    final merged = mergeRemoteAndLocalWalks(
      remote: remote,
      local: local,
      localById: localById,
      unsyncedIds: _unsyncedIds,
      pendingDeleteIds: _pendingDeleteIds,
    );
    return List<WalkSession>.unmodifiable(merged);
  }

  Future<void> saveWalk(WalkSession walk) async {
    final index = _localWalks.indexWhere((item) => item.id == walk.id);
    if (index == -1) {
      _localWalks.insert(0, walk);
    } else {
      _localWalks[index] = walk;
    }
    _pendingDeleteIds.remove(walk.id);

    final client = _resolveClient();
    if (client == null) {
      // No remote configured at all - the local copy above is the only
      // copy that will ever exist, so there's nothing to be "unsynced"
      // relative to.
      _unsyncedIds.remove(walk.id);
      return;
    }

    try {
      await client.from('dog_walks').upsert(toRow(walk));
      _unsyncedIds.remove(walk.id);
    } catch (error) {
      // The local list above already applied for this session; loadWalks
      // won't let a stale remote row overwrite it until this succeeds.
      _unsyncedIds.add(walk.id);
      _notifySyncFailure('saving walk ${walk.id}', error);
    }
  }

  /// Removes a walk entirely - the trash button on a history card (owner
  /// request, 2026-09-30), and the one-time cleanup of already-saved
  /// zero-distance walks (_WalksTabState._load() in pet_detail_page.dart).
  Future<void> deleteWalk(String ownerId, String walkId) async {
    _localWalks.removeWhere((walk) => walk.id == walkId && walk.ownerId == ownerId);
    _unsyncedIds.remove(walkId);

    final client = _resolveClient();
    if (client == null) {
      _pendingDeleteIds.remove(walkId);
      return;
    }

    try {
      await client.from('dog_walks').delete().eq('id', walkId).eq('owner_id', ownerId);
      _pendingDeleteIds.remove(walkId);
    } catch (error) {
      // Same posture as saveWalk: loadWalks hides this id out of remote
      // until the delete actually goes through.
      _pendingDeleteIds.add(walkId);
      _notifySyncFailure('deleting walk $walkId', error);
    }
  }

  /// Strips the `route` from any completed walk for this pet that falls
  /// outside the retention set (see walk_retention.dart) - called once a
  /// walk finishes, since that's the only time the retained set can change.
  Future<void> pruneRoutesOutsideRetention(String ownerId, String petId) async {
    final walks = (await loadWalks(ownerId))
        .where((walk) =>
            walk.petId == petId && walk.status == WalkStatus.completed)
        .toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

    final retainedIds = retainedRouteWalkIds(walks);
    for (final walk in walks) {
      if (walk.route.isNotEmpty && !retainedIds.contains(walk.id)) {
        await saveWalk(walk.copyWith(route: const []));
      }
    }
  }

  Future<List<WalkSession>> _tryLoadRemoteWalks(String ownerId) async {
    final client = _resolveClient();
    if (client == null) {
      return const [];
    }

    try {
      final response =
          await client.from('dog_walks').select('*').eq('owner_id', ownerId);
      final rows = response as List<dynamic>;
      final walks = <WalkSession>[];
      for (final row in rows) {
        final walk = fromRow(row as Map<String, dynamic>);
        if (walk != null) {
          walks.add(walk);
        }
      }
      return walks;
    } catch (_) {
      return const [];
    }
  }

  /// Public (and static - neither reads instance state) so
  /// active_walk_recovery_store.dart can persist/restore the same shape to
  /// shared_preferences without duplicating this mapping.
  static Map<String, dynamic> toRow(WalkSession walk) {
    return {
      'id': walk.id,
      'owner_id': walk.ownerId,
      'pet_id': walk.petId,
      'status': _statusToString(walk.status),
      'started_at': walk.startedAt.toIso8601String(),
      'ended_at': walk.endedAt?.toIso8601String(),
      'distance_meters': walk.distanceMeters,
      'duration_seconds': walk.durationSeconds,
      'step_count_estimate': walk.stepCountEstimate,
      'is_favorite': walk.isFavorite,
      'is_paused': walk.isPaused,
      'paused_at': walk.pausedAt?.toIso8601String(),
      'paused_seconds': walk.pausedSeconds,
      'route': walk.route
          .map(
            (point) => {
              'coordinates': {
                'latitude': point.coordinates.latitude,
                'longitude': point.coordinates.longitude,
              },
              'recorded_at': point.recordedAt.toIso8601String(),
              'accuracy_meters': point.accuracyMeters,
              'starts_new_segment': point.startsNewSegment,
            },
          )
          .toList(),
    };
  }

  static WalkSession? fromRow(Map<String, dynamic> row) {
    final startedAt = DateTime.tryParse((row['started_at'] ?? '').toString());
    final status = _statusFromString(row['status'] as String?);
    if (startedAt == null || status == null) {
      return null;
    }

    final rawRoute = (row['route'] as List<dynamic>?) ?? const [];
    final route = <RoutePoint>[];
    for (final rawPoint in rawRoute) {
      final point = _parseRoutePoint(rawPoint as Map<String, dynamic>);
      if (point != null) {
        route.add(point);
      }
    }

    return WalkSession(
      id: (row['id'] ?? '').toString(),
      ownerId: (row['owner_id'] ?? '').toString(),
      petId: (row['pet_id'] ?? '').toString(),
      status: status,
      startedAt: startedAt,
      endedAt: DateTime.tryParse((row['ended_at'] ?? '').toString()),
      distanceMeters: (row['distance_meters'] as num?)?.toDouble() ?? 0,
      durationSeconds: (row['duration_seconds'] as num?)?.toInt(),
      stepCountEstimate: (row['step_count_estimate'] as num?)?.toInt(),
      isFavorite: row['is_favorite'] as bool? ?? false,
      isPaused: row['is_paused'] as bool? ?? false,
      pausedAt: DateTime.tryParse((row['paused_at'] ?? '').toString()),
      pausedSeconds: (row['paused_seconds'] as num?)?.toInt() ?? 0,
      route: route,
    );
  }

  static RoutePoint? _parseRoutePoint(Map<String, dynamic> raw) {
    final coordinatesJson = raw['coordinates'] as Map<String, dynamic>?;
    final recordedAt = DateTime.tryParse((raw['recorded_at'] ?? '').toString());
    final latitude = (coordinatesJson?['latitude'] as num?)?.toDouble();
    final longitude = (coordinatesJson?['longitude'] as num?)?.toDouble();
    if (recordedAt == null || latitude == null || longitude == null) {
      return null;
    }
    return RoutePoint(
      coordinates: Coordinates(latitude: latitude, longitude: longitude),
      recordedAt: recordedAt,
      accuracyMeters: (raw['accuracy_meters'] as num?)?.toDouble(),
      startsNewSegment: raw['starts_new_segment'] as bool? ?? false,
    );
  }

  static WalkStatus? _statusFromString(String? value) {
    switch (value) {
      case 'in_progress':
        return WalkStatus.inProgress;
      case 'completed':
        return WalkStatus.completed;
      case 'discarded':
        return WalkStatus.discarded;
      default:
        return null;
    }
  }

  static String _statusToString(WalkStatus status) {
    switch (status) {
      case WalkStatus.inProgress:
        return 'in_progress';
      case WalkStatus.completed:
        return 'completed';
      case WalkStatus.discarded:
        return 'discarded';
    }
  }

  SupabaseClient? _resolveClient() {
    if (_client != null) {
      return _client;
    }

    final config = const AppRuntimeConfigLoader().load();
    if (!config.hasSupabaseCredentials) {
      return null;
    }

    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  // Mirrors demo-pet-moka from packages/infrastructure/persistence/demo_seed.py
  // so the maps demo route (see app/preview/maps_demo_page.dart) has a
  // completed walk with a real route to draw as a polyline.
  static final List<WalkSession> _seedWalks = [
    WalkSession(
      id: 'demo-walk-moka-sempione',
      ownerId: 'demo-user',
      petId: 'demo-pet-moka',
      status: WalkStatus.completed,
      startedAt: DateTime.now().subtract(const Duration(days: 1, hours: 1)),
      endedAt: DateTime.now().subtract(const Duration(days: 1)),
      distanceMeters: 850,
      durationSeconds: 1800,
      stepCountEstimate: 1133,
      route: [
        RoutePoint(
          coordinates: const Coordinates(latitude: 45.4707, longitude: 9.1791),
          recordedAt:
              DateTime.now().subtract(const Duration(days: 1, hours: 1)),
        ),
        RoutePoint(
          coordinates: const Coordinates(latitude: 45.4718, longitude: 9.1820),
          recordedAt:
              DateTime.now().subtract(const Duration(days: 1, minutes: 45)),
        ),
        RoutePoint(
          coordinates: const Coordinates(latitude: 45.4730, longitude: 9.1860),
          recordedAt:
              DateTime.now().subtract(const Duration(days: 1, minutes: 30)),
        ),
        RoutePoint(
          coordinates: const Coordinates(latitude: 45.4718, longitude: 9.1875),
          recordedAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ],
    ),
  ];
}
