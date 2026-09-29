import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/config/app_runtime_config_loader.dart';
import '../../location/domain/coordinates.dart';
import '../domain/walk_retention.dart';
import '../domain/walk_session.dart';

/// Same shape as RemindersRepository: an optional Supabase client, a
/// session-lifetime local list as demo/no-backend fallback, defensive
/// row parsing that skips anything malformed rather than crashing.
class DogWalksRepository {
  DogWalksRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  static final List<WalkSession> _localWalks = List<WalkSession>.of(_seedWalks);

  /// Remote is the source of truth when configured, but `saveWalk` swallows
  /// upsert failures as best-effort (network blip, momentarily stale auth
  /// token) - so a walk that just finished (or was just starred) can be
  /// missing from `remote` while still sitting correctly in `_localWalks`.
  /// Returning `remote` verbatim in that case silently dropped it from
  /// every list in the app (owner report, 2026-09-29: confirmed "save as
  /// favorite" then the walk vanished). Any local walk remote doesn't know
  /// about yet is added back in; walks present in both use the remote copy.
  Future<List<WalkSession>> loadWalks(String ownerId) async {
    final remote = await _tryLoadRemoteWalks(ownerId);
    final local = _localWalks.where((walk) => walk.ownerId == ownerId);
    if (remote.isEmpty) {
      return List<WalkSession>.unmodifiable(local);
    }

    final remoteIds = remote.map((walk) => walk.id).toSet();
    return List<WalkSession>.unmodifiable([
      ...remote,
      ...local.where((walk) => !remoteIds.contains(walk.id)),
    ]);
  }

  Future<void> saveWalk(WalkSession walk) async {
    final index = _localWalks.indexWhere((item) => item.id == walk.id);
    if (index == -1) {
      _localWalks.insert(0, walk);
    } else {
      _localWalks[index] = walk;
    }

    final client = _resolveClient();
    if (client == null) {
      return;
    }

    try {
      await client.from('dog_walks').upsert(toRow(walk));
    } catch (_) {
      // Best-effort: the local list above already applied for this session.
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
      'route': walk.route
          .map(
            (point) => {
              'coordinates': {
                'latitude': point.coordinates.latitude,
                'longitude': point.coordinates.longitude,
              },
              'recorded_at': point.recordedAt.toIso8601String(),
              'accuracy_meters': point.accuracyMeters,
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
