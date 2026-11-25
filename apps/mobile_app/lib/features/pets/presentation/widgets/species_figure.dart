import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../data/pet_demo_store.dart';
import '../../domain/pet_details.dart';

/// The simple figure of a kind of animal on its own pale tint: it stands in for
/// a missing photo and goes next to a story. Only figures the app already shows
/// (those of the species choice and of the loader); an animal the app cannot
/// place gets the flat paw.
class SpeciesFigure extends StatelessWidget {
  const SpeciesFigure({super.key, required this.species, this.breed, required this.size});

  /// The stored species ("Cane", "Piccoli mammiferi"...), or a news category.
  final String species;
  final String? breed;

  /// Side of the (already scaled) square the figure fills.
  final double size;

  /// The figure, or null when only the paw is right.
  static String? emojiFor(String species, [String? breed]) {
    String of(String category) => PetDemoStore.optionForSpecies(category).avatarEmoji;
    return switch (petKindOf(species, breed)) {
      PetKind.rabbit => '🐰',
      // A hen is stored under "Altro": still a bird.
      PetKind.bird => of('Uccello'),
      PetKind.dog || PetKind.cat || PetKind.smallMammal || PetKind.reptile || PetKind.fish =>
        of(species),
      PetKind.amphibian || PetKind.largeMammal || PetKind.invertebrate || PetKind.unknown => null,
    };
  }

  /// The pale ground: the species' own tint, sage when it is not a species.
  static Color tintFor(String species) {
    final normalized = species.trim().toLowerCase();
    for (final option in PetDemoStore.speciesOptions) {
      if (option.label.toLowerCase() == normalized) return option.accentColor;
    }
    return AppColors.secondarySoft;
  }

  @override
  Widget build(BuildContext context) {
    final emoji = emojiFor(species, breed);
    return ExcludeSemantics(
      child: ColoredBox(
        color: tintFor(species),
        child: SizedBox.square(
          dimension: size,
          child: Center(
            child: emoji == null
                ? Icon(Icons.pets_rounded, size: size * 0.54, color: AppColors.secondaryStrong)
                : Text(
                    emoji,
                    // The square is already scaled to the screen: the phone's
                    // text size must not push the figure out of it.
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(fontSize: size * 0.56, height: 1.2),
                  ),
          ),
        ),
      ),
    );
  }
}
