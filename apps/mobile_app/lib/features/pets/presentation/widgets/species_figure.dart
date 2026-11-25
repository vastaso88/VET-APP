import 'package:flutter/material.dart';

import '../../../../design_system/atoms/animal_figure.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../domain/pet_details.dart';

/// The flat figure of a kind of animal: the only one the app shows for it, on
/// every page. It stands in for a missing photo and goes next to a story or the
/// name of a species. An animal without a drawing gets the neutral paw.
class SpeciesFigure extends StatelessWidget {
  /// On its own pale round ground, [size] wide.
  const SpeciesFigure({super.key, required this.species, this.breed, required this.size})
      : color = null;

  /// Only the figure, in one colour: inside a pill, next to its text.
  const SpeciesFigure.glyph({
    super.key,
    required this.species,
    required this.size,
    required Color this.color,
  }) : breed = null;

  /// The stored species ("Cane", "Piccoli mammiferi"...), or a news category.
  final String species;
  final String? breed;

  /// Side of the (already scaled) square the figure fills.
  final double size;

  final Color? color;

  static AnimalFigure figureFor(String species, [String? breed]) =>
      switch (petKindOf(species, breed)) {
        PetKind.dog => AnimalFigure.dog,
        PetKind.cat => AnimalFigure.cat,
        PetKind.rabbit => AnimalFigure.rabbit,
        PetKind.smallMammal => AnimalFigure.smallMammal,
        PetKind.bird => AnimalFigure.bird,
        PetKind.reptile => AnimalFigure.reptile,
        PetKind.fish => AnimalFigure.fish,
        PetKind.amphibian ||
        PetKind.largeMammal ||
        PetKind.invertebrate ||
        PetKind.unknown =>
          AnimalFigure.paw,
      };

  /// The two colours of a figure (contrast: scripts/design/contrast_check.py).
  static ({Color ground, Color ink}) colorsOf(AnimalFigure figure) => switch (figure) {
        AnimalFigure.dog ||
        AnimalFigure.cat ||
        AnimalFigure.rabbit ||
        AnimalFigure.smallMammal =>
          (ground: AppColors.warningSoft, ink: AppColors.warningStrong),
        AnimalFigure.bird => (ground: AppColors.infoSoft, ink: AppColors.infoStrong),
        AnimalFigure.fish => (ground: AppColors.primarySoft, ink: AppColors.primary),
        AnimalFigure.reptile ||
        AnimalFigure.paw =>
          (ground: AppColors.secondarySoft, ink: AppColors.secondaryStrong),
      };

  @override
  Widget build(BuildContext context) {
    final figure = figureFor(species, breed);
    if (color case final color?) return AnimalFigureIcon(figure, size: size, color: color);
    final (:ground, :ink) = colorsOf(figure);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: ground, shape: BoxShape.circle),
      child: AnimalFigureIcon(
        figure,
        size: size * 0.7,
        color: ink,
        accent: AppColors.warningStrong,
      ),
    );
  }
}
