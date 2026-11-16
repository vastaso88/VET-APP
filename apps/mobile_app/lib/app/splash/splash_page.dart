import 'dart:async';

import 'package:flutter/material.dart';

import '../../design_system/tokens/app_colors.dart';
import '../../l10n/l10n.dart';
import '../../design_system/tokens/app_spacing.dart';
import '../../features/auth/data/auth_repository_factory.dart';
import '../../features/billing/data/subscription_gate.dart';
import '../../shared/auth/current_user.dart';
import '../../shared/widgets/pet_loader.dart';
import '../../shared/widgets/quokka_logo.dart';
import '../launch/warm_start_store.dart';
import '../router/app_router.dart';
import 'app_preloader.dart';
import 'loading_animation.dart';

export 'loading_animation.dart' show splashMessageInterval;

/// Minimum time the opening screen stays up so the logo and the phrases can be
/// seen (owner, 2026-11-17: at least 3 seconds), for every launch.
const splashMinDisplay = Duration(seconds: 3);

/// The head of the logo: the size and (centred) place of the native splash's.
const splashHeadSize = 112.0;

/// The most the opening screen waits for the calendar and the news (the
/// preload) before showing the Home anyway: with no network the app is never
/// stuck, and the Home shows its own loading states.
const splashMaxWait = Duration(seconds: 10);

class SplashPage extends StatefulWidget {
  const SplashPage({
    super.key,
    this.restoreSignedIn,
    this.preload,
    this.resolveDestination,
    this.warmTab,
    this.minDisplay = splashMinDisplay,
    this.maxWait = splashMaxWait,
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

  /// Cap on waiting for the preload (see [splashMaxWait]).
  final Duration maxWait;

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
      // The opening screen covers the loading: the Home appears once the
      // calendar and the news are in (or after the cap), never before the
      // minimum time.
      unawaited(_confirmAccessInBackground());
      await Future.wait<void>([
        remaining(widget.minDisplay),
        _preloadCapped(),
      ]);
      _goTo(AppRouter.homeShell, arguments: warm);
      return;
    }

    // Signed in: the subscription gate and the preload run in parallel.
    // The preload is capped (AppPreloader.timeout) and best-effort; the
    // gate has its own request timeout and fails open to the home.
    final destinationFuture =
        (widget.resolveDestination ?? const SubscriptionGate().resolveDestination)();
    await Future.wait<void>([
      remaining(widget.minDisplay),
      _preloadCapped(),
    ]);
    final destination = await destinationFuture;
    unawaited(_rememberAccess(destination));
    _goTo(destination);
  }

  /// The preload, never failing and never waited for longer than the cap.
  Future<void> _preloadCapped() => (widget.preload ?? AppPreloader().run)()
      .catchError((Object _) {})
      .timeout(widget.maxWait, onTimeout: () {});

  Future<int?> _defaultWarmTab() async {
    final ownerId = CurrentUser.get()?.id;
    if (ownerId == null) return null;
    // A launch is a new process (the old one was killed): always Home. The
    // saved tab is not used any more; only "access confirmed recently" counts.
    final saved = await const WarmStartStore().warmTab(ownerId);
    return saved == null ? null : 0;
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
  /// (trial over, plan removed) replaces everything with the paywall, and a
  /// revoked device (the gate has already signed out) with the sign-in page.
  Future<void> _confirmAccessInBackground() async {
    try {
      final destination =
          await (widget.resolveDestination ?? const SubscriptionGate().resolveDestination)();
      await _rememberAccess(destination);
      if (destination == AppRouter.paywall || destination == AppRouter.auth) {
        AppRouter.navigatorKey.currentState
            ?.pushNamedAndRemoveUntil(destination, (route) => false);
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
      backgroundColor: AppColors.brandDeep,
      body: SafeArea(
        top: false,
        bottom: false,
        // The head stays exactly where the native splash draws it (centre of
        // the screen, 112 dp) so the hand-over is not seen; the name, the
        // spinning animal and the phrases appear under it.
        child: LayoutBuilder(
          builder: (context, box) => Stack(
            children: [
              Center(
                child: Semantics(
                  label: context.l10n.appTitle,
                  child: const QuokkaLogo.headOnDark(size: splashHeadSize),
                ),
              ),
              Positioned(
                top: box.maxHeight / 2 + splashHeadSize / 2 + AppSpacing.md,
                left: 0,
                right: 0,
                bottom: 0,
                child: _FadeIn(
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                    child: Column(
                      children: [
                        const QuokkaWordmark.onDark(width: 170),
                        const SizedBox(height: AppSpacing.lg),
                        const PetLoader(size: 52, color: AppColors.brandPaper),
                        const SizedBox(height: AppSpacing.md),
                        const SplashRotatingMessages(color: AppColors.brandPaper),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fades its child in shortly after the screen appears, so the head alone is
/// what the native splash hands over and the rest arrives softly. With reduced
/// motion it is simply there.
class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: const Interval(0.3, 1, curve: Curves.easeOut),
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: child,
    );
  }
}
