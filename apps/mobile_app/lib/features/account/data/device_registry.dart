import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/auth/current_user.dart';
import '../../../shared/config/app_runtime_config_loader.dart';

/// Asks the backend whether this install of the app may stay signed in
/// (`POST /devices/register`): each plan allows a number of devices, and
/// when a new one signs in the one seen least recently is signed out.
abstract class DeviceRegistryClient {
  /// True when this install may stay signed in. [claim] is true right after
  /// a sign-in (the device takes a place), false on an ordinary start.
  /// Fails open: if the backend cannot be reached the owner is not locked out.
  Future<bool> register({required bool claim});
}

class DeviceRegistry implements DeviceRegistryClient {
  DeviceRegistry({http.Client? client, AppRuntimeConfigLoader? configLoader})
      : _client = client ?? http.Client(),
        _configLoader = configLoader ?? const AppRuntimeConfigLoader();

  final http.Client _client;
  final AppRuntimeConfigLoader _configLoader;

  static const _storageKey = 'vet_app.install_id';
  static const _timeout = Duration(seconds: 10);

  /// Set when the app signed this device out because a newer one took its
  /// place; the sign-in screen explains it once, then clears it.
  static bool pendingNotice = false;

  static bool takePendingNotice() {
    final pending = pendingNotice;
    pendingNotice = false;
    return pending;
  }

  /// A random id for this install: nothing about the phone or the owner.
  /// It is kept across sign-outs on purpose: a new id at every sign-in
  /// would leave an unreleased place on the server each time and push the
  /// owner's other devices out. It goes away when the app is uninstalled.
  Future<String> installId() async {
    final preferences = await SharedPreferences.getInstance();
    final existing = preferences.getString(_storageKey);
    if (existing != null && existing.length >= 8) return existing;
    final random = Random.secure();
    final created = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await preferences.setString(_storageKey, created);
    return created;
  }

  @override
  Future<bool> register({required bool claim}) async {
    try {
      final token = CurrentUser.accessToken();
      final response = await _client
          .post(
            Uri.parse('${_configLoader.load().apiBaseUrl}/devices/register'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'device_id': await installId(), 'claim': claim}),
          )
          .timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) return true;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return json['active'] as bool? ?? true;
    } catch (_) {
      return true;
    }
  }
}
