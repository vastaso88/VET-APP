import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design_system/atoms/animal_figure.dart';
import '../../design_system/responsive.dart';
import '../../design_system/tokens/app_colors.dart';
import '../../design_system/tokens/app_spacing.dart';
import '../../design_system/tokens/app_text_styles.dart';
import '../../l10n/l10n.dart';

/// The app's loading indicator: an animal spinning on its vertical axis.
///
/// The animal changes once per full turn, at the edge-on moment (a quarter
/// turn away from facing the viewer), so the swap happens while the figure is
/// too thin to read and never mid-face. The animals come in a random order, a
/// new one for each loader. With reduced motion the static first animal is
/// shown instead.
class PetLoader extends StatefulWidget {
  const PetLoader({
    this.size = 48,
    this.label,
    this.color,
    super.key,
  }) : _compactButton = false;

  /// Compact form for inside buttons and dense rows.
  const PetLoader.small({this.color, super.key})
      : size = 18,
        label = null,
        _compactButton = true;

  /// Base size before [appScaleOf]; scaled to the real screen width.
  final double size;
  final String? label;

  /// Of the animal and, much paler, of the disc behind it: light on a dark
  /// ground. The accent by default.
  final Color? color;

  final bool _compactButton;

  static const animals = <AnimalFigure>[
    AnimalFigure.dog,
    AnimalFigure.cat,
    AnimalFigure.rabbit,
    AnimalFigure.bird,
    AnimalFigure.fish,
    AnimalFigure.smallMammal,
    AnimalFigure.reptile,
  ];

  /// The order the animals turn up in, chosen once for each loader: shuffled,
  /// so it does not always start with the dog and the cat. Tests replace it
  /// with one that keeps the order.
  static List<AnimalFigure> Function(List<AnimalFigure> animals) orderOf = _shuffled;

  static List<AnimalFigure> _shuffled(List<AnimalFigure> animals) =>
      List<AnimalFigure>.of(animals)..shuffle(math.Random());

  /// Length of one full turn.
  static const turnDuration = Duration(milliseconds: 1800);

  @override
  State<PetLoader> createState() => _PetLoaderState();
}

class _PetLoaderState extends State<PetLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: PetLoader.turnDuration,
  );

  late final List<AnimalFigure> _order = PetLoader.orderOf(PetLoader.animals);

  bool? _reduceMotion;
  int _turns = 0;
  double _lastValue = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final value = _controller.value;
      if (value < _lastValue) _turns++;
      _lastValue = value;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce == _reduceMotion) return;
    _reduceMotion = reduce;
    if (reduce) {
      _controller.stop();
      _controller.value = 0;
      _turns = 0;
      _lastValue = 0;
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget._compactButton ? 1.0 : appScaleOf(context);
    final size = widget.size * scale;
    final disc = widget.color ?? AppColors.primary;

    final spinner = AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        // Advances when the phase crosses 270° (edge-on), once per turn.
        final index = (_turns + t + 0.25).floor() % _order.length;
        final angle = t * 2 * math.pi;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: disc.withValues(alpha: 0.14),
            ),
            alignment: Alignment.center,
            child: AnimalFigureIcon(_order[index], size: size * 0.72, color: disc),
          ),
        );
      },
    );

    final label = widget.label;
    // One spoken name: the turning animal and the text under it are not
    // read out on top of it.
    return Semantics(
      label: label ?? context.l10n.sharedLoadingLabel,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          spinner,
          if (label != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: widget.color ?? AppColors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
