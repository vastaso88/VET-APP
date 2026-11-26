import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../pets/domain/pet_models.dart';
import '../../../pets/presentation/widgets/pet_avatar.dart';
import '../../../pets/presentation/widgets/pet_picker.dart';
import '../../../pets/presentation/widgets/species_figure.dart';
import 'home_dashboard_primitives.dart';
import 'home_surface.dart';

/// "I tuoi animali": the first thing on Home. One small card per animal (those
/// in Ricordi are not here) and the dashed "Aggiungi"; sideways when they do
/// not fit. Without animals, what there is to say instead.
class HomePetsSection extends StatelessWidget {
  const HomePetsSection({
    super.key,
    required this.pets,
    required this.loading,
    required this.failed,
    required this.onlyMemories,
    required this.onOpenPet,
    required this.onAdd,
    required this.onRetry,
  });

  final List<PetProfile> pets;

  /// Still being read, with nothing to show yet.
  final bool loading;

  /// The last read failed, with nothing to show.
  final bool failed;

  /// No animal here, but at least one in Ricordi: no push to add another.
  final bool onlyMemories;

  final ValueChanged<PetProfile> onOpenPet;
  final VoidCallback onAdd;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DashboardSectionHeader(title: context.l10n.aroundWorldMyPets),
        const SizedBox(height: AppSpacing.sm),
        if (pets.isNotEmpty)
          _PetCards(pets: pets, onOpenPet: onOpenPet, onAdd: onAdd)
        else if (loading)
          const HomeSectionLoader()
        else if (failed)
          HomeSectionNotice(
            text: Text(context.l10n.petsListErrorDefault, style: AppTextStyles.bodySmall),
            action: TextButton.icon(
              key: const ValueKey('home-pets-retry'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(context.l10n.commonRetry),
            ),
          )
        else
          _NoPets(onlyMemories: onlyMemories, onAdd: onAdd),
      ],
    );
  }
}

class _PetCards extends StatelessWidget {
  const _PetCards({required this.pets, required this.onOpenPet, required this.onAdd});

  final List<PetProfile> pets;
  final ValueChanged<PetProfile> onOpenPet;
  final VoidCallback onAdd;

  static const _gap = AppSpacing.sm;

  @override
  Widget build(BuildContext context) {
    final count = pets.length + 1;
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        // Up to three cards fill the line, as drawn. More than three scroll
        // sideways, with the next one peeking in; never narrower than a word.
        final third = (available - 2 * _gap) / 3;
        final peeking = math.max(
          (available - 3 * _gap) / 3.3,
          MediaQuery.textScalerOf(context).scale(13) * 6.2,
        );
        final width = math.min(count <= 3 ? third : peeking, 168.0);
        final cards = IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final pet in pets) ...[
                SizedBox(
                  width: width,
                  child: _PetCard(
                    key: ValueKey('home-pet-${pet.id}'),
                    pet: pet,
                    onTap: () => onOpenPet(pet),
                  ),
                ),
                const SizedBox(width: _gap),
              ],
              SizedBox(width: width, child: _AddCard(onTap: onAdd)),
            ],
          ),
        );
        if (count * width + (count - 1) * _gap <= available + 0.5) {
          return Align(alignment: AlignmentDirectional.centerStart, child: cards);
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: cards,
        );
      },
    );
  }
}

/// Side of the picture in a card, scaled to the screen by [PetRingAvatar].
const _faceSize = 48.0;

class _PetCard extends StatelessWidget {
  const _PetCard({super.key, required this.pet, required this.onTap});

  final PetProfile pet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final line = petShortLine(pet);
    return Semantics(
      button: true,
      label: '${pet.name}, $line',
      excludeSemantics: true,
      onTap: onTap,
      child: HomeCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: AppSpacing.md),
        child: Column(
          children: [
            PetRingAvatar(pet: pet, size: _faceSize),
            const SizedBox(height: 6),
            Text(
              pet.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTextStyles.title.copyWith(fontSize: 14),
            ),
            Text(
              line,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(fontSize: 13, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddCard extends StatelessWidget {
  const _AddCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.petsListEmptyOnlyMemoriesAction,
      excludeSemantics: true,
      onTap: onTap,
      child: AppCard(
        key: const ValueKey('home-add-pet'),
        dashed: true,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.md,
        ),
        child: Column(
          children: [
            Container(
              width: petRingAvatarExtent(context, _faceSize),
              height: petRingAvatarExtent(context, _faceSize),
              decoration: BoxDecoration(
                color: AppColors.secondarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add_rounded, color: AppColors.primary),
            ),
            const SizedBox(height: 6),
            // One word in a narrow card ("Hinzufügen"): it shrinks a little
            // rather than breaking in the middle.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                context.l10n.commonAdd,
                maxLines: 1,
                style: AppTextStyles.bodySmall.copyWith(fontSize: 13, height: 1.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// No animal here. For an owner whose animals are all in Ricordi the wording is
/// the soft one of the Animali page: nothing is asked of them.
class _NoPets extends StatelessWidget {
  const _NoPets({required this.onlyMemories, required this.onAdd});

  final bool onlyMemories;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return HomeCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          if (!onlyMemories) ...[
            SpeciesFigure(species: 'Altro', size: petRingAvatarExtent(context, _faceSize)),
            const SizedBox(height: AppSpacing.md),
          ],
          Text(
            onlyMemories ? l10n.petsListEmptyOnlyMemoriesTitle : l10n.petsListEmptyTitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.title.copyWith(fontSize: 17),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            onlyMemories ? l10n.petsListEmptyOnlyMemoriesSubtitle : l10n.petsListEmptySubtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          if (onlyMemories)
            TextButton(
              key: const ValueKey('home-add-pet'),
              onPressed: onAdd,
              child: Text(l10n.petsListEmptyOnlyMemoriesAction),
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('home-add-pet'),
                onPressed: onAdd,
                child: Text(l10n.petsListEmptyOnlyMemoriesAction, textAlign: TextAlign.center),
              ),
            ),
        ],
      ),
    );
  }
}
