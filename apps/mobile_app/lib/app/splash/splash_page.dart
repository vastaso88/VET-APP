import 'dart:async';

import 'package:flutter/material.dart';

import '../../design_system/tokens/app_colors.dart';
import '../../design_system/tokens/app_spacing.dart';
import '../../design_system/tokens/app_text_styles.dart';
import '../../features/auth/data/auth_repository_factory.dart';
import '../../features/billing/data/subscription_gate.dart';
import '../../shared/auth/current_user.dart';
import '../launch/warm_start_store.dart';
import '../router/app_router.dart';
import 'app_preloader.dart';
import 'loading_animation.dart';

export 'loading_animation.dart' show splashMessageInterval;

/// Minimum time the splash stays up, so the animation never just flashes.
/// Longer than the preload usually needs on its own — a deliberate product
/// choice (2026-09-30) to give the animation room to play, not a timeout
/// tied to how slow loading is. Preload/gate running past this still
/// extends the splash further (see _restoreSessionAndRoute's Future.wait).
const splashMinDisplay = Duration(seconds: 4);

/// A returning owner with a valid session and cached access skips the long
/// animation (see [SplashPage.warmTab]): just long enough not to flash.
const splashWarmMinDisplay = Duration(milliseconds: 400);

class SplashPage extends StatefulWidget {
  const SplashPage({
    super.key,
    this.restoreSignedIn,
    this.preload,
    this.resolveDestination,
    this.warmTab,
    this.minDisplay = splashMinDisplay,
  });

  /// Whether a session could be restored. Defaults to the auth repository.
  final Future<bool> Function()? restoreSignedIn;

  /// Loads the data the home needs (pets, chat, reminders, records,
  /// location, backend warm-up). Defaults to [AppPreloader.run].
  final Future<void> Function()? preload;

  /// Picks home vs paywall for a signed-in user. Defaults to
  /// [SubscriptionGate]: the gate is never skipped, only run in parallel
  /// with the preload.
  final Future<String> Function()? resolveDestination;

  /// The tab to reopen when this launch can skip the full splash - signed in,
  /// and the last subscription check (same owner, a few days at most) gave
  /// access - or null for the normal flow. The preload and the real gate then
  /// run in the background; a refusal still lands on the paywall. Defaults to
  /// [WarmStartStore.warmTab] for the signed-in owner.
  final Future<int?> Function()? warmTab;

  final Duration minDisplay;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _restoreSessionAndRoute();
      }
    });
  }

  Future<bool> _defaultRestoreSignedIn() async {
    final result = await const AuthRepositoryFactory().create().restoreSession();
    return result.fold(
      onSuccess: (context) => context.isSignedIn,
      onFailure: (_) => false,
    );
  }

  Future<void> _restoreSessionAndRoute() async {
    final elapsed = Stopwatch()..start();
    // Waits out what is left of [minimum] since the splash appeared.
    Future<void> remaining(Duration minimum) {
      final left = minimum - elapsed.elapsed;
      return left <= Duration.zero ? Future<void>.value() : Future<void>.delayed(left);
    }

    final signedIn = await (widget.restoreSignedIn ?? _defaultRestoreSignedIn)();
    if (!mounted) return;

    if (!signedIn) {
      await remaining(widget.minDisplay);
      _goTo(AppRouter.auth);
      return;
    }

    // Returning owner whose access was confirmed recently: straight to the
    // tab that was open, everything else refreshes behind it.
    final warm = await (widget.warmTab ?? _defaultWarmTab)();
    if (!mounted) return;
    if (warm != null) {
      unawaited((widget.preload ?? AppPreloader().run)().catchError((Object _) {}));
      unawaited(_confirmAccessInBackground());
      await remaining(
        widget.minDisplay == splashMinDisplay ? splashWarmMinDisplay : widget.minDisplay,
      );
      _goTo(AppRouter.homeShell, arguments: warm);
      return;
    }

    // Signed in: the subscription gate and the preload run in parallel.
    // The preload is capped (AppPreloader.timeout) and best-effort; the
    // gate has its own request timeout and fails open to the home.
    final destinationFuture =
        (widget.resolveDestination ?? const SubscriptionGate().resolveDestination)();
    final preloadFuture = (widget.preload ?? AppPreloader().run)();
    await Future.wait<void>([
      remaining(widget.minDisplay),
      preloadFuture.catchError((Object _) {}),
    ]);
    final destination = await destinationFuture;
    unawaited(_rememberAccess(destination));
    _goTo(destination);
  }

  Future<int?> _defaultWarmTab() async {
    final ownerId = CurrentUser.get()?.id;
    if (ownerId == null) return null;
    return const WarmStartStore().warmTab(ownerId);
  }

  Future<void> _rememberAccess(String destination) async {
    final ownerId = CurrentUser.get()?.id;
    if (ownerId == null) return;
    await const WarmStartStore().saveAccess(
      ownerId,
      hasAccess: destination != AppRouter.paywall,
    );
  }

  /// The gate still decides, just after the home is already up: a refusal
  /// (trial over, plan removed) replaces everything with the paywall.
  Future<void> _confirmAccessInBackground() async {
    try {
      final destination =
          await (widget.resolveDestination ?? const SubscriptionGate().resolveDestination)();
      await _rememberAccess(destination);
      if (destination == AppRouter.paywall) {
        AppRouter.navigatorKey.currentState
            ?.pushNamedAndRemoveUntil(AppRouter.paywall, (route) => false);
      }
    } catch (_) {
      // Fail-open, like the gate itself: the home stays.
    }
  }

  void _goTo(String destination, {Object? arguments}) {
    if (!mounted) return;
    final target = AppRouter.passwordRecoveryPending ? AppRouter.setNewPassword : destination;
    Navigator.of(context).pushReplacementNamed(
      target,
      arguments: target == destination ? arguments : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _SplashLogo(),
                const SizedBox(height: AppSpacing.xl),
                Text('VET APP', style: AppTextStyles.heading),
                const SizedBox(height: AppSpacing.xl),
                const LoadingAnimation(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SplashLogo extends StatelessWidget {
  const _SplashLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowStrong,
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: const Icon(
        Icons.pets_rounded,
        color: AppColors.onPrimary,
        size: 40,
      ),
    );
  }
}
