import 'dart:async';

import 'package:http/http.dart' as http;

import '../../features/chat/data/chat_demo_store.dart';
import '../../features/location/data/location_preference_store.dart';
import '../../features/location/data/location_repository.dart';
import '../../features/medical_records/data/medical_records_repository.dart';
import '../../features/pet_news/data/pet_news_repository.dart';
import '../../features/pets/data/pet_demo_store.dart';
import '../../features/reminders/data/reminders_repository.dart';
import '../../shared/auth/current_owner.dart';
import '../../shared/config/app_runtime_config_loader.dart';

/// Loads everything the home shell needs while the splash is on screen, so
/// the first frame after the splash already has real data instead of each
/// tab starting its own sequential hydration (and the first backend call
/// paying Vercel's cold start).
///
/// Every task is independent and best-effort: a failure or a slow backend
/// never blocks the app, it only means that screen hydrates lazily as
/// before (all the stores' `ensureHydrated` are idempotent).
class AppPreloader {
  AppPreloader({
    List<Future<void> Function()>? tasks,
    this.timeout = defaultTimeout,
  }) : _tasks = tasks ?? defaultTasks();

  /// Overall cap for the preload: past this the app proceeds anyway and
  /// whatever is still in flight keeps running in the background.
  static const defaultTimeout = Duration(seconds: 8);

  final List<Future<void> Function()> _tasks;
  final Duration timeout;

  /// Runs all tasks in parallel; completes when they all finish or
  /// [timeout] elapses, whichever comes first. Never throws.
  Future<void> run() async {
    final futures = <Future<void>>[
      for (final task in _tasks) _guard(task),
    ];
    try {
      await Future.wait(futures).timeout(timeout);
    } on TimeoutException {
      // Proceed anyway; unfinished tasks keep going in the background.
    }
  }

  static Future<void> _guard(Future<void> Function() task) async {
    try {
      await task();
    } catch (_) {
      // Best-effort: the owning screen retries its own hydration lazily.
    }
  }

  static List<Future<void> Function()> defaultTasks() => [
        warmUpBackend,
        PetDemoStore.instance.ensureHydrated,
        ChatDemoStore.instance.ensureHydrated,
        RemindersRepository().ensureHydrated,
        () => MedicalRecordsRepository().loadRecords(),
        _loadLocation,
        _warmPetNewsCache,
      ];

  /// Fetches every "curiosità" category ahead of time so its 20-minute
  /// cache (GoogleNewsPetNewsRepository) is already warm by the time the
  /// user opens Home or the News page — best-effort like every other task
  /// here, but worth calling out: unlike the others, this one can keep
  /// running in the background past the preload's own timeout (see
  /// AppPreloader.run/_guard) since `fetchManyWithLimitStreaming` has no
  /// way to be cancelled mid-batch. That's fine — it only ever *adds*
  /// cache entries, never blocks anything downstream from proceeding.
  static Future<void> _warmPetNewsCache() async {
    final repository = GoogleNewsPetNewsRepository();
    await fetchManyWithLimit(
      allPetNewsCategories
          .map((c) => () => repository.fetchForSpecies(c, limit: petNewsPoolLimitPerCategory))
          .toList(),
    );
  }

  /// GET /health on the FastAPI backend: absorbs the Vercel cold start
  /// (~2 s) so the first real call (subscription status, chat) is warm.
  static Future<void> warmUpBackend() async {
    final baseUrl = const AppRuntimeConfigLoader().load().apiBaseUrl;
    if (baseUrl.isEmpty) {
      return;
    }
    final client = http.Client();
    try {
      await client.get(Uri.parse('$baseUrl/health')).timeout(defaultTimeout);
    } finally {
      client.close();
    }
  }

  /// Same sync the Settings page does on open: local cache first, then a
  /// remote copy (cross-device source of truth) overwrites it if present.
  static Future<void> _loadLocation() async {
    await LocationPreferenceStore.instance.ensureLoaded();
    final remote = await LocationRepository().loadRemote(resolveCurrentOwnerId());
    if (remote != null) {
      await LocationPreferenceStore.instance.update(remote);
    }
  }
}
