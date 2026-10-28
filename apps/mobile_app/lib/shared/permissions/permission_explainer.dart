import 'package:flutter/material.dart';

import '../../app/launch/warm_start_store.dart';
import '../../app/router/app_router.dart';
import '../../l10n/l10n.dart';

/// What the phone is about to be asked for (or, for the picker flows, what is
/// about to open). Each one has the same three texts: the title, why Quokka
/// needs it, and what happens if the owner says no.
enum PermissionPurpose {
  /// Position while the app is open or a walk is running.
  location,

  /// Reminders that ring.
  notifications,

  /// The ongoing notification of a walk in progress.
  walkNotifications,

  /// Dictating chat messages.
  microphone,

  /// The phone's own camera app, through the system picker: no permission is
  /// asked by Quokka, the text only says what is about to happen.
  camera,

  /// The phone gallery, through the system picker (same: no permission).
  gallery;

  /// True when the system itself shows a permission dialog afterwards; the
  /// picker flows ([camera], [gallery]) never do.
  bool get hasSystemDialog => switch (this) {
        camera || gallery => false,
        _ => true,
      };

  String title(AppLocalizations l10n) => switch (this) {
        location => l10n.permLocationTitle,
        notifications => l10n.permNotificationsTitle,
        walkNotifications => l10n.permWalkNotificationsTitle,
        microphone => l10n.permMicrophoneTitle,
        camera => l10n.permCameraTitle,
        gallery => l10n.permGalleryTitle,
      };

  String why(AppLocalizations l10n) => switch (this) {
        location => l10n.permLocationWhy,
        notifications => l10n.permNotificationsWhy,
        walkNotifications => l10n.permWalkNotificationsWhy,
        microphone => l10n.permMicrophoneWhy,
        camera => l10n.permCameraWhy,
        gallery => l10n.permGalleryWhy,
      };

  String ifRefused(AppLocalizations l10n) => switch (this) {
        location => l10n.permLocationRefuse,
        notifications => l10n.permNotificationsRefuse,
        walkNotifications => l10n.permWalkNotificationsRefuse,
        microphone => l10n.permMicrophoneRefuse,
        camera => l10n.permCameraRefuse,
        gallery => l10n.permGalleryRefuse,
      };
}

/// The short window shown BEFORE the system permission dialog: in plain words
/// why Quokka needs it and what happens if the owner refuses, with "Non ora" and
/// "Continua". Returns true on "Continua" (go on and ask), false otherwise.
///
/// The picker flows ([PermissionPurpose.camera], [PermissionPurpose.gallery])
/// have no system dialog; for them the window appears once per phone
/// ([onlyFirstTime]) so it explains without becoming a toll on every photo.
Future<bool> explainPermission(
  BuildContext context,
  PermissionPurpose purpose, {
  bool onlyFirstTime = false,
  WarmStartStore store = const WarmStartStore(),
}) async {
  final key = 'permission_explained.${purpose.name}';
  if (onlyFirstTime && await store.loadDraft(key) != null) return true;
  if (!context.mounted) return false;

  final proceed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final l10n = dialogContext.l10n;
      return AlertDialog(
        // Title and text scroll together: a long German text at a large system
        // text size must never overflow a small phone.
        scrollable: true,
        title: Text(purpose.title(l10n)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(purpose.why(l10n)),
            const SizedBox(height: 12),
            Text(purpose.ifRefused(l10n)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.permNotNow),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.permContinue),
          ),
        ],
      );
    },
  );

  if (proceed == true && onlyFirstTime) {
    // Remembered only on "Continua": "Non ora" may ask again next time.
    await store.saveDraft(key, '1');
  }
  return proceed ?? false;
}

/// [explainPermission] for code with no BuildContext of its own (the position
/// service, the voice recorder): uses the app's navigator. When there is no
/// navigator to show it on the flow just goes on - an explanation must never
/// be what blocks a request.
Future<bool> explainPermissionGlobally(
  PermissionPurpose purpose, {
  bool onlyFirstTime = false,
}) async {
  final BuildContext? context;
  try {
    context = AppRouter.navigatorKey.currentContext;
  } catch (_) {
    // No Flutter binding yet (plain unit tests): nothing to show it on.
    return true;
  }
  if (context == null || !context.mounted) return true;
  return explainPermission(context, purpose, onlyFirstTime: onlyFirstTime);
}
