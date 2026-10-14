import 'dart:math';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/auth/auth.dart';
import '../../../shared/errors/app_auth_error.dart';
import '../../../shared/types/result.dart';
import 'auth_remote_data_source.dart';

class FakeAuthRemoteDataSource implements AuthRemoteDataSource {
  FakeAuthRemoteDataSource({
    Map<String, FakeUserRecord>? seededUsers,
  }) : _users = {
          ..._defaultSeededUsers,
          ...?seededUsers,
        };

  static const _usersStorageKey = 'vet_app.fake_auth_users';
  static final Map<String, FakeUserRecord> _defaultSeededUsers = {
    'demo@vetapp.local': FakeUserRecord(
      id: 'user_demo',
      email: 'demo@vetapp.local',
      password: 'VETAPP',
      displayName: 'Demo',
      createdAt: DateTime.utc(2026, 3, 26),
      onboardingCompleted: true,
    ),
  };

  final Map<String, FakeUserRecord> _users;
  SharedPreferences? _preferences;

  Future<SharedPreferences> _preferencesInstance() async {
    final preferences = _preferences;
    if (preferences != null) {
      return preferences;
    }

    final created = await SharedPreferences.getInstance();
    _preferences = created;
    return created;
  }

  @override
  Future<Result<AppSession>> signInWithPassword(
    AuthEmailPasswordCredentials credentials,
  ) async {
    await _restorePersistedUsers();
    final normalizedEmail = credentials.email.trim().toLowerCase();
    final user = _users[normalizedEmail];
    if (user == null || user.password != credentials.password) {
      return Result.failure(
        const AppAuthError(
          code: 'invalid_credentials',
          message: 'Email or password is incorrect',
        ),
      );
    }

    return Result.success(_sessionFor(user.toAppUser()));
  }

  @override
  Future<Result<AppSession>> signUpWithPassword(
    AuthSignUpRequest request,
  ) async {
    await _restorePersistedUsers();
    final normalizedEmail = request.email.trim().toLowerCase();
    if (_users.containsKey(normalizedEmail)) {
      return Result.failure(
        const AppAuthError(
          code: 'email_already_used',
          message: 'This email is already registered',
        ),
      );
    }

    final user = FakeUserRecord(
      id: _id('user'),
      email: normalizedEmail,
      password: request.password,
      displayName: request.displayName?.trim().isEmpty ?? true
          ? null
          : request.displayName?.trim(),
      createdAt: DateTime.now().toUtc(),
      onboardingCompleted: false,
    );
    _users[normalizedEmail] = user;
    await _persistUsers();

    return Result.success(_sessionFor(user.toAppUser()));
  }

  @override
  Future<Result<void>> resetPasswordForEmail(String email) async {
    await _restorePersistedUsers();
    final normalizedEmail = email.trim().toLowerCase();
    if (!_users.containsKey(normalizedEmail)) {
      return Result.failure(
        const AppAuthError(
          code: 'email_not_found',
          message: 'No account found for this email',
        ),
      );
    }

    return Result.success(null);
  }

  @override
  Future<Result<void>> updatePassword({String? email, required String newPassword}) async {
    await _restorePersistedUsers();
    final normalizedEmail = email?.trim().toLowerCase();
    final user = normalizedEmail == null ? null : _users[normalizedEmail];
    if (user == null) {
      return Result.failure(
        const AppAuthError(
          code: 'no_active_session',
          message: 'No account to update the password for',
        ),
      );
    }

    _users[normalizedEmail!] = FakeUserRecord(
      id: user.id,
      email: user.email,
      password: newPassword,
      displayName: user.displayName,
      createdAt: user.createdAt,
      onboardingCompleted: user.onboardingCompleted,
      firstName: user.firstName,
      lastName: user.lastName,
      phone: user.phone,
      avatarPath: user.avatarPath,
    );
    await _persistUsers();
    return Result.success(null);
  }

  @override
  Future<Result<AppUser>> updateProfile({String? email, required ProfileUpdate update}) async {
    await _restorePersistedUsers();
    final key = email?.trim().toLowerCase();
    final record = key == null ? null : _users[key];
    if (record == null) return Result.failure(_noAccount());

    final phone = update.phone?.trim();
    final updated = record.copyWith(
      firstName: update.firstName.trim(),
      lastName: update.lastName.trim(),
      phone: phone == null || phone.isEmpty ? null : phone,
      avatarPath: update.avatarPath,
      clearPhone: phone == null || phone.isEmpty,
      clearAvatar: update.avatarPath == null,
      displayName: [update.firstName.trim(), update.lastName.trim()]
          .where((part) => part.isNotEmpty)
          .join(' '),
    );
    _users[key!] = updated;
    await _persistUsers();
    return Result.success(updated.toAppUser());
  }

  @override
  Future<Result<EmailChangeStatus>> changeEmail({String? email, required String newEmail}) async {
    await _restorePersistedUsers();
    final key = email?.trim().toLowerCase();
    final record = key == null ? null : _users[key];
    if (record == null) return Result.failure(_noAccount());

    final target = newEmail.trim().toLowerCase();
    if (_users.containsKey(target)) {
      return Result.failure(
        const AppAuthError(code: 'email_exists', message: 'This email is already registered'),
      );
    }
    _users.remove(key);
    _users[target] = record.copyWith(email: target);
    await _persistUsers();
    // No mailbox offline: the new address applies at once.
    return Result.success(EmailChangeStatus.applied);
  }

  @override
  Future<Result<void>> verifyPassword({required String email, required String password}) async {
    await _restorePersistedUsers();
    final record = _users[email.trim().toLowerCase()];
    if (record == null || record.password != password) {
      return Result.failure(
        const AppAuthError(
          code: 'invalid_credentials',
          message: 'Email or password is incorrect',
        ),
      );
    }
    return Result.success(null);
  }

  @override
  Future<Result<void>> deleteAccount({String? email}) async {
    await _restorePersistedUsers();
    final key = email?.trim().toLowerCase();
    if (key == null || _users.remove(key) == null) return Result.failure(_noAccount());
    await _persistUsers();
    return Result.success(null);
  }

  AppAuthError _noAccount() =>
      const AppAuthError(code: 'no_active_session', message: 'No account found');

  @override
  Future<Result<void>> signOut() async {
    return Result.success(null);
  }

  Future<void> _restorePersistedUsers() async {
    final preferences = await _preferencesInstance();
    final raw = preferences.getString(_usersStorageKey);
    if (raw == null || raw.isEmpty) {
      return;
    }

    try {
      final payload = jsonDecode(raw);
      if (payload is! List) {
        return;
      }

      for (final entry in payload) {
        if (entry is! Map) {
          continue;
        }
        final record = FakeUserRecord.fromMap(Map<String, dynamic>.from(entry));
        _users[record.email.trim().toLowerCase()] = record;
      }
    } catch (_) {
      return;
    }
  }

  Future<void> _persistUsers() async {
    final preferences = await _preferencesInstance();
    final payload = _users.values.map((user) => user.toMap()).toList(growable: false);
    await preferences.setString(_usersStorageKey, jsonEncode(payload));
  }

  AppSession _sessionFor(AppUser user) {
    // 0xFFFFFFF (not 1 << 32): on web, dart2js/DDC compile `<<` using
    // JS's 32-bit-truncating shift, so `1 << 32` evaluates to 0 there and
    // Random().nextInt(0) throws — this stays a plain literal to sidestep
    // that entirely, cross-platform.
    final seed = Random().nextInt(0xFFFFFFF).toRadixString(16);
    return AppSession(
      user: user,
      accessToken: 'fake_access_$seed',
      refreshToken: 'fake_refresh_$seed',
      createdAt: DateTime.now().toUtc(),
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 2)),
    );
  }

  String _id(String prefix) {
    final seed = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    return '${prefix}_$seed';
  }
}

class FakeUserRecord {
  const FakeUserRecord({
    required this.id,
    required this.email,
    required this.password,
    required this.createdAt,
    required this.onboardingCompleted,
    this.displayName,
    this.firstName,
    this.lastName,
    this.phone,
    this.avatarPath,
  });

  final String id;
  final String email;
  final String password;
  final String? displayName;
  final DateTime createdAt;
  final bool onboardingCompleted;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? avatarPath;

  FakeUserRecord copyWith({
    String? email,
    String? displayName,
    String? firstName,
    String? lastName,
    String? phone,
    String? avatarPath,
    bool clearPhone = false,
    bool clearAvatar = false,
  }) {
    return FakeUserRecord(
      id: id,
      email: email ?? this.email,
      password: password,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt,
      onboardingCompleted: onboardingCompleted,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: clearPhone ? null : (phone ?? this.phone),
      avatarPath: clearAvatar ? null : (avatarPath ?? this.avatarPath),
    );
  }

  AppUser toAppUser() {
    return AppUser(
      id: id,
      email: email,
      displayName: displayName,
      createdAt: createdAt,
      onboardingCompleted: onboardingCompleted,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      avatarPath: avatarPath,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'password': password,
      'display_name': displayName,
      'created_at': createdAt.toIso8601String(),
      'onboarding_completed': onboardingCompleted,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'avatar_path': avatarPath,
    };
  }

  factory FakeUserRecord.fromMap(Map<String, dynamic> map) {
    return FakeUserRecord(
      id: map['id'] as String? ?? '',
      email: map['email'] as String? ?? '',
      password: map['password'] as String? ?? '',
      displayName: map['display_name'] as String?,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      onboardingCompleted: map['onboarding_completed'] as bool? ?? false,
      firstName: map['first_name'] as String?,
      lastName: map['last_name'] as String?,
      phone: map['phone'] as String?,
      avatarPath: map['avatar_path'] as String?,
    );
  }
}
