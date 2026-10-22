import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../language/data/language_store.dart';

import '../../../shared/auth/auth.dart';
import '../../../shared/config/app_runtime_config.dart';
import '../../../shared/errors/app_auth_error.dart';
import '../../../shared/types/result.dart';
import 'auth_remote_data_source.dart';

const kPasswordRecoveryRedirect = 'vetapp://auth-callback';

class SupabaseAuthRemoteDataSource implements AuthRemoteDataSource {
  const SupabaseAuthRemoteDataSource({
    required this.config,
  });

  final AppRuntimeConfig config;

  bool get isConfigured => config.hasSupabaseCredentials;
  GoTrueClient get _client => Supabase.instance.client.auth;

  @override
  Future<Result<AppSession>> signInWithPassword(
    AuthEmailPasswordCredentials credentials,
  ) async {
    if (!isConfigured) {
      return _missingConfig();
    }

    try {
      final response = await _client.signInWithPassword(
        email: credentials.email.trim(),
        password: credentials.password,
      );
      final session = response.session;
      final user = response.user;
      if (session == null || user == null || user.email == null) {
        return Result.failure(
          const AppAuthError(
            code: 'sign_in_incomplete',
            message: 'Sign-in completed without a usable session',
          ),
        );
      }

      await LanguageStore.instance.syncAfterAuthentication();
      return Result.success(_mapSession(session, user));
    } on AuthException catch (error) {
      return Result.failure(
        AppAuthError(
          code: error.statusCode ?? 'auth_error',
          message: error.message,
        ),
      );
    } catch (error) {
      return Result.failure(
        AppAuthError(
          code: 'unexpected_sign_in_error',
          message: 'Unable to sign in right now',
          details: error,
        ),
      );
    }
  }

  @override
  Future<Result<AppSession>> signUpWithPassword(
    AuthSignUpRequest request,
  ) async {
    if (!isConfigured) {
      return _missingConfig();
    }

    try {
      final response = await _client.signUp(
        email: request.email.trim(),
        password: request.password,
        data: {
          if (request.displayName != null && request.displayName!.trim().isNotEmpty)
            'display_name': request.displayName!.trim(),
          'onboarding_completed': false,
          'preferred_locale': LanguageStore.instance.variant.languageCode,
          'preferred_locale_variant': LanguageStore.instance.variant.id,
        },
      );
      final session = response.session;
      final user = response.user;
      if (session == null || user == null || user.email == null) {
        return Result.failure(
          const AppAuthError(
            code: 'sign_up_confirmation_required',
            message: 'Account created. Check your email to confirm the registration.',
          ),
        );
      }

      return Result.success(_mapSession(session, user));
    } on AuthException catch (error) {
      return Result.failure(
        AppAuthError(
          code: error.statusCode ?? 'auth_error',
          message: error.message,
        ),
      );
    } catch (error) {
      return Result.failure(
        AppAuthError(
          code: 'unexpected_sign_up_error',
          message: 'Unable to create the account right now',
          details: error,
        ),
      );
    }
  }

  @override
  Future<Result<void>> resetPasswordForEmail(String email) async {
    if (!isConfigured) {
      return Result.failure(_missingConfigError());
    }

    try {
      // On web the link must come back to this app's own origin; on mobile
      // it returns via the app's custom scheme (needs the matching intent
      // filter in AndroidManifest.xml — see docs/auth/01_brainstorm.md).
      await _client.resetPasswordForEmail(
        email.trim(),
        redirectTo: kIsWeb ? Uri.base.origin : kPasswordRecoveryRedirect,
      );
      return Result.success(null);
    } on AuthException catch (error) {
      return Result.failure(
        AppAuthError(
          code: error.statusCode ?? 'auth_error',
          message: error.message,
        ),
      );
    } catch (error) {
      return Result.failure(
        AppAuthError(
          code: 'unexpected_reset_password_error',
          message: 'Unable to start password recovery right now',
          details: error,
        ),
      );
    }
  }

  @override
  Future<Result<void>> updatePassword(
      {String? email, required String newPassword}) async {
    if (!isConfigured) {
      return Result.failure(_missingConfigError());
    }

    try {
      await _client.updateUser(UserAttributes(password: newPassword));
      return Result.success(null);
    } on AuthException catch (error) {
      return Result.failure(
        AppAuthError(
          code: error.statusCode ?? 'auth_error',
          message: error.message,
        ),
      );
    } catch (error) {
      return Result.failure(
        AppAuthError(
          code: 'unexpected_update_password_error',
          message: 'Unable to update the password right now',
          details: error,
        ),
      );
    }
  }

  @override
  Future<Result<AppUser>> updateProfile({String? email, required ProfileUpdate update}) async {
    if (!isConfigured) {
      return Result.failure(_missingConfigError());
    }

    try {
      final first = update.firstName.trim();
      final last = update.lastName.trim();
      final phone = update.phone?.trim();
      final response = await _client.updateUser(
        UserAttributes(
          data: {
            'first_name': first,
            'last_name': last,
            'display_name': [first, last].where((part) => part.isNotEmpty).join(' '),
            // Empty strings clear a metadata key.
            'phone': phone ?? '',
            'avatar_path': update.avatarPath ?? '',
          },
        ),
      );
      final user = response.user;
      if (user == null) {
        return Result.failure(
          const AppAuthError(code: 'no_active_session', message: 'No signed-in account'),
        );
      }
      return Result.success(_mapUser(user));
    } on AuthException catch (error) {
      return Result.failure(
        AppAuthError(code: error.statusCode ?? 'auth_error', message: error.message),
      );
    } catch (error) {
      return Result.failure(
        AppAuthError(
          code: 'unexpected_update_profile_error',
          message: 'Unable to save the profile right now',
          details: error,
        ),
      );
    }
  }

  @override
  Future<Result<EmailChangeStatus>> changeEmail({String? email, required String newEmail}) async {
    if (!isConfigured) {
      return Result.failure(_missingConfigError());
    }

    try {
      final target = newEmail.trim();
      final response = await _client.updateUser(
        UserAttributes(email: target),
        emailRedirectTo: kIsWeb ? Uri.base.origin : kPasswordRecoveryRedirect,
      );
      // With email confirmation off in the project the new address is applied
      // straight away; with it on, GoTrue keeps the old one and parks the new
      // one in `new_email` until the link is opened.
      final applied = response.user?.email?.toLowerCase() == target.toLowerCase();
      return Result.success(
        applied ? EmailChangeStatus.applied : EmailChangeStatus.confirmationSent,
      );
    } on AuthException catch (error) {
      return Result.failure(
        AppAuthError(code: error.statusCode ?? 'auth_error', message: error.message),
      );
    } catch (error) {
      return Result.failure(
        AppAuthError(
          code: 'unexpected_change_email_error',
          message: 'Unable to change the email right now',
          details: error,
        ),
      );
    }
  }

  @override
  Future<Result<void>> verifyPassword({required String email, required String password}) async {
    if (!isConfigured) {
      return Result.failure(_missingConfigError());
    }

    try {
      await _client.signInWithPassword(email: email.trim(), password: password);
      return Result.success(null);
    } on AuthException catch (error) {
      return Result.failure(
        AppAuthError(code: error.statusCode ?? 'auth_error', message: error.message),
      );
    } catch (error) {
      return Result.failure(
        AppAuthError(
          code: 'unexpected_verify_password_error',
          message: 'Unable to check the password right now',
          details: error,
        ),
      );
    }
  }

  @override
  Future<Result<void>> deleteAccount({String? email}) async {
    if (!isConfigured) {
      return Result.failure(_missingConfigError());
    }

    try {
      final token = _client.currentSession?.accessToken;
      if (token == null || !config.hasApiBaseUrl) {
        return Result.failure(
          const AppAuthError(code: 'no_active_session', message: 'No signed-in account'),
        );
      }
      final response = await http.delete(
        Uri.parse('${config.apiBaseUrl}/account'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 60));
      if (response.statusCode == 401) {
        // The server wants a sign-in from the last few minutes.
        return Result.failure(
          const AppAuthError(
            code: 'reauth_required',
            message: 'Sign in again to confirm the deletion',
          ),
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Result.failure(
          AppAuthError(
            code: 'delete_account_http_${response.statusCode}',
            message: 'Unable to delete the account right now',
          ),
        );
      }
      try {
        // The account no longer exists server-side: only drop the local session.
        await _client.signOut(scope: SignOutScope.local);
      } catch (_) {
        // Nothing left to revoke; the caller clears the stored session anyway.
      }
      return Result.success(null);
    } catch (error) {
      return Result.failure(
        AppAuthError(
          code: 'unexpected_delete_account_error',
          message: 'Unable to delete the account right now',
          details: error,
        ),
      );
    }
  }

  @override
  Future<Result<void>> signOut() async {
    if (!isConfigured) {
      return Result.success(null);
    }

    try {
      await _client.signOut();
      return Result.success(null);
    } on AuthException catch (error) {
      return Result.failure(
        AppAuthError(
          code: error.statusCode ?? 'auth_error',
          message: error.message,
        ),
      );
    } catch (error) {
      return Result.failure(
        AppAuthError(
          code: 'unexpected_sign_out_error',
          message: 'Unable to sign out right now',
          details: error,
        ),
      );
    }
  }

  Result<AppSession> _missingConfig() => Result.failure(_missingConfigError());

  AppAuthError _missingConfigError() {
    return AppAuthError(
      code: 'supabase_missing_config',
      message: 'Supabase credentials are missing from runtime config',
      details: {
        'hasSupabaseCredentials': isConfigured,
        'supabaseUrl': config.supabaseUrl,
      },
    );
  }

  AppUser _mapUser(User user) {
    final metadata = user.userMetadata;
    String? text(String key) {
      final value = (metadata?[key] as String?)?.trim();
      return value == null || value.isEmpty ? null : value;
    }

    return AppUser(
      id: user.id,
      email: user.email ?? '',
      displayName: text('display_name'),
      createdAt: DateTime.tryParse(user.createdAt) ?? DateTime.now().toUtc(),
      onboardingCompleted: metadata?['onboarding_completed'] as bool? ?? false,
      firstName: text('first_name'),
      lastName: text('last_name'),
      phone: text('phone'),
      avatarPath: text('avatar_path'),
    );
  }

  AppSession _mapSession(Session session, User user) {
    final appUser = _mapUser(user);

    return AppSession(
      user: appUser,
      accessToken: session.accessToken,
      refreshToken: session.refreshToken ?? '',
      createdAt: DateTime.tryParse(user.createdAt) ?? DateTime.now().toUtc(),
      expiresAt: session.expiresAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              session.expiresAt! * 1000,
              isUtc: true,
            ),
    );
  }
}
