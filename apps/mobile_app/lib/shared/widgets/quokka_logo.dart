import 'package:flutter/material.dart';

/// The Quokka logo (approved 2026-11-04). [QuokkaLogo.full] is the head with
/// the name under it, [QuokkaLogo.head] the head alone for small places.
/// Decorative: the app name is always written next to it where it matters.
class QuokkaLogo extends StatelessWidget {
  const QuokkaLogo.full({super.key, this.size = 160}) : _asset = 'assets/brand/quokka_logo.png';

  const QuokkaLogo.head({super.key, this.size = 40}) : _asset = 'assets/brand/quokka_head.png';

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
