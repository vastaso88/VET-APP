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
}
