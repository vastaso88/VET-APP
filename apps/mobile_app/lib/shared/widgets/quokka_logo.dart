import 'package:flutter/material.dart';

import '../../design_system/tokens/app_colors.dart';

/// The Quokka logo (approved 2026-11-04), always in paper colour on the dark brand
/// ground: drawn dark on a light page the face turns into a negative. On light pages
/// use [QuokkaHeadTile]. Decorative: the app name is written next to it where it matters.
class QuokkaLogo extends StatelessWidget {
  /// The head with the name, in paper colour, for the dark brand ground.
  const QuokkaLogo.fullOnDark({super.key, this.size = 160})
      : _asset = 'assets/brand/quokka_logo_paper.png';

  /// The head in paper colour, for the dark brand ground.
  const QuokkaLogo.headOnDark({super.key, this.size = 40})
      : _asset = 'assets/brand/quokka_head_paper.png';

  final String _asset;

  /// Width and height of the square the logo is drawn in.
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Image.asset(
        _asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => SizedBox(width: size, height: size),
      ),
    );
  }
}

/// The head as in the app icon: paper colour on a petrol tile, for light pages.
class QuokkaHeadTile extends StatelessWidget {
  const QuokkaHeadTile({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.brandDeep,
          borderRadius: BorderRadius.circular(size * 0.26),
        ),
        child: QuokkaLogo.headOnDark(size: size * 0.76),
      ),
    );
  }
}

/// The head in a petrol circle with a paper frame, for a coloured ground: the
/// frame keeps the symbol apart from what is around it, and the two colours
/// are the same on every ground and in every theme.
class QuokkaHeadRound extends StatelessWidget {
  const QuokkaHeadRound({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.brandDeep,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.brandPaper, width: 3),
        ),
        child: QuokkaLogo.headOnDark(size: size * 0.7),
      ),
    );
  }
}

/// Only the name "Quokka" of the approved logo, in paper colour for the dark
/// brand ground: the full logo image cropped to the band with the lettering,
/// so it always matches the logo (no second drawing of the name).
class QuokkaWordmark extends StatelessWidget {
  const QuokkaWordmark.onDark({super.key, this.width = 180});

  /// Width of the lettering.
  final double width;

  // Where the lettering sits in the square logo image (fractions of its side):
  // from 71.2% down to 93% down (the chin of the head ends at ~70.7%, the
  // lettering starts at ~71.7% and its lowest stroke is at ~91%), 12% to 88%
  // across.
  static const _top = 0.712;
  static const _bottom = 0.93;
  static const _left = 0.12;
  static const _right = 0.88;

  @override
  Widget build(BuildContext context) {
    const bandHeight = _bottom - _top;
    const bandWidth = _right - _left;
    final side = width / bandWidth;
    return ExcludeSemantics(
      child: ClipRect(
        child: SizedBox(
          width: width,
          height: side * bandHeight,
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: side,
            maxWidth: side,
            minHeight: side,
            maxHeight: side,
            child: Transform.translate(
              offset: Offset(-side * _left, -side * _top),
              child: Image.asset(
                'assets/brand/quokka_logo_paper.png',
                width: side,
                height: side,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) => SizedBox(width: side, height: side),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
