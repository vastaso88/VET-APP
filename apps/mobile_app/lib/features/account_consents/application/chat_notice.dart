import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/router/app_router.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/config/app_runtime_config_loader.dart';
import '../data/account_consents_remote_data_source.dart';
import '../domain/account_consent_models.dart';
import '../presentation/pages/emergency_notice_gate_page.dart';

/// The acknowledgement that Quokka does not handle emergencies, asked once, when the first
/// chat is opened (owner decision of 24 November 2026): it is a condition of the CHAT only.
/// The rest of the app never waits for it, and a server that does not know it yet, or that
/// cannot be reached, never keeps the owner out: the acceptance stays on the phone and is
/// sent again later.
class ChatNotice {
  const ChatNotice._();

  static const _acceptedKey = 'vet_app.chat_notice_accepted';
  static const _pendingKey = 'vet_app.chat_notice_pending';

  /// The longest the chat waits for the server before going on.
  static const serverWait = Duration(seconds: 6);

  /// True when the chat may be used: accepted before (here or on another phone) or now.
  /// With no server (the demo) there is nothing to ask.
  static Future<bool> ensure(
    BuildContext context, {
    AccountConsentsRemoteDataSource? dataSource,
  }) async {
    if (dataSource == null && !const AppRuntimeConfigLoader().load().hasApiBaseUrl) return true;
    if (await _acceptedHere()) return true;
    if (!context.mounted) return false;
    final source = dataSource ?? HttpAccountConsentsRemoteDataSource();
    final snapshot = await _read(source);
    if (!context.mounted) return false;
    if (snapshot != null && acceptedOnServer(snapshot)) {
      await _remember(pending: false);
      return true;
    }
    final accepted = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) => const EmergencyNoticeGatePage(),
      ),
    );
    if (accepted != true) {
      AppRouter.scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(appL10n.emergencyNoticeDeclineTitle)),
      );
      return false;
    }
    await _remember(pending: true);
    await submitPending(source).timeout(serverWait, onTimeout: () {});
    return true;
  }

  static bool acceptedOnServer(AccountConsentsSnapshot snapshot) {
    final decision = snapshot.decisions[AccountConsentKeys.emergencyNotice];
    final current = snapshot.catalog[AccountConsentKeys.emergencyNotice]?.version ??
        AccountConsentKeys.emergencyNoticeVersion;
    return decision != null && decision.granted && decision.version == current;
  }

  /// Sends an acceptance the server has not recorded yet, if there is one.
  static Future<void> submitPending(AccountConsentsRemoteDataSource source) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (preferences.getBool(_pendingKey) != true) return;
      final result = await source.setConsent(
        consentKey: AccountConsentKeys.emergencyNotice,
        granted: true,
      );
      if (result.isSuccess) await preferences.remove(_pendingKey);
    } catch (_) {}
  }

  /// Sign-out: nothing of this account stays.
  static Future<void> clear() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_acceptedKey);
      await preferences.remove(_pendingKey);
    } catch (_) {}
  }

  static Future<AccountConsentsSnapshot?> _read(AccountConsentsRemoteDataSource source) async {
    try {
      final result = await source.fetch().timeout(serverWait);
      return result.fold(onSuccess: (value) => value, onFailure: (_) => null);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> _acceptedHere() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      return preferences.getString(_acceptedKey) == AccountConsentKeys.emergencyNoticeVersion;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _remember({required bool pending}) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_acceptedKey, AccountConsentKeys.emergencyNoticeVersion);
      if (pending) {
        await preferences.setBool(_pendingKey, true);
      } else {
        await preferences.remove(_pendingKey);
      }
    } catch (_) {}
  }
}
