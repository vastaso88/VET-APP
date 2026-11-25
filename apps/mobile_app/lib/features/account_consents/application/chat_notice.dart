import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/router/app_router.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/config/app_runtime_config_loader.dart';
import '../data/account_consents_remote_data_source.dart';
import '../domain/account_consent_models.dart';
import '../presentation/pages/emergency_notice_gate_page.dart';

/// The one screen of the first chat (owner decisions of 24 and 25 November 2026). It holds two
/// things:
///
/// * the acknowledgement that Quokka does not handle emergencies, with its own box, recorded on
///   the server with the version of the text that was shown;
/// * who answers: an AI, and the provider the questions go to. A notice without a version, kept
///   on this phone only ([_providerKey]): everybody sees the screen once, also who had already
///   acknowledged the emergencies (on this phone or on another one).
///
/// It is a condition of the CHAT only. The rest of the app never waits for it, and a server that
/// does not know the acknowledgement (or its version) yet, or that cannot be reached, never keeps
/// the owner out of the app or of the chat: the acceptance stays on the phone, with the version
/// of the text that was shown, and is sent again later.
class ChatNotice {
  const ChatNotice._();

  /// The version accepted on this phone.
  static const _acceptedKey = 'vet_app.chat_notice_accepted';

  /// The version of the text that was shown when the acceptance could not be sent yet: that
  /// one is sent again, never the version of today.
  static const _pendingKey = 'vet_app.chat_notice_pending_version';

  static const _pendingKeyBuild44 = 'vet_app.chat_notice_pending';

  /// The screen that names the AI provider was accepted on this phone. Another provider is
  /// another key: the screen then comes back once to everybody.
  static const _providerKey = 'vet_app.chat_ai_provider';

  static DateTime? _lastRecheck;

  /// The longest the chat waits for the server before going on.
  static const serverWait = Duration(seconds: 6);

  /// True when the chat may be used: the screen was accepted on this phone, before or now. With
  /// no server (the demo) there is nothing to ask.
  ///
  /// Emergencies acknowledged here and provider seen: nothing is shown, nothing is waited for.
  /// Otherwise the screen is shown; what its "Accetto" does depends on the emergencies:
  ///
  /// * already acknowledged, here or on the server, for the text on the screen: nothing is sent
  ///   again, only the provider is marked as seen;
  /// * else: the acceptance is recorded with the version shown, now or later.
  static Future<bool> ensure(
    BuildContext context, {
    AccountConsentsRemoteDataSource? dataSource,
  }) async {
    if (dataSource == null && !const AppRuntimeConfigLoader().load().hasApiBaseUrl) return true;
    final source = dataSource ?? HttpAccountConsentsRemoteDataSource();
    final here = await _acceptedHere();
    final providerSeen = await _providerSeen();
    if (here != null && providerSeen) {
      _recheckBehind(source, here);
      return true;
    }
    if (!context.mounted) return false;
    // Acknowledged on this phone, with the text this app shows: only the provider is new, no
    // need to wait for the server.
    final snapshot =
        here == AccountConsentKeys.emergencyNoticeVersion ? null : await _read(source);
    if (!context.mounted) return false;
    final entry = snapshot?.catalog[AccountConsentKeys.emergencyNotice];
    final onServer = snapshot != null && acceptedOnServer(snapshot)
        ? snapshot.decisions[AccountConsentKeys.emergencyNotice]?.version
        : null;
    if (onServer != null && onServer != here) await _remember(onServer, pending: false);
    if (onServer != null && providerSeen) return true;
    if (!context.mounted) return false;
    // With a server that could not be read, what was acknowledged here still counts.
    final acknowledged =
        onServer != null || (here != null && (entry == null || entry.version == here));
    if (!acknowledged) return _askAndRecord(context, source, entry);
    if (!await _ask(context, entry)) return false;
    await _rememberProvider();
    if (here != null && snapshot == null) _recheckBehind(source, here);
    return true;
  }

  /// Shows the screen, with the emergencies' text of the catalog when it is newer than the app's
  /// own. False, and said so, when it was not accepted: only the chat closes.
  static Future<bool> _ask(BuildContext context, ConsentCatalogEntry? entry) async {
    final newerText = entry != null && entry.version != AccountConsentKeys.emergencyNoticeVersion
        ? entry.text
        : null;
    final accepted = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) => EmergencyNoticeGatePage(catalogText: newerText),
      ),
    );
    if (accepted == true) return true;
    AppRouter.scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(appL10n.emergencyNoticeDeclineTitle)),
    );
    return false;
  }

  /// Shows the screen and records the answer with the version shown. A refused version is asked
  /// once more with the text the server holds now; if that cannot be shown the acceptance waits
  /// on the phone.
  static Future<bool> _askAndRecord(
    BuildContext context,
    AccountConsentsRemoteDataSource source,
    ConsentCatalogEntry? entry, {
    bool mayRetry = true,
  }) async {
    final version = entry?.version ?? AccountConsentKeys.emergencyNoticeVersion;
    if (!await _ask(context, entry)) return false;
    await _rememberProvider();
    await _remember(version, pending: true);
    final outcome = await _send(source, version).timeout(serverWait, onTimeout: () => _Sent.later);
    if (outcome == _Sent.refused && mayRetry && context.mounted) {
      // The text changed while the owner read it: the catalog again, and the new text.
      final fresh = (await _read(source))?.catalog[AccountConsentKeys.emergencyNotice];
      if (fresh != null && fresh.version != version && context.mounted) {
        await _forget();
        if (!context.mounted) return true;
        return _askAndRecord(context, source, fresh, mayRetry: false);
      }
    }
    // Whatever happened, the chat opens: what could not be recorded is sent again later.
    return true;
  }

  static bool acceptedOnServer(AccountConsentsSnapshot snapshot) {
    final decision = snapshot.decisions[AccountConsentKeys.emergencyNotice];
    final current = snapshot.catalog[AccountConsentKeys.emergencyNotice]?.version ??
        AccountConsentKeys.emergencyNoticeVersion;
    return decision != null && decision.granted && decision.version == current;
  }

  /// Sends an acceptance the server has not recorded yet, if there is one, with the version
  /// that was shown when it was given. A server that refuses that version is not insisted
  /// upon: the acceptance is dropped and the next chat asks again with the current text.
  static Future<void> submitPending(AccountConsentsRemoteDataSource source) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final version = preferences.getString(_pendingKey) ??
          // Build 44 kept a yes/no: the text it showed was its own.
          (preferences.getBool(_pendingKeyBuild44) == true
              ? AccountConsentKeys.emergencyNoticeVersion
              : null);
      if (version == null || version.isEmpty) return;
      final outcome = await _send(source, version);
      if (outcome == _Sent.refused) await _forget();
    } catch (_) {}
  }

  static Future<_Sent> _send(AccountConsentsRemoteDataSource source, String version) async {
    try {
      final result = await source.setConsent(
        consentKey: AccountConsentKeys.emergencyNotice,
        granted: true,
        shownVersion: version,
      );
      if (result.isSuccess) {
        final preferences = await SharedPreferences.getInstance();
        await preferences.remove(_pendingKey);
        await preferences.remove(_pendingKeyBuild44);
        return _Sent.recorded;
      }
      final code = result.fold(onSuccess: (_) => null, onFailure: (error) => error.code);
      return code == kConsentVersionMismatchCode ? _Sent.refused : _Sent.later;
    } catch (_) {
      return _Sent.later;
    }
  }

  /// Accepted on this phone: a newer text on the server is found out behind the chat, at most
  /// once an hour.
  static void _recheckBehind(AccountConsentsRemoteDataSource source, String accepted) {
    final now = DateTime.now();
    final last = _lastRecheck;
    if (last != null && now.difference(last) <= const Duration(hours: 1)) return;
    _lastRecheck = now;
    unawaited(_recheckCatalog(source, accepted));
  }

  /// Accepted on this phone and the server holds a different text now: the next chat asks again.
  static Future<void> _recheckCatalog(
    AccountConsentsRemoteDataSource source,
    String accepted,
  ) async {
    final entry = (await _read(source))?.catalog[AccountConsentKeys.emergencyNotice];
    if (entry != null && entry.version != accepted) await _forget();
  }

  /// Sign-out: nothing of this account stays, the provider's notice included.
  static Future<void> clear() async {
    await _forget();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_providerKey);
    } catch (_) {}
  }

  static Future<void> _forget() async {
    _lastRecheck = null;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_acceptedKey);
      await preferences.remove(_pendingKey);
      await preferences.remove(_pendingKeyBuild44);
    } catch (_) {}
  }

  static Future<AccountConsentsSnapshot?> _read(AccountConsentsRemoteDataSource source) async {
    try {
      final result = await source.fetch().timeout(serverWait);
      final AccountConsentsSnapshot? snapshot =
          result.fold(onSuccess: (value) => value, onFailure: (_) => null);
      return snapshot;
    } catch (_) {
      return null;
    }
  }

  /// The version accepted on this phone, or null.
  static Future<String?> _acceptedHere() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final version = preferences.getString(_acceptedKey);
      return version == null || version.isEmpty ? null : version;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> _providerSeen() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      return preferences.getBool(_providerKey) ?? false;
    } catch (_) {
      // Unreadable: better to say it once more than to skip it.
      return false;
    }
  }

  static Future<void> _rememberProvider() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_providerKey, true);
    } catch (_) {}
  }

  static Future<void> _remember(String version, {required bool pending}) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_acceptedKey, version);
      if (pending) {
        await preferences.setString(_pendingKey, version);
      } else {
        await preferences.remove(_pendingKey);
      }
    } catch (_) {}
  }
}

enum _Sent { recorded, refused, later }
