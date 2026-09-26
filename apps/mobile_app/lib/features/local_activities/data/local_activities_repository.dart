import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/config/app_runtime_config_loader.dart';
import '../../location/domain/coordinates.dart';
import '../domain/local_activity.dart';

/// Same shape as RemindersRepository. The local seed mirrors
/// packages/infrastructure/persistence/demo_seed.py's `local_activities`
/// so a fresh demo (no Supabase configured) still shows something on the
/// map instead of an empty state.
class LocalActivitiesRepository {
  LocalActivitiesRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  static final List<LocalActivity> _localActivities = List<LocalActivity>.of(_seedActivities);

  Future<List<LocalActivity>> loadActiveActivities() async {
    final remote = await _tryLoadRemoteActivities();
    if (remote.isNotEmpty) {
      return remote;
    }
    return List<LocalActivity>.unmodifiable(
      _localActivities.where((activity) => activity.status == LocalActivityStatus.active),
    );
  }

  Future<void> saveActivity(LocalActivity activity) async {
    final index = _localActivities.indexWhere((item) => item.id == activity.id);
    if (index == -1) {
      _localActivities.insert(0, activity);
    } else {
      _localActivities[index] = activity;
    }

    final client = _resolveClient();
    if (client == null) {
      return;
    }

    try {
      await client.from('local_activities').upsert(_toRow(activity));
    } catch (_) {
      // Best-effort: the local list above already applied for this session.
    }
  }

  Future<List<LocalActivity>> _tryLoadRemoteActivities() async {
    final client = _resolveClient();
    if (client == null) {
      return const [];
    }

    try {
      final response = await client.from('local_activities').select('*').eq('status', 'active');
      final rows = response as List<dynamic>;
      final activities = <LocalActivity>[];
      for (final row in rows) {
        final activity = _parseRow(row as Map<String, dynamic>);
        if (activity != null) {
          activities.add(activity);
        }
      }
      return activities;
    } catch (_) {
      return const [];
    }
  }

  Map<String, dynamic> _toRow(LocalActivity activity) {
    return {
      'id': activity.id,
      'kind': activity.kind == LocalActivityKind.event ? 'event' : 'service',
      'title': activity.title,
      'description': activity.description,
      'category': activity.category,
      'latitude': activity.location.latitude,
      'longitude': activity.location.longitude,
      'address_label': activity.addressLabel,
      'starts_at': activity.startsAt?.toIso8601String(),
      'ends_at': activity.endsAt?.toIso8601String(),
      'source': activity.source == LocalActivitySource.seeded ? 'seeded' : 'user_submitted',
      'submitted_by_owner_id': activity.submittedByOwnerId,
      'status': activity.status == LocalActivityStatus.removed ? 'removed' : 'active',
      'report_count': activity.reportCount,
    };
  }

  LocalActivity? _parseRow(Map<String, dynamic> row) {
    final latitude = (row['latitude'] as num?)?.toDouble();
    final longitude = (row['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) {
      return null;
    }

    return LocalActivity(
      id: (row['id'] ?? '').toString(),
      kind: row['kind'] == 'service' ? LocalActivityKind.service : LocalActivityKind.event,
      title: (row['title'] ?? '').toString(),
      description: row['description'] as String?,
      category: row['category'] as String?,
      location: Coordinates(latitude: latitude, longitude: longitude),
      addressLabel: row['address_label'] as String?,
      startsAt: DateTime.tryParse((row['starts_at'] ?? '').toString()),
      endsAt: DateTime.tryParse((row['ends_at'] ?? '').toString()),
      source: row['source'] == 'seeded' ? LocalActivitySource.seeded : LocalActivitySource.userSubmitted,
      submittedByOwnerId: row['submitted_by_owner_id'] as String?,
      status: row['status'] == 'removed' ? LocalActivityStatus.removed : LocalActivityStatus.active,
      reportCount: (row['report_count'] as num?)?.toInt() ?? 0,
    );
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

  // "event" entries need a startsAt - without one they're indistinguishable
  // from a standing "service" and never show up under "In programma"
  // (apps/mobile_app/lib/features/local_events/presentation/pages/local_events_page.dart
  // splits on startsAt == null). Computed relative to now, not a fixed
  // date, so the demo data stays "upcoming" whenever this runs.
  static final List<LocalActivity> _seedActivities = [
    LocalActivity(
      id: 'demo-activity-fiera-cinofila',
      kind: LocalActivityKind.event,
      title: 'Fiera cinofila regionale',
      category: 'fiera',
      location: const Coordinates(latitude: 45.4718, longitude: 9.1875),
      addressLabel: 'Parco Sempione, Milano',
      startsAt: DateTime.now().add(const Duration(days: 12)),
      source: LocalActivitySource.seeded,
    ),
    LocalActivity(
      id: 'demo-activity-vaccinazioni',
      kind: LocalActivityKind.event,
      title: 'Giornata vaccinazioni gratuite',
      category: 'vaccinazioni',
      location: const Coordinates(latitude: 45.4595, longitude: 9.1910),
      addressLabel: 'Ambulatorio comunale, Milano',
      startsAt: DateTime.now().add(const Duration(days: 4)),
      source: LocalActivitySource.seeded,
    ),
    const LocalActivity(
      id: 'demo-activity-ambulatorio',
      kind: LocalActivityKind.service,
      title: 'Ambulatorio veterinario Navigli',
      category: 'ambulatorio',
      location: Coordinates(latitude: 45.4508, longitude: 9.1739),
      addressLabel: 'Navigli, Milano',
      source: LocalActivitySource.seeded,
    ),
  ];
}
