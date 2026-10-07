import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/dog_walks/data/active_walk_controller.dart';
import 'package:vet_app_mobile/features/dog_walks/data/dog_walks_repository.dart';
import 'package:vet_app_mobile/features/dog_walks/data/home_widget_action_store.dart';
import 'package:vet_app_mobile/features/dog_walks/data/walk_foreground_service.dart';
import 'package:vet_app_mobile/features/dog_walks/domain/gps_fix.dart';
import 'package:vet_app_mobile/features/dog_walks/domain/walk_session.dart';

WalkSession _walk({
  double distance = 800,
  bool paused = false,
  DateTime? startedAt,
  int pausedSeconds = 0,
  DateTime? pausedAt,
}) {
  return WalkSession(
    id: 'walk-1',
    ownerId: 'owner-1',
    petId: 'pet-1',
    startedAt: startedAt ?? DateTime(2026, 10, 7, 10),
    distanceMeters: distance,
    isPaused: paused,
    pausedAt: pausedAt,
    pausedSeconds: pausedSeconds,
  );
}

/// Records what the controller asks of the walk notification.
class _RecordingService extends WalkForegroundService {
  final calls = <String>[];

  @override
  Future<bool> start(WalkSession walk) async {
    calls.add('start');
    return true;
  }

  @override
  Future<void> update(WalkSession walk) async {
    calls.add(walk.isPaused ? 'update:paused' : 'update:running');
  }

  @override
  Future<void> stop() async => calls.add('stop');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WalkNotificationContent', () {
    final now = DateTime(2026, 10, 7, 10, 12);

    test('running: pet name, distance and a chronometer base', () {
      final content = WalkNotificationContent.fromWalk(_walk(), petName: 'Fido', now: now);
      expect(content.title, 'Passeggiata con Fido');
      expect(content.text, '800 m percorsi');
      expect(content.isPaused, isFalse);
      expect(content.chronometerBase, DateTime(2026, 10, 7, 10));
    });

    test('the chronometer base skips the time spent paused', () {
      final content = WalkNotificationContent.fromWalk(
        _walk(pausedSeconds: 120),
        petName: 'Fido',
        now: now,
      );
      expect(content.chronometerBase, DateTime(2026, 10, 7, 10, 2));
    });

    test('paused: says so and shows the minutes walked, no chronometer', () {
      final content = WalkNotificationContent.fromWalk(
        _walk(paused: true, pausedAt: now, distance: 1300),
        petName: 'Fido',
        now: now,
      );
      expect(content.title, 'Passeggiata con Fido · in pausa');
      expect(content.text, '12 min · 1.3 km');
      expect(content.chronometerBase, isNull);
    });

    test('an unknown pet falls back to a generic title', () {
      final content = WalkNotificationContent.fromWalk(_walk(), petName: null, now: now);
      expect(content.title, 'Passeggiata in corso');
    });
  });

  group('AndroidWalkForegroundService', () {
    const channel = MethodChannel('test/walk_tracking_service');
    late List<MethodCall> calls;
    late DateTime clock;

    AndroidWalkForegroundService build({bool permission = true, bool nativeStarts = true}) {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return call.method == 'start' ? nativeStarts : null;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null));
      clock = DateTime(2026, 10, 7, 10, 5);
      return AndroidWalkForegroundService(
        channel: channel,
        petNameOf: (_) => 'Fido',
        hasLocationPermission: () async => permission,
        clock: () => clock,
      );
    }

    test('start sends the notification content and reports success', () async {
      final service = build();
      expect(await service.start(_walk()), isTrue);
      expect(calls.single.method, 'start');
      final args = calls.single.arguments as Map;
      expect(args['petId'], 'pet-1');
      expect(args['title'], 'Passeggiata con Fido');
      expect(args['paused'], false);
    });

    test('no location permission: no native start, the caller falls back', () async {
      final service = build(permission: false);
      expect(await service.start(_walk()), isFalse);
      expect(calls, isEmpty);
    });

    test('distance-only changes are throttled, pause goes through at once', () async {
      final service = build();
      await service.start(_walk(distance: 100));

      clock = clock.add(const Duration(seconds: 3));
      await service.update(_walk(distance: 120));
      expect(calls.where((c) => c.method == 'update'), isEmpty);

      await service.update(_walk(distance: 120, paused: true, pausedAt: clock));
      expect(calls.where((c) => c.method == 'update'), hasLength(1));

      clock = clock.add(const Duration(seconds: 11));
      await service.update(_walk(distance: 150, paused: true, pausedAt: clock));
      expect(calls.where((c) => c.method == 'update'), hasLength(2));
    });

    test('an identical notification is not re-posted', () async {
      final service = build();
      await service.start(_walk());
      clock = clock.add(const Duration(minutes: 1));
      await service.update(_walk());
      expect(calls.where((c) => c.method == 'update'), isEmpty);
    });

    test('stop ends the native service once, updates afterwards are ignored', () async {
      final service = build();
      await service.start(_walk());
      await service.stop();
      await service.stop();
      await service.update(_walk(distance: 900));
      expect(calls.map((c) => c.method), ['start', 'stop']);
    });
  });

  group('ActiveWalkController with the walk notification', () {
    test('start, pause, resume and stop drive the notification', () async {
      final service = _RecordingService();
      final controller = ActiveWalkController(
        repository: DogWalksRepository(),
        foregroundService: service,
      );
      final gps = StreamController<GpsFix>();
      addTearDown(() async {
        await gps.close();
        controller.dispose();
      });

      await controller.start(ownerId: 'owner-1', petId: 'pet-1', positionStream: gps.stream);
      await controller.pause();
      await controller.resume();
      await controller.stop();

      expect(service.calls, ['start', 'update:paused', 'update:running', 'stop']);
      // Pausing no longer restarts the GPS stream: a single-subscription
      // stream would have thrown on a second listen.
      expect(controller.walk!.status, WalkStatus.completed);
    });
  });

  test('the notification "Termina" deep link parses as finishWalk', () {
    final action = HomeWidgetAction.tryParse(Uri.parse('homewidget://finish_walk?petId=p9'));
    expect(action?.kind, HomeWidgetActionKind.finishWalk);
    expect(action?.petId, 'p9');
  });
}
