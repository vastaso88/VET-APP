import '../../../app/router/app_router.dart';

/// The API answers 402 `subscription_required` when the trial ended in the
/// middle of a session. Data sources call this on every non-success answer:
/// on a 402 it sends the owner to the paywall (the whole navigation stack
/// is replaced, same as at start-up) and returns true.
bool handleSubscriptionRequired(int statusCode) {
  if (statusCode != 402) return false;
  AppRouter.navigatorKey.currentState?.pushNamedAndRemoveUntil(
    AppRouter.paywall,
    (route) => false,
  );
  return true;
}
