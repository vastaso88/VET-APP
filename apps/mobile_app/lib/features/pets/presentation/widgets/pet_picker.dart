import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../domain/pet_models.dart';
import 'pet_avatar.dart';

/// Breed (or species of a small animal) when the owner gave one, else the kind
/// of animal. The scientific name in brackets stays out of a line this short.
String petShortLine(PetProfile pet) {
  final breed = pet.breed.split(' (').first.trim();
  if (pet.isAquarium || breed.isEmpty || breed == 'Altro') {
    return pet.speciesDisplayLabel;
  }
  return breed;
}

/// Asks "which animal?", each with its face; null when the owner goes back.
Future<PetProfile?> showPetPicker(BuildContext context, List<PetProfile> pets) {
  return showDialog<PetProfile>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: Text(dialogContext.l10n.remindersChoosePet),
      children: [
        for (final pet in pets)
          SimpleDialogOption(
            key: ValueKey('pick-pet-${pet.id}'),
            onPressed: () => Navigator.of(dialogContext).pop(pet),
            child: Row(
              children: [
                PetRingAvatar(pet: pet, size: 36),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pet.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.title.copyWith(fontSize: 15),
                      ),
                      // Two animals may have the same name.
                      Text(
                        petShortLine(pet),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
