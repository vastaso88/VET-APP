import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/billing/presentation/widgets/billing_account_panel.dart';

void main() {
  testWidgets('native builds have no external purchase button', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: BillingAccountPanel()),
    ));
    expect(find.byType(OutlinedButton), findsNothing);
    expect(BillingAccountPanel.demoEnabled, isFalse);
  });

  test('account links contain no token or platform bypass', () {
    final url = BillingAccountPanel.accountUrl;
    expect(url.scheme, 'https');
    expect(url.host, 'quokkapet.net');
    expect(url.path, '/account');
    expect(url.hasQuery, isFalse);
    expect(url.hasFragment, isFalse);
  });
}
