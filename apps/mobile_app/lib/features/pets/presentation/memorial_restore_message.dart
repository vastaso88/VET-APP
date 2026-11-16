import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../application/memorial_service.dart';

/// What the owner is told when a pet cannot come back from Ricordi because the
/// plan has no free place: first that the pet stays in Ricordi and nothing is
/// lost, then why, then the way out (free a place or, when there is one, the plan
/// above, with the same weight). No purchase is offered here.
String memorialRestoreBlockedText(
  AppLocalizations l10n,
  String petName,
  PetLimitBlocksRestore blocked,
) {
  final plan = blocked.upgradePlan;
  return plan == null
      ? l10n.memorialRestoreBlockedFull(petName, blocked.limit)
      : l10n.memorialRestoreBlockedUpgrade(petName, blocked.limit, plan);
}

/// What the owner is told when a pet cannot be moved to Ricordi because Ricordi
/// already holds as many as it may (owner decision 2026-11-16): kindly, that the
/// pet stays where it is, nothing is lost, and that a place frees up by deleting
/// one of the pets already in Ricordi.
String memorialMoveBlockedText(
  AppLocalizations l10n,
  String petName,
  MemoriesFullBlocksMove blocked,
) =>
    l10n.memorialMoveBlockedFull(petName, blocked.limit);

/// The message as a dialog with one button: it is long, and a snackbar would
/// vanish before it can be read.
Future<void> showMemorialRestoreBlocked(
  BuildContext context,
  String petName,
  PetLimitBlocksRestore blocked,
) =>
    _showOkDialog(
      context,
      const ValueKey('memorial-restore-blocked'),
      memorialRestoreBlockedText(context.l10n, petName, blocked),
    );

/// Same for a move that Ricordi cannot take.
Future<void> showMemorialMoveBlocked(
  BuildContext context,
  String petName,
  MemoriesFullBlocksMove blocked,
) =>
    _showOkDialog(
      context,
      const ValueKey('memorial-move-blocked'),
      memorialMoveBlockedText(context.l10n, petName, blocked),
    );

Future<void> _showOkDialog(BuildContext context, Key key, String text) {
  final l10n = context.l10n;
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: key,
      content: Text(text),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.commonOk),
        ),
      ],
    ),
  );
}
