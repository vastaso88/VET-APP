import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/settings/presentation/widgets/collapsible_section.dart';

class _Accordion extends StatefulWidget {
  const _Accordion();

  @override
  State<_Accordion> createState() => _AccordionState();
}

class _AccordionState extends State<_Accordion> {
  String? _open;

  Widget _section(String id) => CollapsibleSection(
        sectionId: id,
        title: id,
        expanded: _open == id,
        onToggle: (value) => setState(() => _open = _open == value ? null : value),
        children: [Text('body-$id')],
      );

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(body: ListView(children: [_section('a'), _section('b')])),
      );
}

void main() {
  testWidgets('starts closed and opens one section at a time', (tester) async {
    await tester.pumpWidget(const _Accordion());
    expect(find.text('body-a').hitTestable(), findsNothing);
    expect(find.text('body-b').hitTestable(), findsNothing);

    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();
    expect(find.text('body-a').hitTestable(), findsOneWidget);

    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();
    expect(find.text('body-b').hitTestable(), findsOneWidget);
    expect(find.text('body-a').hitTestable(), findsNothing);
  });
}
