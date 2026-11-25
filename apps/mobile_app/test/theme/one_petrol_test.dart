import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vet_app_mobile/app/theme/app_theme.dart';
import 'package:vet_app_mobile/design_system/atoms/outline_icon_button.dart';
import 'package:vet_app_mobile/design_system/tokens/app_colors.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  test('there is one petrol: the second one has no name any more', () {
    final users = [
      for (final entity in Directory('lib').listSync(recursive: true))
        if (entity is File &&
            entity.path.endsWith('.dart') &&
            entity.readAsStringSync().contains('primaryStrong'))
          entity.path,
    ];
    expect(users, isEmpty, reason: 'use AppColors.primary');
  });

  testWidgets('one look for the main button, whichever widget a page uses', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Column(
            children: [
              ElevatedButton(onPressed: () {}, child: const Text('Accedi')),
              FilledButton(onPressed: () {}, child: const Text('Continua')),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {},
            label: const Text('Nuovo annuncio'),
          ),
        ),
      ),
    );

    Material materialOf(Type button) => tester.widget<Material>(
          find.descendant(of: find.byType(button), matching: find.byType(Material)).first,
        );
    final elevated = materialOf(ElevatedButton);
    final filled = materialOf(FilledButton);
    final floating = materialOf(FloatingActionButton);

    for (final material in [elevated, filled, floating]) {
      expect(material.color, AppColors.primary);
      expect(material.elevation, 0);
      expect(
        (material.shape! as RoundedRectangleBorder).borderRadius,
        (filled.shape! as RoundedRectangleBorder).borderRadius,
      );
    }
    expect(tester.getSize(find.byType(ElevatedButton)), tester.getSize(find.byType(FilledButton)));
  });

  testWidgets('a chosen chip is the same petrol as the button', (tester) async {
    final theme = AppTheme.light().chipTheme;
    expect(theme.selectedColor, AppColors.primary);
    // The one a ChoiceChip paints.
    expect(theme.secondarySelectedColor, AppColors.primary);
  });

  testWidgets('the round commands of a header are outlined', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: OutlineIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Indietro',
              onPressed: () {},
            ),
          ),
        ),
      ),
    );
    final material = tester.widget<Material>(
      find.descendant(of: find.byType(OutlineIconButton), matching: find.byType(Material)).first,
    );
    expect(material.color, AppColors.surfaceElevated);
    expect((material.shape! as OutlinedBorder).side.color, AppColors.borderStrong);
    final size = tester.getSize(find.byType(OutlineIconButton));
    expect(size.shortestSide, greaterThanOrEqualTo(48));
  });
}
