import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' as geolocator;

import '../../pets/data/pet_demo_store.dart';
import '../domain/walk_session.dart';
import '../presentation/walk_labels.dart';

/// What the walk's status-bar notification shows. Pure, so the wording is
/// unit-testable without a device.
class WalkNotificationContent {
  const WalkNotificationContent({
    required this.title,
    required this.text,
    required this.isPaused,
    this.chronometerBase,
  });

  /// Running: "Passeggiata con Fido" / "0.8 km percorsi", plus a chronometer
  /// the system ticks from [chronometerBase] (start time shifted by the
  /// pauses), so the notification is only re-posted when the text changes.
  /// Paused: "Passeggiata con Fido · in pausa" / "12 min · 0.8 km", no
  /// chronometer (it would keep counting).
  factory WalkNotificationContent.fromWalk(
    WalkSession walk, {
    String? petName,
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    final activeSeconds = walkActiveDurationSeconds(walk, now: at);
    final name = petName?.trim() ?? '';
    final baseTitle = name.isEmpty ? 'Passeggiata in corso' : 'Passeggiata con $name';
    final distance = walkDistanceLabel(walk.distanceMeters);
    if (walk.isPaused) {
      return WalkNotificationContent(
        title: '$baseTitle · in pausa',
        text: '${walkDurationLabel(activeSeconds)} · $distance',
        isPaused: true,
      );
    }
    return WalkNotificationContent(
      title: baseTitle,
      text: '$distance percorsi',
      isPaused: false,
      chronometerBase: at.subtract(Duration(seconds: activeSeconds)),
    );
  }

  final String title;
  final String text;
  final bool isPaused;
  final DateTime? chronometerBase;

  /// Equal keys mean an identical-looking notification (the chronometer base
  /// drifts by under a second between calls and is deliberately left out).
  String get key => '$title|$text|$isPaused';

  Map<String, Object?> toArgs(String petId) => {
        'petId': petId,
        'title': title,
        'text': text,
        'paused': isPaused,
        'chronometerBaseMillis': chronometerBase?.millisecondsSinceEpoch ?? 0,
      };
}

/// The walk's ongoing notification (and, on Android, the foreground service
/// behind it that keeps GPS alive in the background). Driven by
/// ActiveWalkController: [start] once per walk, [update] on every change,
/// [stop] when the walk ends.
abstract class WalkForegroundService {
  const WalkForegroundService();

  /// The right implementation for this platform: the native service on
  /// Android, nothing elsewhere (web and iOS don't track in the background).
  factory WalkForegroundService.forPlatform() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidWalkForegroundService();
    }
    return const NoopWalkForegroundService();
  }

  /// Whether the notification is up. False tells the controller to fall back
  /// to geolocator's own foreground notification.
  Future<bool> start(WalkSession walk);

  Future<void> update(WalkSession walk);

  Future<void> stop();
}

class NoopWalkForegroundService extends WalkForegroundService {
  const NoopWalkForegroundService();

  @override
  Future<bool> start(WalkSession walk) async => false;

  @override
  Future<void> update(WalkSession walk) async {}

  @override
  Future<void> stop() async {}
}

/// Talks to WalkTrackingService.kt over a MethodChannel.
class AndroidWalkForegroundService extends WalkForegroundService {
  AndroidWalkForegroundService({
    MethodChannel channel = const MethodChannel('vetapp/walk_tracking_service'),
    String? Function(String petId)? petNameOf,
    Future<bool> Function()? hasLocationPermission,
    DateTime Function()? clock,
  })  : _channel = channel,
        _petNameOf = petNameOf ?? _petNameFromStore,
        _hasLocationPermission = hasLocationPermission ?? _geolocatorPermission,
        _clock = clock ?? DateTime.now;

  /// Distance-only changes are re-posted at most this often: a fix arrives
  /// every few seconds and the shade doesn't need to flicker at that pace.
  /// A pause/resume or a different pet name always goes through at once.
  static const minDistanceUpdateGap = Duration(seconds: 10);

  final MethodChannel _channel;
  final String? Function(String petId) _petNameOf;
  final Future<bool> Function() _hasLocationPermission;
  final DateTime Function() _clock;

  bool _running = false;
  String? _lastKey;
  bool? _lastPaused;
  DateTime? _lastPostedAt;

  bool get isRunning => _running;

  static String? _petNameFromStore(String petId) {
    for (final pet in PetDemoStore.instance.list()) {
      if (pet.id == petId) return pet.name;
    }
    return null;
  }

  /// Android 14 refuses a location-typed foreground service without the
  /// location permission - better to know up front and use the fallback.
  static Future<bool> _geolocatorPermission() async {
    final permission = await geolocator.Geolocator.checkPermission();
    return permission == geolocator.LocationPermission.whileInUse ||
        permission == geolocator.LocationPermission.always;
  }

  WalkNotificationContent _contentFor(WalkSession walk) => WalkNotificationContent.fromWalk(
        walk,
        petName: _petNameOf(walk.petId),
        now: _clock(),
      );

  @override
  Future<bool> start(WalkSession walk) async {
    try {
      if (!await _hasLocationPermission()) return false;
      final content = _contentFor(walk);
      final started =
          await _channel.invokeMethod<bool>('start', content.toArgs(walk.petId)) ?? false;
      _running = started;
      if (started) _remember(content);
      return started;
    } catch (_) {
      _running = false;
      return false;
    }
  }

  @override
  Future<void> update(WalkSession walk) async {
    if (!_running) return;
    final content = _contentFor(walk);
    if (content.key == _lastKey) return;
    final lastAt = _lastPostedAt;
    if (content.isPaused == _lastPaused &&
        lastAt != null &&
        _clock().difference(lastAt) < minDistanceUpdateGap &&
        !_titleChanged(content)) {
      return;
    }
    _remember(content);
    try {
      await _channel.invokeMethod<void>('update', content.toArgs(walk.petId));
    } catch (_) {
      // Best-effort: a stale notification text never affects tracking.
    }
  }

  bool _titleChanged(WalkNotificationContent content) =>
      _lastKey != null && !_lastKey!.startsWith('${content.title}|');

  void _remember(WalkNotificationContent content) {
    _lastKey = content.key;
    _lastPaused = content.isPaused;
    _lastPostedAt = _clock();
  }

  @override
  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    _lastKey = null;
    _lastPaused = null;
    _lastPostedAt = null;
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (_) {
      // Nothing else to do: the activity finishing stops it natively too.
    }
  }
}
