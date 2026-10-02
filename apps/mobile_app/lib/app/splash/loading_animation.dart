import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design_system/tokens/app_spacing.dart';
import '../../design_system/tokens/app_text_styles.dart';
import 'splash_messages.dart';

/// How often the feature teaser under the animation changes.
const splashMessageInterval = Duration(milliseconds: 2500);

/// The splash's animal-ticker + rotating-teaser animation, extracted so any
/// other slow-loading screen can reuse the same "the app is working on
/// something" moment instead of a bare spinner — first reused by the News
/// page's loading state (2026-09-30).
class LoadingAnimation extends StatelessWidget {
  const LoadingAnimation({super.key, this.label});

  /// Shown above the animation, e.g. "Carico le News...". Omit to match
  /// the splash's own bare animation (no caption).
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(label!, style: AppTextStyles.title, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.lg),
        ],
        const SplashAnimalTicker(),
        const SizedBox(height: AppSpacing.lg),
        const SplashRotatingMessages(),
      ],
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
