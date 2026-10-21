import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:vet_app_mobile/features/notifications/application/notification_availability.dart';
import 'package:vet_app_mobile/features/notifications/presentation/notifications_off_banner.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';

const _bannerText = 'Le notifiche sono disattivate: i promemoria non suoneranno';

/// A phone whose notification state the test controls.
class _Phone {
  PermissionStatus status = PermissionStatus.denied;
  PermissionStatus afterRequest = PermissionStatus.denied;
  bool notificationSettingsOpen = true;
  int requests = 0;
  int notificationSettingsOpened = 0;
  int appSettingsOpened = 0;
  int replans = 0;

  NotificationAvailability availability({bool android = true}) => NotificationAvailability(
        readStatus: () async => status,
        requestPermission: () async {
          requests++;
          status = afterRequest;
          return afterRequest;
        },
        openNotificationSettings: () async {
          notificationSettingsOpened++;
          return notificationSettingsOpen;
        },
        openAppSettingsScreen: () async {
          appSettingsOpened++;
          return true;
        },
        onEnabled: () => replans++,
        isAndroid: android,
      );
}

void main() {
  group('NotificationAvailability', () {
    test('disabled while the permission is missing, clear once it is granted', () async {
      final phone = _Phone();
      final availability = phone.availability();

      await availability.refresh();
      expect(availability.disabled.value, isTrue);

      phone.status = PermissionStatus.granted;
      await availability.refresh();
      expect(availability.disabled.value, isFalse);
      // Allowed from the settings: the notification plan is rebuilt.
      expect(phone.replans, 1);
    });

    test('nothing to show on web or iOS, or when the state cannot be read', () async {
      final phone = _Phone();
      final other = phone.availability(android: false);
      await other.refresh();
      expect(other.disabled.value, isFalse);

      final broken = NotificationAvailability(
        readStatus: () async => throw PlatformException(code: 'no plugin'),
        isAndroid: true,
      );
      await broken.refresh();
      expect(broken.disabled.value, isFalse);
    });

    test('"Attiva" first lets Android show its own dialog when it still can', () async {
      final phone = _Phone()..afterRequest = PermissionStatus.granted;
      final availability = phone.availability();
      await availability.refresh();

      await availability.activate();

      expect(phone.requests, 1);
      expect(availability.disabled.value, isFalse);
      expect(phone.notificationSettingsOpened, 0);
    });

    test('...and goes to the notification settings when the owner refuses or it was refused for good',
        () async {
      final refused = _Phone();
      await refused.availability().activate();
      expect(refused.requests, 1);
      expect(refused.notificationSettingsOpened, 1);

      final forGood = _Phone()..status = PermissionStatus.permanentlyDenied;
      await forGood.availability().activate();
      // Android shows no dialog any more: no request, straight to the settings.
      expect(forGood.requests, 0);
      expect(forGood.notificationSettingsOpened, 1);
      expect(forGood.appSettingsOpened, 0);
    });

    test('without a notification settings screen it opens the app\'s general settings', () async {
      final phone = _Phone()
        ..status = PermissionStatus.permanentlyDenied
        ..notificationSettingsOpen = false;

      await phone.availability().activate();

      expect(phone.notificationSettingsOpened, 1);
      expect(phone.appSettingsOpened, 1);
    });
  });

  group('NotificationsOffBanner', () {
    Future<void> pump(WidgetTester tester, NotificationAvailability availability) {
      return tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: NotificationsOffBanner(availability: availability)),
        ),
      );
    }

    testWidgets('shows the message and "Attiva" while notifications cannot ring', (tester) async {
      final phone = _Phone();
      await pump(tester, phone.availability());
      await tester.pumpAndSettle();

      expect(find.text(_bannerText), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Attiva'), findsOneWidget);
    });

    testWidgets('is not there when they can ring', (tester) async {
      final phone = _Phone()..status = PermissionStatus.granted;
      await pump(tester, phone.availability());
      await tester.pumpAndSettle();

      expect(find.text(_bannerText), findsNothing);
    });

    testWidgets('is not there on web or iOS', (tester) async {
      final phone = _Phone();
      await pump(tester, phone.availability(android: false));
      await tester.pumpAndSettle();

      expect(find.text(_bannerText), findsNothing);
    });

    testWidgets('"Attiva" opens the settings; back in the app and allowed, it goes away',
        (tester) async {
      final phone = _Phone()..status = PermissionStatus.permanentlyDenied;
      await pump(tester, phone.availability());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Attiva'));
      await tester.pumpAndSettle();
      expect(phone.notificationSettingsOpened, 1);
      expect(find.text(_bannerText), findsOneWidget);

      // The owner switches notifications on in the system settings and comes back.
      phone.status = PermissionStatus.granted;
      final binding = tester.binding;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text(_bannerText), findsNothing);
      expect(phone.replans, 1);
    });
  });
}
