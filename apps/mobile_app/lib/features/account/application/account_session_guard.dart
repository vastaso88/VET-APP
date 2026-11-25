import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/router/app_router.dart';
import '../../auth/data/auth_repository_factory.dart';
import '../../notifications/application/notification_scheduler.dart';
import '../../pets/data/pet_photo_repository.dart';
import '../data/account_session_remote_data_source.dart';
import '../data/device_registry.dart';
import '../data/profile_photo_repository.dart';

/// What the app does when the backend says the account was put in deletion from ANOTHER
/// device: nothing of it may keep running here.

/// What the backend said about this account when the app asked.
enum SessionOutcome {
  /// Usable: nothing to do.
  ok,

  /// Waiting to be erased: local notices and caches already cleared; the caller
  /// goes on to the page that cancels the deletion or erases at once.
  deactivated,
}

/// Called when the app opens or comes back to the front.
///
/// - `account_deactivated`: clears the notices and the caches but stays signed in: the next
///   step offers the page that cancels the deletion or erases at once, and a sign-out here
///   would make it unreachable.
Future<SessionOutcome> checkAccountSession(
  BuildContext context, {
  AccountSessionRemoteDataSource? dataSource,
  Future<void> Function()? clearLocalTraces,
}) async {
  final clear = clearLocalTraces ?? _clearLocalAccountTraces;
  final result = await (dataSource ?? HttpAccountSessionRemoteDataSource()).checkSession();
  if (!context.mounted) return SessionOutcome.ok;
  final code = result.fold(onSuccess: (_) => null, onFailure: (error) => error.code);
  if (code == kAccountDeactivatedCode) {
    await clear();
    return SessionOutcome.deactivated;
  }
  return SessionOutcome.ok;
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
