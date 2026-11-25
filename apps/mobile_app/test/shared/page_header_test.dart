import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vet_app_mobile/app/theme/app_theme.dart';
import 'package:vet_app_mobile/design_system/app_text_scaler.dart';
import 'package:vet_app_mobile/design_system/atoms/outline_icon_button.dart';
import 'package:vet_app_mobile/design_system/responsive.dart';
import 'package:vet_app_mobile/design_system/tokens/app_colors.dart';
import 'package:vet_app_mobile/design_system/tokens/app_spacing.dart';
import 'package:vet_app_mobile/design_system/tokens/app_text_styles.dart';
import 'package:vet_app_mobile/l10n/app_localizations.dart';
import 'package:vet_app_mobile/shared/widgets/page_header.dart';

Widget _app(Widget page) => MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('it'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final factor = (mq.size.width / referenceScreenWidth).clamp(0.85, 1.35);
        return MediaQuery(
          data: mq.copyWith(textScaler: AppTextScaler(system: mq.textScaler, appFactor: factor)),
          child: child!,
        );
      },
      initialRoute: '/page',
      routes: {'/': (_) => const Text('sotto'), '/page': (_) => page},
    );

Widget _page(String title, {List<Widget> actions = const [], bool? showBack}) => Scaffold(
      appBar: PageHeader(title: title, actions: actions, showBack: showBack),
      body: const SizedBox.expand(child: Text('corpo')),
    );

void _phone(WidgetTester tester, Size size, {double text = 1}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = text;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
}

/// One header for the sister pages (test round, card X07).
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('arrow in an outlined circle, big title beside it, one margin', (tester) async {
    _phone(tester, const Size(390, 844));
    await tester.pumpWidget(_app(_page('Eventi')));
    await tester.pumpAndSettle();

    final arrow = find.byType(OutlineIconButton);
    expect(arrow, findsOneWidget);
    expect(tester.getTopLeft(arrow).dx, AppSpacing.page);
    final title = tester.widget<Text>(find.text('Eventi'));
    expect(title.style!.fontSize, AppTextStyles.heading.fontSize);
    expect(tester.getTopLeft(find.text('Eventi')).dx, greaterThan(tester.getTopRight(arrow).dx));
    // The header takes only what it needs: the page starts right under it.
    expect(tester.getTopLeft(find.text('corpo')).dy, lessThan(90));
    final scaffold = tester.widget<Material>(
      find.descendant(of: find.byType(Scaffold), matching: find.byType(Material)).first,
    );
    expect(scaffold.color, AppColors.background);
  });

  testWidgets('the arrow goes back, and a page that asks first is still asked', (tester) async {
    var asked = 0;
    await tester.pumpWidget(_app(PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => asked++,
      child: _page('Le mie inserzioni'),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Indietro'));
    await tester.pumpAndSettle();
    expect(asked, 1);
    expect(find.text('Le mie inserzioni'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_app(_page('Eventi')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Indietro'));
    await tester.pumpAndSettle();
    expect(find.text('sotto'), findsOneWidget);
  });

  testWidgets('no arrow on a page that cannot be left', (tester) async {
    await tester.pumpWidget(_app(_page('Account chiuso', showBack: false)));
    await tester.pumpAndSettle();
    expect(find.byType(OutlineIconButton), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: _page('Prima pagina'),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(OutlineIconButton), findsNothing);
  });

  final commands = [
    OutlineIconButton(icon: Icons.info_outline, tooltip: 'Informazioni', onPressed: () {}),
    OutlineIconButton(icon: Icons.mail_outline_rounded, tooltip: 'Messaggi', onPressed: () {}),
  ];
  for (final (size, text) in const [
    (Size(390, 844), 1.0),
    (Size(320, 568), 1.3),
    (Size(320, 568), 2.4),
  ]) {
    testWidgets('a long title with two commands is whole at ${size.width.round()} px, text x$text',
        (tester) async {
      _phone(tester, size, text: text);
      const title = 'Mercatino degli animali';
      await tester.pumpWidget(_app(_page(title, actions: commands)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final paragraph = tester.renderObject(
        find.descendant(of: find.text(title), matching: find.byType(RichText)),
      );
      expect((paragraph as dynamic).didExceedMaxLines, isFalse, reason: 'no dots');
      for (final tooltip in ['Indietro', 'Informazioni', 'Messaggi']) {
        final size = tester.getSize(find.byTooltip(tooltip));
        expect(size.shortestSide, greaterThanOrEqualTo(40), reason: tooltip);
      }
    });
  }

  for (final back in [true, false]) {
    testWidgets('no word of the title is broken on two lines (arrow: $back)', (tester) async {
      _phone(tester, const Size(320, 568), text: 1.3);
      const title = 'Abbonamento e pagamenti';
      await tester.pumpWidget(_app(_page(title, showBack: back)));
      await tester.pumpAndSettle();
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: find.text(title), matching: find.byType(RichText)),
      );
      for (final word in ['Abbonamento', 'pagamenti']) {
        final start = title.indexOf(word);
        final boxes = paragraph.getBoxesForSelection(
          TextSelection(baseOffset: start, extentOffset: start + word.length),
        );
        expect(boxes.map((box) => box.top).toSet(), hasLength(1), reason: word);
      }
    });
  }

  testWidgets('read as the title of the page', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(_page('Eventi')));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.text('Eventi')),
      isSemantics(label: 'Eventi', isHeader: true, namesRoute: true),
    );
    handle.dispose();
  });

  test('no page makes a header of its own', () {
    // Full-screen photo, video and image on black, and the developers' map preview.
    const allowed = {
      'lib/features/pets/presentation/pages/pet_gallery_page.dart',
      'lib/features/medical_records/presentation/record_file_actions.dart',
      'lib/app/preview/maps_demo_page.dart',
    };
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (allowed.contains(path)) continue;
      if (RegExp(r'[^A-Za-z]AppBar\(').hasMatch(entity.readAsStringSync())) offenders.add(path);
    }
    expect(offenders, isEmpty, reason: 'use PageHeader');
  });

  test('the header is at the same height on the pages that scroll as a whole', () {
    for (final path in [
      'lib/features/activities/presentation/pages/activities_page.dart',
      'lib/features/reminders/presentation/widgets/reminder_page_parts.dart',
      'lib/features/settings/presentation/pages/settings_page.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('padding: EdgeInsets.zero'), reason: path);
      expect(source, contains('PageHeader.top'), reason: path);
    }
  });

  test('one background: no page paints a gradient under itself', () {
    final offenders = <String>[];
    for (final entity in Directory('lib/features').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.readAsStringSync().contains('LinearGradient(')) offenders.add(entity.path);
    }
    expect(offenders, isEmpty, reason: 'pages are flat AppColors.background');
  });
}
