import '../../../app/router/app_router.dart';
import '../../account/data/device_registry.dart';
import '../../auth/data/auth_repository_factory.dart';
import '../domain/subscription_status.dart';
import 'subscription_remote_data_source.dart';

/// Decides whether a signed-in user lands on the home shell or the paywall
/// — trial expired, no plan chosen, not on the developer allowlist (spec:
/// 14 free days, no card, then a mandatory plan choice) — and whether this
/// device may stay signed in at all (the plan limits how many devices an
/// account can use). Used right after login and on every cold start (see
/// splash_page.dart).
class SubscriptionGate {
  const SubscriptionGate({
    SubscriptionRemoteDataSource? dataSource,
    DeviceRegistryClient? deviceRegistry,
    Future<void> Function()? signOut,
  })  : _dataSource = dataSource,
        _deviceRegistry = deviceRegistry,
        _signOut = signOut;

  final SubscriptionRemoteDataSource? _dataSource;
  final DeviceRegistryClient? _deviceRegistry;
  final Future<void> Function()? _signOut;

  /// [afterSignIn] is true when the owner has just signed in: this device
  /// then takes a place among the plan's devices.
  Future<String> resolveDestination({bool afterSignIn = false}) async {
    final resolved = await resolve(afterSignIn: afterSignIn);
    return resolved.destination;
  }

  /// Same decision as [resolveDestination], also returning the status it was
  /// based on so the caller can show trial reminders without a second fetch.
  Future<({String destination, SubscriptionStatus? status})> resolve({
    bool afterSignIn = false,
  }) async {
    final registry = _deviceRegistry ?? DeviceRegistry();
    if (!await registry.register(claim: afterSignIn)) {
      // A newer device took this one's place: sign out here and say why on
      // the sign-in screen.
      DeviceRegistry.pendingNotice = true;
      await (_signOut ?? _defaultSignOut)();
      return (destination: AppRouter.auth, status: null);
    }

    final source = _dataSource ?? HttpSubscriptionRemoteDataSource();
    final result = await source.fetchStatus();
    return result.fold(
      // Fail-open: a backend hiccup shouldn't lock a legitimate user out of
      // the app they were already signed into.
      onSuccess: (status) => (
        destination: status.hasAccess ? AppRouter.homeShell : AppRouter.paywall,
        status: status,
      ),
      onFailure: (_) => (destination: AppRouter.homeShell, status: null),
    );
  }

  static Future<void> _defaultSignOut() async {
    await const AuthRepositoryFactory().create().signOut();
  }
}
