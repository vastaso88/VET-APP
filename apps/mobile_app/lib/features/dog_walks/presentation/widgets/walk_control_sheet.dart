import 'package:flutter/material.dart';

import '../../../pets/domain/pet_models.dart';
import '../../data/active_walk_controller.dart';
import '../pages/active_walk_page.dart';
import '../walk_completion_flow.dart';

/// The "Fine passeggiata / Pausa / Apri passeggiata" sheet, opened by
/// tapping the shell's "Passeggiata in corso" banner (owner request,
/// 2026-09-30 - previously the banner navigated straight to the page;
/// pet_detail_page.dart's own status button does that now instead, so this
/// sheet moved here as the one place left that needs it).
Future<void> showWalkControlSheet(BuildContext context, {required PetProfile pet}) async {
  final walk = ActiveWalkController.instance.walk;
  if (walk == null) return;

  final action = await showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.map_outlined),
            title: const Text('Apri passeggiata'),
            onTap: () => Navigator.of(context).pop('open'),
          ),
          ListTile(
            leading: Icon(
              walk.isPaused ? Icons.play_circle_outline : Icons.pause_circle_outline,
            ),
            title: Text(walk.isPaused ? 'Riavvia' : 'Pausa'),
            onTap: () => Navigator.of(context).pop(walk.isPaused ? 'resume' : 'pause'),
          ),
          ListTile(
            leading: const Icon(Icons.stop_circle_outlined),
            title: const Text('Fine passeggiata'),
            onTap: () => Navigator.of(context).pop('finish'),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted) return;

  switch (action) {
    case 'open':
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<bool>(builder: (_) => ActiveWalkPage(pet: pet)),
      );
    case 'pause':
      await ActiveWalkController.instance.pause();
    case 'resume':
      await ActiveWalkController.instance.resume();
    case 'finish':
      await finishActiveWalk(context, pet);
  }
}
