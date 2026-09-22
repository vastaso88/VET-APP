import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/config/app_runtime_config_loader.dart';

class ListingReport {
  const ListingReport({
    required this.id,
    required this.listingId,
    required this.reporterOwnerId,
    required this.reason,
    required this.createdAt,
  });

  final String id;
  final String listingId;
  final String reporterOwnerId;
  final String reason;
  final DateTime createdAt;
}

/// Same shape as the other repositories in this app: optional Supabase
/// client, a session-lifetime local list as demo/no-backend fallback.
class ListingReportsRepository {
  ListingReportsRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  static final List<ListingReport> _localReports = [];

  Future<void> save(ListingReport report) async {
    _localReports.add(report);

    final client = _resolveClient();
    if (client == null) {
      return;
    }

    try {
      await client.from('marketplace_listing_reports').insert({
        'id': report.id,
        'listing_id': report.listingId,
        'reporter_owner_id': report.reporterOwnerId,
        'reason': report.reason,
        'created_at': report.createdAt.toIso8601String(),
      });
    } catch (_) {
      // Best-effort: the local list above already counts this report for
      // this session even if the remote insert fails.
    }
  }

  /// Distinct reporters, not raw report rows - mirrors
  /// packages/core/application/services/report_listing.py so one user
  /// spamming reports can't alone force a removal.
  Future<int> countDistinctReporters(String listingId) async {
    final remote = await _tryCountRemote(listingId);
    if (remote != null) {
      return remote;
    }
    return _localReports
        .where((report) => report.listingId == listingId)
        .map((report) => report.reporterOwnerId)
        .toSet()
        .length;
  }

  Future<int?> _tryCountRemote(String listingId) async {
    final client = _resolveClient();
    if (client == null) {
      return null;
    }

    try {
      final response = await client
          .from('marketplace_listing_reports')
          .select('reporter_owner_id')
          .eq('listing_id', listingId);
      final rows = response as List<dynamic>;
      return rows
          .map((row) => (row as Map<String, dynamic>)['reporter_owner_id'].toString())
          .toSet()
          .length;
    } catch (_) {
      return null;
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
}
