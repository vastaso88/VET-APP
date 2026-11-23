import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/auth/data/supabase_auth_remote_data_source.dart';
import 'package:vet_app_mobile/features/auth/domain/auth_error_messages.dart';
import 'package:vet_app_mobile/features/auth/domain/auth_link_notice.dart';
import 'package:vet_app_mobile/features/auth/presentation/widgets/resend_confirmation_button.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';
import 'package:vet_app_mobile/shared/errors/app_auth_error.dart';
import 'package:vet_app_mobile/shared/types/result.dart';

Widget _app(Widget child) {
  AppLocaleHolder.current = const Locale('it');
  return MaterialApp(
    locale: const Locale('it'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(body: child),
  );
}

AppAuthError _error(String code, String message) => AppAuthError(code: code, message: message);

void main() {
  group('where the e-mail link brings the person back', () {
    test('on a phone it is the app scheme, on the web the app origin', () {
      expect(authEmailRedirect(isWeb: false), kPasswordRecoveryRedirect);
      expect(
        authEmailRedirect(isWeb: true, origin: 'https://app.example.com'),
        'https://app.example.com',
      );
    });
  });

  group('where the sign-up confirmation brings the person back', () {
    test('on a phone with an https API it is the confirmation page', () {
      expect(
        signUpConfirmationRedirect(isWeb: false, apiBaseUrl: 'https://api.example.com'),
        'https://api.example.com/auth/confirmed',
      );
      expect(
        signUpConfirmationRedirect(isWeb: false, apiBaseUrl: 'https://api.example.com/'),
        'https://api.example.com/auth/confirmed',
      );
    });

    test('without a usable https API it stays the app scheme', () {
      for (final base in ['', '   ', 'http://api.example.com', 'https://', 'api.example.com']) {
        expect(
          signUpConfirmationRedirect(isWeb: false, apiBaseUrl: base),
          kPasswordRecoveryRedirect,
          reason: base,
        );
      }
    });

    test('on the web it is the app origin, whatever the API', () {
      expect(
        signUpConfirmationRedirect(
          isWeb: true,
          origin: 'https://app.example.com',
          apiBaseUrl: 'https://api.example.com',
        ),
        'https://app.example.com',
      );
    });

    test('recovery and change of e-mail keep their own redirect', () {
      expect(authEmailRedirect(isWeb: false), kPasswordRecoveryRedirect);
    });
  });

  group('resend button', () {
    testWidgets('sends once, then makes the person wait before the next one', (tester) async {
      final sent = <String>[];
      await tester.pumpWidget(_app(
        ResendConfirmationButton(
          email: 'anna@example.com',
          resend: (email) async {
            sent.add(email);
            return Result.success(null);
          },
          wait: const Duration(seconds: 3),
        ),
      ));

      await tester.tap(find.text("Invia di nuovo l'email"));
      await tester.pump();
      expect(sent, ['anna@example.com']);
      expect(find.textContaining('inviata di nuovo'), findsOneWidget);

      // Waiting: the button is off and says for how long; a tap sends nothing.
      expect(find.textContaining('Puoi richiederla di nuovo tra 3 s'), findsOneWidget);
      await tester.tap(find.textContaining('Puoi richiederla'));
      await tester.pump();
      expect(sent, hasLength(1));

      await tester.pump(const Duration(seconds: 3));
      await tester.tap(find.text("Invia di nuovo l'email"));
      await tester.pump();
      expect(sent, hasLength(2));
      // Let the last countdown end so no timer is left behind.
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('right after sign-up it starts already waiting', (tester) async {
      await tester.pumpWidget(_app(
        ResendConfirmationButton(
          email: 'anna@example.com',
          resend: (_) async => Result.success(null),
          startWaiting: true,
          wait: const Duration(seconds: 2),
        ),
      ));
      expect(find.textContaining('tra 2 s'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text("Invia di nuovo l'email"), findsOneWidget);
    });

    testWidgets('a failure shows a clear message, never the raw text of the provider',
        (tester) async {
      await tester.pumpWidget(_app(
        ResendConfirmationButton(
          email: 'anna@example.com',
          resend: (_) async => Result.failure(
            _error('over_email_send_rate_limit', 'email rate limit exceeded'),
          ),
          wait: const Duration(seconds: 1),
        ),
      ));
      await tester.tap(find.text("Invia di nuovo l'email"));
      await tester.pump();

      expect(find.textContaining('troppe email'), findsOneWidget);
      expect(find.textContaining('rate limit exceeded'), findsNothing);
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('messages for the e-mail problems', () {
    test('address not confirmed is recognised and has its own message', () {
      final error = _error('email_not_confirmed', 'Email not confirmed');
      expect(isEmailNotConfirmed(error), isTrue);
      expect(isEmailNotConfirmed(_error('400', 'Email not confirmed')), isTrue);
      expect(isEmailNotConfirmed(_error('invalid_credentials', 'Invalid login credentials')),
          isFalse);
      AppLocaleHolder.current = const Locale('it');
      expect(localizedAuthMessage(error), contains('confermare la tua email'));
    });

    test('too many sends: a clear message in the app language', () {
      AppLocaleHolder.current = const Locale('it');
      for (final error in [
        _error('over_email_send_rate_limit', 'email rate limit exceeded'),
        _error('429', 'For security purposes, you can only request this after 10 seconds. Too many'),
      ]) {
        expect(localizedAuthMessage(error), contains('troppe email'));
      }
    });

    test('an address the sender cannot reach is never shown with the provider text', () {
      AppLocaleHolder.current = const Locale('it');
      for (final error in [
        _error('email_address_not_authorized', 'Email address not authorized'),
        _error('unexpected_failure', 'Error sending confirmation email'),
        _error('500', 'SMTP error: mailbox unavailable'),
      ]) {
        final message = localizedAuthMessage(error);
        expect(message, contains('Non riusciamo a consegnare'));
        expect(message.toLowerCase(), isNot(contains('smtp')));
      }
    });

    test('a link opened on another device explains what to do', () {
      AppLocaleHolder.current = const Locale('it');
      final message = localizedAuthMessage(
        _error('bad_code_verifier', 'Code verifier could not be found in local storage'),
      );
      expect(message, contains('stesso dispositivo'));
    });

    test('a link already used or expired keeps its message', () {
      AppLocaleHolder.current = const Locale('it');
      expect(
        localizedAuthMessage(_error('otp_expired', 'Email link is invalid or has expired')),
        contains('Richiedine uno nuovo'),
      );
    });
  });

  group('problem of an e-mail link', () {
    test('is shown once and then forgotten', () {
      AuthLinkNotice.instance.record(_error('otp_expired', 'Email link is invalid or has expired'));
      expect(AuthLinkNotice.instance.take(), isNotNull);
      expect(AuthLinkNotice.instance.take(), isNull);
    });
  });
}
