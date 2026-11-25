import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vet_app_mobile/app/theme/app_theme.dart';
import 'package:vet_app_mobile/design_system/tokens/app_colors.dart';
import 'package:vet_app_mobile/design_system/tokens/app_radii.dart';
import 'package:vet_app_mobile/l10n/app_localizations.dart';
import 'package:vet_app_mobile/shared/widgets/app_card.dart';
import 'package:vet_app_mobile/shared/widgets/app_field.dart';
import 'package:vet_app_mobile/shared/widgets/empty_state.dart';
import 'package:vet_app_mobile/shared/widgets/quokka_logo.dart';
import 'package:vet_app_mobile/shared/widgets/typed_date_field.dart';

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

Iterable<(String, String)> _sources(String root) sync* {
  for (final entity in Directory(root).listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    yield (entity.path.replaceAll(r'\', '/'), entity.readAsStringSync());
  }
}

/// One field, one card, one empty state (test round, card X11).
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('card', () {
    Material of(WidgetTester tester) => tester.widget<Material>(
          find.descendant(of: find.byType(AppCard), matching: find.byType(Material)).first,
        );

    testWidgets('white and round; a visible edge only when it opens something', (tester) async {
      await tester.pumpWidget(_app(const AppCard(child: Text('letta'))));
      var shape = of(tester).shape! as RoundedRectangleBorder;
      expect(of(tester).color, AppColors.surfaceElevated);
      expect(shape.borderRadius, BorderRadius.circular(AppRadii.large));
      expect(shape.side.color, AppColors.border);
      expect(of(tester).elevation, 0);

      var taps = 0;
      await tester.pumpWidget(_app(AppCard(onTap: () => taps++, child: const Text('toccata'))));
      shape = of(tester).shape! as RoundedRectangleBorder;
      expect(shape.side.color, AppColors.borderStrong);
      await tester.tap(find.text('toccata'));
      expect(taps, 1);

      await tester.pumpWidget(_app(const AppCard(selected: true, child: Text('scelta'))));
      shape = of(tester).shape! as RoundedRectangleBorder;
      expect(shape.side.color, AppColors.primary);
      expect(shape.side.width, 2);
    });
  });

  group('empty state', () {
    testWidgets('the light Quokka, a sentence and one command, all centred', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_app(EmptyState(
        title: 'Niente qui',
        text: 'Una frase breve.',
        action: FilledButton(onPressed: () => taps++, child: const Text('Aggiungi')),
      )));
      expect(find.byType(QuokkaHeadRound), findsOneWidget);
      final centre = tester.getCenter(find.byType(AppCard)).dx;
      for (final finder in [
        find.byType(QuokkaHeadRound),
        find.text('Niente qui'),
        find.text('Una frase breve.'),
        find.text('Aggiungi'),
      ]) {
        expect(tester.getCenter(finder).dx, closeTo(centre, 1));
      }
      await tester.tap(find.text('Aggiungi'));
      expect(taps, 1);
    });

    testWidgets('next to an error an icon, never the mascot', (tester) async {
      await tester.pumpWidget(_app(EmptyState.icon(icon: Icons.cloud_off_outlined, text: 'Errore')));
      expect(find.byType(QuokkaHeadRound), findsNothing);
      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
    });

    testWidgets('it scrolls where it does not fit', (tester) async {
      tester.view.physicalSize = const Size(320, 300);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: CenteredPageState(
            child: EmptyState(
              title: 'Un titolo piuttosto lungo',
              text: 'Una frase che occupa parecchie righe quando il testo è molto grande.',
              action: FilledButton(onPressed: () {}, child: const Text('Aggiungi')),
            ),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
    });

    test('health, Ricordi, reminders and billing never show the mascot', () {
      const roots = [
        'lib/features/medical_records',
        'lib/features/monitoring',
        'lib/features/reminders',
        'lib/features/billing',
        'lib/features/chat',
      ];
      final files = [
        for (final root in roots) ..._sources(root),
        ..._sources('lib/features/pets').where((s) => s.$1.contains('memor')),
      ];
      final offenders = [
        for (final (path, text) in files)
          if (RegExp(r'[^.A-Za-z]EmptyState\(').hasMatch(text) || text.contains('QuokkaHead')) path,
      ];
      expect(offenders, isEmpty, reason: 'EmptyState.icon or EmptyState.figure there');
    });
  });

  group('field', () {
    testWidgets('its name above, whole, and spoken for the field', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(
        AppField(
          label: 'Numero di telefono (facoltativo)',
          child: TextFormField(decoration: const InputDecoration(hintText: 'Es. 1234')),
        ),
      ));
      expect(
        tester.getBottomLeft(find.text('Numero di telefono (facoltativo)')).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.byType(TextFormField)).dy),
      );
      final node = tester.getSemantics(find.byType(EditableText));
      expect(node.label, contains('Numero di telefono (facoltativo)'));
      // Once, not twice: the writing above is for the eye.
      expect(find.bySemanticsLabel(RegExp('Numero di telefono')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a date: spoken with its name, its calendar button with its own', (tester) async {
      final handle = tester.ensureSemantics();
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AppField(
            label: 'Data',
            child: TypedDateField(
              controller: controller,
              decoration: const InputDecoration(hintText: 'gg/mm/aaaa'),
              onPick: () {},
              pickIcon: const Icon(Icons.calendar_today_outlined),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      final field = tester.getSemantics(find.byType(EditableText));
      expect(field.label, contains('Data'));
      expect(field, isSemantics(isTextField: true));
      expect(
        tester.getSemantics(find.byTooltip('Apri il calendario')),
        isSemantics(isButton: true, tooltip: 'Apri il calendario'),
      );
      handle.dispose();
    });

    testWidgets('a list to choose from: spoken with its name', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(
        AppField(
          label: 'Categoria',
          child: DropdownButtonFormField<int>(
            initialValue: 0,
            items: const [DropdownMenuItem(value: 0, child: Text('Guinzagli'))],
            onChanged: (_) {},
          ),
        ),
      ));
      expect(find.bySemanticsLabel(RegExp('Categoria')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Guinzagli')), findsWidgets);
      handle.dispose();
    });

    testWidgets('a picked value looks like the other fields', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_app(
        AppField(
          label: 'Ora',
          child: PickerField(text: '09:00', icon: Icons.schedule_rounded, onTap: () => taps++),
        ),
      ));
      final field = AppTheme.light().inputDecorationTheme;
      final material = tester.widget<Material>(
        find.descendant(of: find.byType(PickerField), matching: find.byType(Material)).first,
      );
      expect(material.color, field.fillColor);
      expect(material.shape, field.enabledBorder);
      expect(tester.getSize(find.byType(PickerField)).height, greaterThanOrEqualTo(48));
      await tester.tap(find.text('09:00'));
      expect(taps, 1);
    });

    test('no form writes the name inside the field', () {
      final offenders = [
        for (final (path, text) in _sources('lib'))
          if (text.contains('labelText:')) path,
      ];
      expect(offenders, isEmpty, reason: 'use AppField');
    });
  });
}
