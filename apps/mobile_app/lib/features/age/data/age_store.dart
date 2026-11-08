import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/types/result.dart';
import '../domain/age_status.dart';
import 'account_age_remote_data_source.dart';

/// What the app knows about the owner's declared age, shared by the screens
/// that depend on it (sign-in prompt, Mercatino, plans, closed account).
///
/// The date itself is only ever held for a moment: while it is typed, and - if
/// the account could not be written to yet (registration with e-mail
/// confirmation, no session) - as one pending value on the phone until the
/// first signed-in start sends it. It is wiped on sign-out.
class AgeStore extends ChangeNotifier {
  AgeStore._({AccountAgeRemoteDataSource? dataSource})
      : _dataSource = dataSource ?? HttpAccountAgeRemoteDataSource();

  static AgeStore instance = AgeStore._();

  /// Tests swap the store (and so the backend it talks to).
  @visibleForTesting
  static void useForTest(AccountAgeRemoteDataSource dataSource) {
    instance = AgeStore._(dataSource: dataSource);
  }

  @visibleForTesting
  static void restoreDefault() => instance = AgeStore._();

  static const _pendingKey = 'vet_app.pending_birth_date';

  final AccountAgeRemoteDataSource _dataSource;

  AgeStatus _status = const AgeStatus.unknown();
  AgeStatus get status => _status;

  /// True once the backend answered at least once in this run.
  bool _loaded = false;
  bool get loaded => _loaded;

  /// The "declare your date" prompt is shown once per run when the owner
  /// chooses "later".
  bool promptDismissed = false;

  /// Reads the status; sends a pending date first, if there is one.
  /// Returns the status, or null if the backend could not be reached.
  Future<AgeStatus?> refresh() async {
    await submitPending();
    final result = await _dataSource.fetch();
    return result.fold(
      onSuccess: (status) {
        _set(status);
        return status;
      },
      onFailure: (error) {
        _noteClosed(error.code);
        return null;
      },
    );
  }

  /// Declares the date. On success the new status is kept.
  Future<Result<AgeStatus>> declare(DateTime birthDate) async {
    final result = await _dataSource.declare(birthDate);
    result.fold(onSuccess: _set, onFailure: (error) => _noteClosed(error.code));
    return result;
  }

  Future<Result<AgeStatus>> confirmGuardian() async {
    final result = await _dataSource.confirmGuardian();
    result.fold(onSuccess: _set, onFailure: (error) => _noteClosed(error.code));
    return result;
  }

  /// Keeps a date typed at registration until a session exists to send it.
  Future<void> rememberPending(DateTime birthDate) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_pendingKey, birthDate.toIso8601String().substring(0, 10));
    } catch (_) {}
  }

  /// Sends a pending date, if any, then forgets it (also when the backend says
  /// a date was declared already). Quietly does nothing on a network failure:
  /// it will be tried again.
  Future<void> submitPending() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_pendingKey);
      if (raw == null) return;
      final date = DateTime.tryParse(raw);
      if (date == null) {
        await preferences.remove(_pendingKey);
        return;
      }
      final result = await _dataSource.declare(date);
      final sent = result.fold(
        onSuccess: (status) {
          _set(status);
          return true;
        },
        onFailure: (error) =>
            error.code == 'age_already_declared' || error.code == kUnderMinimumAgeCode,
      );
      if (sent) await preferences.remove(_pendingKey);
    } catch (_) {}
  }

  /// Sign-out: nothing of this account stays.
  Future<void> reset() async {
    _status = const AgeStatus.unknown();
    _loaded = false;
    promptDismissed = false;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_pendingKey);
    } catch (_) {}
    notifyListeners();
  }

  void _set(AgeStatus status) {
    _status = status;
    _loaded = true;
    notifyListeners();
  }

  /// Any route answers `under_minimum_age` for a closed account.
  void _noteClosed(String code) {
    if (code == kUnderMinimumAgeCode) {
      _set(const AgeStatus(
        band: AgeBand.underMinimum,
        marketplaceAllowed: false,
        guardianRequired: false,
        guardianConfirmed: false,
        paidPlanAllowed: false,
      ));
    }
  }
}
