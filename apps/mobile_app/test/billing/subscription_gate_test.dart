import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/app/router/app_router.dart';
import 'package:vet_app_mobile/features/account/data/device_registry.dart';
import 'package:vet_app_mobile/features/billing/data/subscription_gate.dart';
import 'package:vet_app_mobile/features/billing/data/subscription_remote_data_source.dart';
import 'package:vet_app_mobile/features/billing/domain/billing_models.dart';
import 'package:vet_app_mobile/features/billing/domain/subscription_status.dart';
import 'package:vet_app_mobile/shared/errors/app_network_error.dart';
import 'package:vet_app_mobile/shared/types/result.dart';

class _FakeSubscriptionSource implements SubscriptionRemoteDataSource {
  _FakeSubscriptionSource(this.status);

  final SubscriptionStatus? status;

  @override
  Future<Result<SubscriptionStatus>> fetchStatus() async {
    final value = status;
    if (value == null) {
      return Result.failure(const AppNetworkError(code: 'down', message: 'down'));
    }
    return Result.success(value);
  }

  @override
  Future<Result<SubscriptionStatus>> selectPlan(PlanTier plan) =>
      throw UnimplementedError();
}

class _FakeRegistry implements DeviceRegistryClient {
  _FakeRegistry({required this.active});

  final bool active;
  final List<bool> claims = [];

  @override
  Future<bool> register({required bool claim}) async {
    claims.add(claim);
    return active;
  }
}

/// Answers after [delay] (or fails after it), and counts how often it was asked.
class _SlowSource implements SubscriptionRemoteDataSource {
  _SlowSource(this.status, {required this.delay, this.throwsAfterDelay = false});

  final SubscriptionStatus? status;
  final Duration delay;
  final bool throwsAfterDelay;
  int calls = 0;

  @override
  Future<Result<SubscriptionStatus>> fetchStatus() async {
    calls++;
    await Future<void>.delayed(delay);
    if (throwsAfterDelay) throw StateError('status failed late');
    final value = status;
    if (value == null) {
      return Result.failure(const AppNetworkError(code: 'down', message: 'down'));
    }
    return Result.success(value);
  }

  @override
  Future<Result<SubscriptionStatus>> selectPlan(PlanTier plan) =>
      throw UnimplementedError();
}

class _SlowRegistry implements DeviceRegistryClient {
  _SlowRegistry({required this.active, required this.delay});

  final bool active;
  final Duration delay;
  int calls = 0;

  @override
  Future<bool> register({required bool claim}) async {
    calls++;
    await Future<void>.delayed(delay);
    return active;
  }
}

SubscriptionStatus _status({required bool hasAccess}) => SubscriptionStatus(
      trialEndsAt: DateTime(2026, 12, 1),
      plan: null,
      isDeveloper: false,
      hasAccess: hasAccess,
    );

void main() {
  setUp(() => DeviceRegistry.pendingNotice = false);

  test('an active device with access goes to the home shell', () async {
    final registry = _FakeRegistry(active: true);
    final gate = SubscriptionGate(
      dataSource: _FakeSubscriptionSource(_status(hasAccess: true)),
      deviceRegistry: registry,
    );

    expect(await gate.resolveDestination(), AppRouter.homeShell);
    expect(DeviceRegistry.pendingNotice, isFalse);
  });

  test('without access (trial over, no plan) the destination is the paywall', () async {
    final gate = SubscriptionGate(
      dataSource: _FakeSubscriptionSource(_status(hasAccess: false)),
      deviceRegistry: _FakeRegistry(active: true),
    );

    expect(await gate.resolveDestination(), AppRouter.paywall);
  });

  test('right after a sign-in the device claims a place; on a plain start it does not', () async {
    final registry = _FakeRegistry(active: true);
    final gate = SubscriptionGate(
      dataSource: _FakeSubscriptionSource(_status(hasAccess: true)),
      deviceRegistry: registry,
    );

    await gate.resolveDestination(afterSignIn: true);
    await gate.resolveDestination();

    expect(registry.claims, [true, false]);
  });

  test('a device that lost its place is signed out and sent to the sign-in screen', () async {
    var signedOut = false;
    final gate = SubscriptionGate(
      dataSource: _FakeSubscriptionSource(_status(hasAccess: true)),
      deviceRegistry: _FakeRegistry(active: false),
      signOut: () async => signedOut = true,
    );

    expect(await gate.resolveDestination(), AppRouter.auth);
    expect(signedOut, isTrue);
    expect(DeviceRegistry.takePendingNotice(), isTrue);
    expect(DeviceRegistry.takePendingNotice(), isFalse, reason: 'the notice shows once');
  });

  test('an unreachable subscription service never locks the owner out', () async {
    final gate = SubscriptionGate(
      dataSource: _FakeSubscriptionSource(null),
      deviceRegistry: _FakeRegistry(active: true),
    );

    expect(await gate.resolveDestination(), AppRouter.homeShell);
  });

  group('a slow cold start', () {
    const registryDelay = Duration(seconds: 10); // the device call's own timeout
    const statusDelay = Duration(seconds: 15); // the status call's own timeout

    // testWidgets runs on a fake clock: `tester.pump(duration)` moves it, so
    // these "slow" cases take no real time.

    testWidgets('both requests are sent right away, before either one answers',
        (tester) async {
      final registry = _SlowRegistry(active: true, delay: registryDelay);
      final source = _SlowSource(_status(hasAccess: true), delay: statusDelay);
      final gate = SubscriptionGate(dataSource: source, deviceRegistry: registry);

      unawaited(gate.resolveDestination());
      await tester.pump();

      expect(registry.calls, 1);
      expect(source.calls, 1, reason: 'the status does not wait for the device call');
      // Let the slow fakes finish so no timer outlives the test.
      await tester.pump(statusDelay);
    });

    testWidgets('the owner waits for the slower call, not for both (15 s, not 25 s)',
        (tester) async {
      final gate = SubscriptionGate(
        dataSource: _SlowSource(_status(hasAccess: true), delay: statusDelay),
        deviceRegistry: _SlowRegistry(active: true, delay: registryDelay),
      );
      String? destination;
      unawaited(gate.resolveDestination().then((value) => destination = value));

      await tester.pump(const Duration(seconds: 14));
      expect(destination, isNull, reason: 'the status is still on its way');
      await tester.pump(const Duration(seconds: 1));
      expect(destination, AppRouter.homeShell);
    });

    testWidgets('without access the paywall also comes after 15 s, not 25 s',
        (tester) async {
      final gate = SubscriptionGate(
        dataSource: _SlowSource(_status(hasAccess: false), delay: statusDelay),
        deviceRegistry: _SlowRegistry(active: true, delay: registryDelay),
      );
      String? destination;
      unawaited(gate.resolveDestination().then((value) => destination = value));

      await tester.pump(statusDelay);

      expect(destination, AppRouter.paywall);
    });

    testWidgets('a status that fails after a slow device call never locks the owner out',
        (tester) async {
      final gate = SubscriptionGate(
        dataSource: _SlowSource(null, delay: statusDelay),
        deviceRegistry: _SlowRegistry(active: true, delay: registryDelay),
      );
      String? destination;
      unawaited(gate.resolveDestination().then((value) => destination = value));

      await tester.pump(statusDelay);

      expect(destination, AppRouter.homeShell);
    });

    testWidgets('a revoked device is signed out at once, without waiting for the status',
        (tester) async {
      var signedOut = false;
      final gate = SubscriptionGate(
        dataSource: _SlowSource(_status(hasAccess: true), delay: statusDelay),
        deviceRegistry: _SlowRegistry(active: false, delay: const Duration(seconds: 2)),
        signOut: () async => signedOut = true,
      );
      String? destination;
      unawaited(gate.resolveDestination().then((value) => destination = value));

      await tester.pump(const Duration(seconds: 2));

      expect(destination, AppRouter.auth);
      expect(signedOut, isTrue);
      expect(DeviceRegistry.takePendingNotice(), isTrue);
      // The status answers later: nothing more happens.
      await tester.pump(statusDelay);
      expect(destination, AppRouter.auth);
    });

    testWidgets('a status call that then throws, for a revoked device, is not an error',
        (tester) async {
      // An uncaught asynchronous error fails the test, so this passes only if
      // the late failure of the dropped status call was handled.
      final gate = SubscriptionGate(
        dataSource: _SlowSource(
          _status(hasAccess: true),
          delay: statusDelay,
          throwsAfterDelay: true,
        ),
        deviceRegistry: _SlowRegistry(active: false, delay: const Duration(seconds: 2)),
        signOut: () async {},
      );
      unawaited(gate.resolveDestination());

      await tester.pump(const Duration(seconds: 20));

      expect(tester.takeException(), isNull);
    });
  });
}
