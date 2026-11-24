import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/router/app_router.dart';
import '../../../l10n/date_formats.dart';
import '../../../l10n/l10n.dart';
import '../../../l10n/regional_defaults.dart';
import '../../auth/data/auth_repository_factory.dart';
import '../../notifications/application/notification_scheduler.dart';
import '../../pets/data/pet_photo_repository.dart';
import '../data/account_pause_remote_data_source.dart';
import '../data/device_registry.dart';
import '../data/profile_photo_repository.dart';

/// What the app does when the backend says the account was paused or put in
/// deletion from ANOTHER device: nothing of it may keep running here. Without
/// this the promise "no reminders or notifications" would hold only on the
/// phone that pressed the button.

/// What the backend said about this account when the app asked.
enum SessionOutcome {
  /// Usable: nothing to do.
  ok,

  /// Paused from another device: already cleared, signed out and sent to the
  /// sign-in page; the caller stops there.
  paused,

  /// Waiting to be erased: local notices and caches already cleared; the caller
  /// goes on to the page that cancels the deletion or erases at once.
  deactivated,
}

/// Called when the app opens or comes back to the front.
///
/// - `account_paused`: clears the local notices and caches, signs out and says
///   why. Signing in again ends the pause.
/// - `account_deactivated`: clears the notices and the caches but stays signed
///   in: the next step offers the page that cancels the deletion or erases at
///   once, and a sign-out here would make it unreachable.
Future<SessionOutcome> checkAccountSession(
  BuildContext context, {
  AccountPauseRemoteDataSource? dataSource,
  Future<void> Function()? clearLocalTraces,
  Future<void> Function()? signOut,
}) async {
  final clear = clearLocalTraces ?? _clearLocalAccountTraces;
  final result = await (dataSource ?? HttpAccountPauseRemoteDataSource()).checkSession();
  if (!context.mounted) return SessionOutcome.ok;
  final code = result.fold(onSuccess: (_) => null, onFailure: (error) => error.code);
  if (code == kAccountDeactivatedCode) {
    await clear();
    return SessionOutcome.deactivated;
  }
  if (code != kAccountPausedCode) return SessionOutcome.ok;

  final message = context.l10n.accountPausedElsewhere;
  await clear();
  await (signOut ?? () => const AuthRepositoryFactory().create().signOut())();
  if (!context.mounted) return SessionOutcome.paused;
  final navigator = Navigator.of(context, rootNavigator: true);
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  navigator.pushNamedAndRemoveUntil(AppRouter.auth, (route) => false);
  return SessionOutcome.paused;
}

/// Back in front with the app already open: is this phone still one of the places the plan
/// allows? When a newer device took its place, this one is signed out HERE, at once (not at the
/// next cold start), the local notices and caches are cleared, and the sign-in page says why and
/// what to do (the notice `authDeviceLimitNotice`: sign in again to take a place back). Returns
/// true when it was signed out. Fails open like the registry: no answer keeps the person in.
Future<bool> checkDeviceStillActive(
  BuildContext context, {
  DeviceRegistryClient? registry,
  Future<void> Function()? clearLocalTraces,
  Future<void> Function()? signOut,
}) async {
  final stillActive = await (registry ?? DeviceRegistry()).register(claim: false);
  if (stillActive || !context.mounted) return false;
  DeviceRegistry.pendingNotice = true;
  await (clearLocalTraces ?? _clearLocalAccountTraces)();
  await (signOut ?? () => const AuthRepositoryFactory().create().signOut())();
  if (!context.mounted) return true;
  Navigator.of(context, rootNavigator: true)
      .pushNamedAndRemoveUntil(AppRouter.auth, (route) => false);
  return true;
}

Future<void> _clearLocalAccountTraces() async {
  unawaited(NotificationScheduler.instance.clearAll());
  unawaited(PetPhotoRepository.clearLocalCaches());
  ProfilePhotoRepository.clearLocalCache();
}

/// After a sign-in: says once that the pause is over and, for an account
/// without a plan, the new day its data would be erased. Then tells the
/// backend it was shown (so it is not said again).
Future<void> showPauseEndedIfAny(
  BuildContext context, {
  AccountPauseRemoteDataSource? dataSource,
}) async {
  final source = dataSource ?? HttpAccountPauseRemoteDataSource();
  final result = await source.fetchNotice();
  if (!context.mounted) return;
  final notice = result.fold(onSuccess: (value) => value, onFailure: (_) => null);
  if (notice == null) return;

  final l10n = context.l10n;
  final until = notice.dataKeptUntil;
  final lines = [
    l10n.accountPauseEndedBody,
    if (!notice.hasAccess && until != null)
      l10n.accountPauseEndedNoPlan(formatAppDate(until, appNumericDatePattern())),
  ];
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.accountPauseEndedTitle),
      content: Text(lines.join('\n\n')),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          style: FilledButton.styleFrom(minimumSize: Size.zero),
          child: Text(l10n.commonOk),
        ),
      ],
    ),
  );
  // Shown: the backend can forget it. A failure here only means it is said again.
  unawaited(source.acknowledgeNotice());
}
