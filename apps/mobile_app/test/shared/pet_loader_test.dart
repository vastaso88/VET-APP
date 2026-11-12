import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/shared/widgets/pet_loader.dart';

Widget _harness(Widget child, {bool disableAnimations = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

String _currentAnimal(WidgetTester tester) {
  return PetLoader.animals.firstWhere(
    (emoji) => find.text(emoji).evaluate().isNotEmpty,
    orElse: () => '',
  );
}

void main() {
  testWidgets('the animal changes after one full turn', (tester) async {
    await tester.pumpWidget(_harness(const PetLoader()));
    final first = _currentAnimal(tester);
    expect(first, PetLoader.animals.first);

    // One full turn in frame-sized steps — the turn is counted when the
    // value wraps, which needs a frame sampled on each side of the wrap.
    // The swap happens at the edge-on quarter, so one turn is enough.
    for (var elapsed = 0;
        elapsed < PetLoader.turnDuration.inMilliseconds + 50;
        elapsed += 16) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(_currentAnimal(tester), isNot(first));
    expect(_currentAnimal(tester), PetLoader.animals[1]);
  });

  testWidgets('the label is shown under the animal when given', (tester) async {
    await tester.pumpWidget(_harness(const PetLoader(label: 'Carico le News...')));

    expect(find.text('Carico le News...'), findsOneWidget);
  });

  testWidgets('no label text when none is given', (tester) async {
    await tester.pumpWidget(_harness(const PetLoader()));

    expect(find.byType(Text), findsOneWidget);
  });

  testWidgets('reduced motion shows the static first animal and runs no animation', (tester) async {
    await tester.pumpWidget(_harness(const PetLoader(), disableAnimations: true));

    expect(_currentAnimal(tester), PetLoader.animals.first);
    await tester.pump(PetLoader.turnDuration * 2);
    expect(_currentAnimal(tester), PetLoader.animals.first);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('disposing stops the animation so nothing keeps ticking', (tester) async {
    await tester.pumpWidget(_harness(const PetLoader()));
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pumpWidget(_harness(const SizedBox()));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('the small variant renders without a label', (tester) async {
    await tester.pumpWidget(_harness(const PetLoader.small()));

    expect(find.text(PetLoader.animals.first), findsOneWidget);
  });
}
