import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/l10n/app_localizations.dart';
import 'package:vet_app_mobile/features/home/presentation/widgets/home_dashboard_primitives.dart';

void main() {
  test('Italian wording: the notification section is not called "push", news load as "notizie"', () async {
    final it = await AppLocalizations.delegate.load(const Locale('it'));
    expect(it.settingsSectionPushNotifications, 'Notifiche');
    expect(it.petNewsLoading, 'Carico le notizie...');
  });

  testWidgets('a long title in a Home row goes on a second line instead of being cut',
      (tester) async {
    const title = 'Controllo annuale del peso e della dentatura con visita completa';
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 240, child: DashboardListRow(title: title)),
      ),
    ));
    final text = tester.widget<Text>(find.text(title));
    expect(text.maxLines, 2);
    // Two lines are really drawn: the box is taller than a single line.
    expect(tester.getSize(find.text(title)).height, greaterThan(24));
  });
}
