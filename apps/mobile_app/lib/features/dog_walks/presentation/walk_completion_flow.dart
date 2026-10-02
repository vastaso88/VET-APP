import 'package:flutter/material.dart';

import '../../../shared/auth/current_owner.dart';
import '../../pets/domain/pet_models.dart';
import '../data/active_walk_controller.dart';
import '../data/dog_walks_repository.dart';
import '../domain/badges.dart';
import '../domain/walk_retention.dart';
import '../domain/walk_session.dart';
import 'walk_labels.dart';
import 'widgets/badge_earned_dialog.dart';
import 'widgets/favorite_eviction_dialog.dart';

/// Ends the active walk for [pet]: stops tracking, runs the badge-earned
/// celebration if anything newly unlocked, offers to save it as a
/// favorite, then prunes retention. Shared between ActiveWalkPage's
/// "Termina" button and pet_detail_page.dart's status sheet ("Fine
/// passeggiata") so both entry points behave identically (owner request,
/// 2026-09-30 - the sheet needed the exact same completion flow the page
/// already had, not a second copy of it).
Future<void> finishActiveWalk(BuildContext context, PetProfile pet) async {
  final repository = DogWalksRepository();
  final ownerId = resolveCurrentOwnerId();
  final beforeWalks =
      (await repository.loadWalks(ownerId)).where((walk) => walk.petId == pet.id).toList();
  final beforeBadges = evaluateBadges(beforeWalks).toSet();

  await ActiveWalkController.instance.stop();
  if (!context.mounted) return;

  final justStopped = ActiveWalkController.instance.walk;
  if (justStopped != null && justStopped.petId == pet.id && justStopped.distanceMeters <= 0) {
    // No point tracked far enough apart to register any distance - not a
    // real walk to keep (owner request, 2026-09-30). stop() already saved
    // it, so this is a delete, not a "never save" - same visible result.
    await repository.deleteWalk(ownerId, justStopped.id);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Passeggiata senza spostamento'),
        content: const Text(
          'Non è stato registrato alcuno spostamento: la passeggiata non è stata salvata.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Ho capito'),
          ),
        ],
      ),
    );
    return;
  }

  final afterWalks =
      (await repository.loadWalks(ownerId)).where((walk) => walk.petId == pet.id).toList();
  final afterBadges = evaluateBadges(afterWalks);
  final newlyEarned = afterBadges.where((badge) => !beforeBadges.contains(badge)).toList();

  if (!context.mounted) return;
  if (newlyEarned.isNotEmpty) {
    await showBadgeEarnedDialog(context, newlyEarned);
  }

  final finishedWalk = ActiveWalkController.instance.walk;
  if (finishedWalk != null && finishedWalk.petId == pet.id) {
    if (!context.mounted) return;
    await _promptSaveAsFavorite(context, repository, ownerId, pet.id, finishedWalk);
  }
  await repository.pruneRoutesOutsideRetention(ownerId, pet.id);
}

Future<void> _promptSaveAsFavorite(
  BuildContext context,
  DogWalksRepository repository,
  String ownerId,
  String petId,
  WalkSession walk,
) async {
  final wantsFavorite = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Salva tra le preferite?'),
      content: Text(
        'Vuoi aggiungere questa passeggiata (${walkDistanceLabel(walk.distanceMeters)}) '
        'alle tue preferite ⭐?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('No, grazie'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Salva ⭐'),
        ),
      ],
    ),
  );
  if (wantsFavorite != true) return;
  if (!context.mounted) return;

  final existingFavorites = (await repository.loadWalks(ownerId))
      .where((item) => item.petId == petId && item.isFavorite)
      .toList();

  if (existingFavorites.length >= maxFavoriteWalks) {
    if (!context.mounted) return;
    final walkIdToEvict = await pickFavoriteToEvict(context, existingFavorites);
    if (walkIdToEvict == null) return;
    final toEvict = existingFavorites.firstWhere((item) => item.id == walkIdToEvict);
    await repository.saveWalk(toEvict.copyWith(isFavorite: false));
  }

  await repository.saveWalk(walk.copyWith(isFavorite: true));
}
