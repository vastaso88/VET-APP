import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design_system/tokens/app_colors.dart';
import '../../design_system/tokens/app_spacing.dart';
import '../../design_system/tokens/app_text_styles.dart';
import '../../features/auth/data/auth_repository_factory.dart';
import '../../features/billing/data/subscription_gate.dart';
import '../router/app_router.dart';
import 'app_preloader.dart';
import 'splash_messages.dart';

/// Minimum time the splash stays up, so the animation never just flashes.
const splashMinDisplay = Duration(milliseconds: 1200);

/// How often the feature teaser under the animation changes.
const splashMessageInterval = Duration(milliseconds: 2500);

class SplashPage extends StatefulWidget {
  const SplashPage({
    super.key,
    this.restoreSignedIn,
    this.preload,
    this.resolveDestination,
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
    final minDelay = Future<void>.delayed(widget.minDisplay);

    final signedIn = await (widget.restoreSignedIn ?? _defaultRestoreSignedIn)();
    if (!mounted) return;

    if (!signedIn) {
      await minDelay;
      _goTo(AppRouter.auth);
      return;
    }

    // Signed in: the subscription gate and the preload run in parallel.
    // The preload is capped (AppPreloader.timeout) and best-effort; the
    // gate has its own request timeout and fails open to the home.
    final destinationFuture =
        (widget.resolveDestination ?? const SubscriptionGate().resolveDestination)();
    final preloadFuture = (widget.preload ?? AppPreloader().run)();
    await Future.wait<void>([
      minDelay,
      preloadFuture.catchError((Object _) {}),
    ]);
    final destination = await destinationFuture;
    _goTo(destination);
  }

  void _goTo(String destination) {
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(destination);
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
                const SplashAnimalTicker(),
                const SizedBox(height: AppSpacing.lg),
                const SplashRotatingMessages(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Continuously scrolling strip of pet emojis with a small bobbing motion.
class SplashAnimalTicker extends StatefulWidget {
  const SplashAnimalTicker({super.key});

  @override
  State<SplashAnimalTicker> createState() => _SplashAnimalTickerState();
}

class _SplashAnimalTickerState extends State<SplashAnimalTicker>
    with SingleTickerProviderStateMixin {
  static const _slot = 56.0;
  static const _windowWidth = 4 * _slot;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 1800 * splashAnimals.length),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stripWidth = _slot * splashAnimals.length;
    return ExcludeSemantics(
      child: SizedBox(
        width: _windowWidth,
        height: 64,
        child: ShaderMask(
          // Fade the edges so emojis glide in and out of the window.
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              Color(0x00FFFFFF),
              Color(0xFFFFFFFF),
              Color(0xFFFFFFFF),
              Color(0x00FFFFFF),
            ],
            stops: [0, 0.2, 0.8, 1],
          ).createShader(bounds),
          blendMode: BlendMode.dstIn,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final shift = _controller.value * stripWidth;
              return Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  for (var i = 0; i < splashAnimals.length; i++)
                    _positioned(i, shift, stripWidth),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _positioned(int index, double shift, double stripWidth) {
    // Wrap each emoji around the strip so the loop is seamless.
    var x = (index * _slot - shift) % stripWidth;
    if (x < 0) x += stripWidth;
    if (x > stripWidth - _slot) x -= stripWidth;
    final bob = math.sin((_controller.value * 2 * math.pi * 3) + index) * 4;
    return Positioned(
      left: x,
      top: 8 + bob,
      width: _slot,
      child: Text(
        splashAnimals[index],
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 34),
      ),
    );
  }
}

/// Small feature teasers that swap every [splashMessageInterval].
class SplashRotatingMessages extends StatefulWidget {
  const SplashRotatingMessages({super.key});

  @override
  State<SplashRotatingMessages> createState() => _SplashRotatingMessagesState();
}

class _SplashRotatingMessagesState extends State<SplashRotatingMessages> {
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(splashMessageInterval, (_) {
      if (mounted) {
        setState(() => _index = (_index + 1) % splashMessages.length);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // Fixed height so long messages don't make the layout jump.
      height: 44,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.25),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: Text(
          splashMessages[_index],
          key: ValueKey<int>(_index),
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall,
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
            color: Color(0x26163A35),
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
