import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/pet_loader.dart';
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
            title: Text(context.l10n.walksSheetOpen),
            onTap: () => Navigator.of(context).pop('open'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(context.l10n.walksCaptureTakePhoto),
            onTap: () => Navigator.of(context).pop('photo'),
          ),
          ListTile(
            leading: const Icon(Icons.videocam_outlined),
            title: Text(context.l10n.walksCaptureRecordVideo),
            onTap: () => Navigator.of(context).pop('video'),
          ),
          ListTile(
            leading: Icon(
              walk.isPaused ? Icons.play_circle_outline : Icons.pause_circle_outline,
            ),
            title: Text(
              walk.isPaused ? context.l10n.walksActionResume : context.l10n.walksActionPause,
            ),
            onTap: () => Navigator.of(context).pop(walk.isPaused ? 'resume' : 'pause'),
          ),
          ListTile(
            leading: const Icon(Icons.stop_circle_outlined),
            title: Text(context.l10n.walksSheetFinish),
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
    // Photo and video open the walk page, which owns the camera flow and the
    // progress (and shows the new photo on the map).
    case 'photo' || 'video':
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<bool>(
          builder: (_) => ActiveWalkPage(
            pet: pet,
            autoCapture: action == 'photo' ? WalkCaptureKind.photo : WalkCaptureKind.video,
          ),
        ),
      );
    case 'pause':
      await ActiveWalkController.instance.pause();
    case 'resume':
      await ActiveWalkController.instance.resume();
    case 'finish':
      await _finishWithProgress(context, pet);
  }
}

/// "Termina" on the walk notification (WalkTrackingService.kt): the app
/// opens and asks first - a tap in the shade is easy to make by mistake,
/// and ending a walk can't be undone.
Future<void> confirmAndFinishWalk(BuildContext context, {required PetProfile pet}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(dialogContext.l10n.walksConfirmFinishTitle(pet.name)),
      content: Text(dialogContext.l10n.walksConfirmFinishBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(dialogContext.l10n.commonContinue),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(dialogContext.l10n.walksActionFinish),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  await _finishWithProgress(context, pet);
}

Future<void> _finishWithProgress(BuildContext context, PetProfile pet) async {
  // The sheet is gone and saving can take seconds: say so meanwhile.
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    SnackBar(
      duration: const Duration(minutes: 1),
      content: Row(
        children: [
          const PetLoader.small(),
          const SizedBox(width: 12),
          Text(context.l10n.walksSavingSnackbar),
        ],
      ),
    ),
  );
  try {
    await finishActiveWalk(context, pet, onSaved: messenger.hideCurrentSnackBar);
  } finally {
    messenger.hideCurrentSnackBar();
  }
}
