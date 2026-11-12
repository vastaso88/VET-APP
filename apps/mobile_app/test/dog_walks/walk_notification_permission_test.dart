import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vet_app_mobile/features/dog_walks/presentation/walk_notification_permission.dart';
import 'package:vet_app_mobile/l10n/app_localizations.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Runs as Android; the override is lifted inside the body, before the
  /// framework checks that no debug variable was left changed.
  void androidTest(String name, Future<void> Function(WidgetTester tester, BuildContext context) body) {
    testWidgets(name, (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        late BuildContext context;
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('it'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(builder: (c) {
              context = c;
              return const Scaffold();
            }),
          ),
        );
        await body(tester, context);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  androidTest('first walk: explains with the shared window, then the system dialog follows',
      (tester, context) async {
    var requested = 0;
    final done = maybeAskWalkNotificationPermission(
      context,
      readStatus: () async => PermissionStatus.denied,
      request: () async {
        requested++;
        return PermissionStatus.granted;
      },
    );
    await tester.pumpAndSettle();

    expect(find.text('Vedi la passeggiata nelle notifiche'), findsOneWidget);
    expect(find.textContaining('notifica fissa con tempo e distanza'), findsOneWidget);
    expect(find.textContaining('la passeggiata viene registrata comunque'), findsOneWidget);
    expect(requested, 0, reason: 'nothing is asked before "Continua"');

    await tester.tap(find.text('Continua'));
    await tester.pumpAndSettle();
    await done;

    expect(requested, 1);
  });

  androidTest('"Non ora" asks nothing, and the question is not repeated at the next walk',
      (tester, context) async {
    var requested = 0;
    Future<PermissionStatus> request() async {
      requested++;
      return PermissionStatus.granted;
    }

    final first = maybeAskWalkNotificationPermission(
      context,
      readStatus: () async => PermissionStatus.denied,
      request: request,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Non ora'));
    await tester.pumpAndSettle();
    await first;
    expect(requested, 0);

    await maybeAskWalkNotificationPermission(
      context,
      readStatus: () async => PermissionStatus.denied,
      request: request,
    );
    await tester.pumpAndSettle();
    expect(find.text('Vedi la passeggiata nelle notifiche'), findsNothing);
  });
}
