import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/shared/widgets/typed_date_field.dart';

Widget _harness(TextEditingController controller, {Future<void> Function()? onPick}) {
  return MaterialApp(
    home: Scaffold(
      body: Column(
        children: [
          TypedDateField(
            key: const Key('date'),
            controller: controller,
            decoration: const InputDecoration(hintText: 'gg/mm/aaaa'),
            onPick: onPick ?? () async {},
            pickIcon: const Icon(Icons.calendar_today_outlined),
          ),
          const TextField(key: Key('other')),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('the first tap empties the proposed date and typing starts from zero', (tester) async {
    final controller = TextEditingController(text: '07/10/2026');
    await tester.pumpWidget(_harness(controller));

    await tester.tap(find.byKey(const Key('date')));
    await tester.pump();
    expect(controller.text, '');

    await tester.enterText(find.byKey(const Key('date')), '12112026');
    expect(controller.text, '12/11/2026');
  });

  testWidgets('leaving the field without typing puts the proposed date back', (tester) async {
    final controller = TextEditingController(text: '07/10/2026');
    await tester.pumpWidget(_harness(controller));

    await tester.tap(find.byKey(const Key('date')));
    await tester.pump();
    expect(controller.text, '');

    await tester.tap(find.byKey(const Key('other')));
    await tester.pump();
    expect(controller.text, '07/10/2026');
  });

  testWidgets('a date the owner typed is not emptied by the next tap', (tester) async {
    final controller = TextEditingController(text: '07/10/2026');
    await tester.pumpWidget(_harness(controller));

    await tester.tap(find.byKey(const Key('date')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('date')), '12112026');
    await tester.tap(find.byKey(const Key('other')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('date')));
    await tester.pump();
    expect(controller.text, '12/11/2026');
  });

  testWidgets('a field that starts empty stays empty and keeps working', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(_harness(controller));

    await tester.tap(find.byKey(const Key('date')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('other')));
    await tester.pump();
    expect(controller.text, '');
  });

  testWidgets('the calendar button still fills the field, and a picked date is kept', (tester) async {
    final controller = TextEditingController(text: '07/10/2026');
    await tester.pumpWidget(
      _harness(controller, onPick: () async => controller.text = '25/12/2026'),
    );

    await tester.tap(find.byIcon(Icons.calendar_today_outlined));
    await tester.pump();
    expect(controller.text, '25/12/2026');

    await tester.tap(find.byKey(const Key('date')));
    await tester.pump();
    expect(controller.text, '25/12/2026', reason: 'the owner picked it; it is not a proposal any more');
  });

  testWidgets('cancelling the calendar leaves the proposed date, still replaceable', (tester) async {
    final controller = TextEditingController(text: '07/10/2026');
    await tester.pumpWidget(_harness(controller));

    await tester.tap(find.byIcon(Icons.calendar_today_outlined));
    await tester.pump();
    expect(controller.text, '07/10/2026');

    await tester.tap(find.byKey(const Key('date')));
    await tester.pump();
    expect(controller.text, '');
  });
}
