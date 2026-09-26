import '../../../app/router/app_router.dart';
import 'subscription_remote_data_source.dart';

/// Decides whether a signed-in user lands on the home shell or the paywall
/// — trial expired, no plan chosen, not on the developer allowlist (spec:
/// 10 free days, no card, then a mandatory plan choice). Used right after
/// login and on every cold start (see splash_page.dart).
class SubscriptionGate {
  const SubscriptionGate({SubscriptionRemoteDataSource? dataSource})
      : _dataSource = dataSource;

  final SubscriptionRemoteDataSource? _dataSource;

  Future<String> resolveDestination() async {
    final source = _dataSource ?? HttpSubscriptionRemoteDataSource();
    final result = await source.fetchStatus();
    return result.fold(
      // Fail-open: a backend hiccup shouldn't lock a legitimate user out of
      // the app they were already signed into.
      onSuccess: (status) => status.hasAccess ? AppRouter.homeShell : AppRouter.paywall,
      onFailure: (_) => AppRouter.homeShell,
    );
  }
}
