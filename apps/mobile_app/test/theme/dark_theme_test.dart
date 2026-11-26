import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vet_app_mobile/app/theme/app_theme.dart';
import 'package:vet_app_mobile/app/theme/phone_palette.dart';
import 'package:vet_app_mobile/design_system/tokens/app_colors.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_models.dart';
import 'package:vet_app_mobile/features/pets/presentation/widgets/pet_avatar.dart';
import 'package:vet_app_mobile/shared/widgets/app_card.dart';
import 'package:vet_app_mobile/shared/widgets/empty_state.dart';
import 'package:vet_app_mobile/shared/widgets/page_header.dart';

/// Where a colour that does not change with the theme may be written, and why.
/// Everything else reads the palette in use through AppColors.
const _fixedColours = <String, Map<String, String>>{
  // The light palette itself: only the tokens and the theme pick a palette.
  r'AppPalette\.(light|dark)\b': {
    'lib/app/theme/app_theme.dart': 'builds one theme from each palette',
    'lib/features/medical_records/presentation/history_export.dart': 'the PDF is paper',
  },
  // White and black of photos, video and maps: the same in both themes, so only
  // over a photo, a scrim, a map or a fill that keeps its colour (white on white
  // would vanish in the light theme, white on a light fill in the dark one).
  r'AppColors\.(onMedia\w*|scrim\w*|mediaBackground)\b': {
    'lib/app/splash/loading_animation.dart': 'alpha mask of the splash strip',
    'lib/app/theme/app_theme.dart': 'scrim behind dialogs',
    'lib/features/dog_walks/presentation/pages/active_walk_page.dart': 'over the map and its scrim',
    'lib/features/dog_walks/presentation/pages/walk_detail_page.dart': 'photo dots on the map',
    'lib/features/dog_walks/presentation/widgets/badge_earned_dialog.dart': 'dialog barrier',
    'lib/features/dog_walks/presentation/widgets/walk_mini_map.dart': 'route edge on the tiles',
    'lib/features/dog_walks/presentation/widgets/walk_route_markers_layer.dart': 'markers on the tiles',
    'lib/features/marketplace/presentation/pages/create_listing_page.dart': 'close button over a photo',
    'lib/features/marketplace/presentation/pages/marketplace_map_page.dart': 'markers on the tiles',
    'lib/features/medical_records/presentation/record_file_actions.dart': 'black image viewer',
    'lib/features/nearby_places/presentation/radar_category.dart': 'ring of a mark on a fixed fill',
    'lib/features/nearby_places/presentation/widgets/radar_map.dart': 'markers on the tiles',
    'lib/features/pets/presentation/pages/pet_gallery_page.dart': 'photo and video viewer',
    'lib/features/pets/presentation/widgets/pet_profile_form.dart': 'tick on an identity colour',
    'lib/features/pets/presentation/widgets/photo_timeline_view.dart': 'caption over a photo',
  },
  // A pet's pale card tint, a value stored with the pet (never drawn as a ground).
  r'AppIdentityColors\.tint\w+': {
    'lib/features/pets/data/pet_demo_store.dart': 'stored species tint',
    'lib/features/pets/domain/pet_models.dart': 'stored species tint',
  },
  // A pet's identity colour as stored: drawn through AppIdentityColors.shown.
  r'AppIdentityColors\.(green|amber|blue|terracotta|teal|violet|coral|olive|palette)\b': {
    'lib/features/pets/domain/pet_identity_colors.dart': 'the choice offered to the owner',
    'lib/features/pets/domain/pet_models.dart': 'colour stored with the demo pets',
  },
  // The radar categories as stored: drawn through AppCategoryColors.shown.
  r'AppCategoryColors\.(?!shown\b)\w+': {
    'lib/features/nearby_places/presentation/radar_category.dart': 'the category table',
    'lib/app/preview/maps_demo_page.dart': 'a route on the tiles (preview page)',
  },
  // The brand ground: the quokka is always paper on petrol.
  r'AppColors\.brand(Deep|Paper)\b': {
    'lib/app/splash/splash_page.dart': 'opening screen, same as the native splash',
    'lib/shared/widgets/quokka_logo.dart': 'the logo on its own petrol ground',
  },
  // What is drawn on the map tiles, which stay light in both themes.
  r'AppColors\.map\b': {
    'lib/features/nearby_places/presentation/widgets/radar_map.dart': 'markers on the tiles',
    'lib/features/marketplace/presentation/pages/marketplace_map_page.dart': 'markers on the tiles',
    'lib/features/dog_walks/presentation/widgets/walk_mini_map.dart': 'route on the tiles',
    'lib/features/dog_walks/presentation/widgets/walk_route_markers_layer.dart': 'markers on the tiles',
    'lib/features/dog_walks/presentation/pages/active_walk_page.dart': 'route on the tiles',
    'lib/features/dog_walks/presentation/pages/walk_detail_page.dart': 'route and photo dots on the tiles',
    'lib/features/location/presentation/center_pin_map_picker.dart': 'pin on the tiles',
    'lib/app/preview/maps_demo_page.dart': 'markers on the tiles',
  },
};

/// A colour or a text style kept in a field or a top-level variable keeps the
/// value of the theme it was read in: read them in build() instead.
final _cached = RegExp(
  r'^(\s{0,2})(static\s+)?(late\s+)?final\s+[^=(]*=[^;]*\b(AppColors\.(?!map\b|brand|onMedia|mediaBackground|scrim)\w+|AppTextStyles\.)',
);

Iterable<(String, int, String)> _lines() sync* {
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final path = entity.path.replaceAll(r'\', '/');
    if (path.startsWith('lib/design_system/tokens/')) continue;
    final lines = entity.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trimLeft().startsWith('//')) continue;
      yield (path, i + 1, lines[i]);
    }
  }
}

double _luminance(Color color) => color.computeLuminance();

/// Reads a colour in build() under a const parent: it changes only if the
/// whole tree is rebuilt.
class _Probe extends StatelessWidget {
  const _Probe();

  @override
  Widget build(BuildContext context) => ColoredBox(
        key: const ValueKey('probe'),
        color: AppColors.surfaceElevated,
        child: const SizedBox.square(dimension: 10),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  tearDown(() => AppColors.use(AppPalette.light));

  test('colours that do not change with the theme are written only where they belong', () {
    final offenders = <String>[];
    for (final (path, line, text) in _lines()) {
      _fixedColours.forEach((pattern, allowed) {
        if (RegExp(pattern).hasMatch(text) && !allowed.containsKey(path)) {
          offenders.add('$path:$line: ${text.trim()}');
        }
      });
    }
    expect(offenders, isEmpty,
        reason: 'Read the colour through AppColors (it follows the theme), or add the '
            'file to _fixedColours with the reason.\n${offenders.join('\n')}');
  });

  test('no colour or text style is kept in a field or a top-level variable', () {
    final offenders = [
      for (final (path, line, text) in _lines())
        if (_cached.hasMatch(text)) '$path:$line: ${text.trim()}',
    ];
    expect(offenders, isEmpty,
        reason: 'It would keep the light value in the dark theme. Offenders:\n'
            '${offenders.join('\n')}');
  });

  test('the two palettes name the same roles, and the dark one is dark', () {
    expect(AppPalette.light.brightness, Brightness.light);
    expect(AppPalette.dark.brightness, Brightness.dark);
    expect(_luminance(AppPalette.dark.background), lessThan(0.05));
    expect(_luminance(AppPalette.dark.text), greaterThan(0.7));
    AppColors.use(AppPalette.dark);
    expect(AppColors.background, AppPalette.dark.background);
    expect(AppColors.isDark, isTrue);
    expect(AppIdentityColors.shown(AppIdentityColors.terracotta), isNot(AppIdentityColors.terracotta));
    expect(AppCategoryColors.shown(AppCategoryColors.shelter), isNot(AppCategoryColors.shelter));
    AppColors.use(AppPalette.light);
    expect(AppColors.background, AppPalette.light.background);
    expect(AppIdentityColors.shown(AppIdentityColors.terracotta), AppIdentityColors.terracotta);
  });

  testWidgets('the dark theme sets what dialogs, sheets and snack bars read', (tester) async {
    final scheme = AppTheme.dark().colorScheme;
    final p = AppPalette.dark;
    expect(scheme.brightness, Brightness.dark);
    expect(scheme.surface, p.surface);
    expect(scheme.onSurface, p.text);
    expect(scheme.onSurfaceVariant, p.secondaryText);
    expect(scheme.surfaceContainerHigh, p.surfaceElevated);
    expect(scheme.inverseSurface, p.text);
    expect(scheme.onInverseSurface, p.background);
    expect(AppTheme.dark().scaffoldBackgroundColor, p.background);
    expect(AppTheme.dark().textTheme.bodyLarge!.color, p.secondaryText);
    // Built while the dark palette is in use, the light theme is still light.
    AppColors.use(AppPalette.dark);
    expect(AppTheme.light().textTheme.displayLarge!.color, AppPalette.light.text);
    expect(AppTheme.light().scaffoldBackgroundColor, AppPalette.light.background);
  });

  testWidgets('the app follows the phone: dark at the start, light after a switch', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(PhonePalette(
      builder: (_) => MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        themeAnimationDuration: Duration.zero,
        home: const Scaffold(body: Center(child: _Probe())),
      ),
    ));
    Color probe() => tester.widget<ColoredBox>(find.byKey(const ValueKey('probe'))).color;
    Color page() => tester
        .widget<Material>(
            find.descendant(of: find.byType(Scaffold), matching: find.byType(Material)).first)
        .color!;

    expect(AppColors.isDark, isTrue);
    expect(probe(), AppPalette.dark.surfaceElevated);
    expect(page(), AppPalette.dark.background);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pump();
    expect(AppColors.isDark, isFalse);
    expect(probe(), AppPalette.light.surfaceElevated);
    expect(page(), AppPalette.light.background);
  });

  testWidgets('in the dark theme the shared pieces paint no light ground', (tester) async {
    AppColors.use(AppPalette.dark);
    final pet = PetProfile(
      id: 'p',
      name: 'Lilla',
      species: 'Gatto',
      breed: '',
      birthDateLabel: '',
      sex: '',
      weightLabel: '',
      medicalNote: '',
      healthBadge: '',
      nextVisitLabel: '',
      avatarEmoji: 'L',
      accentColor: AppIdentityColors.tintAmber,
      identityColor: AppIdentityColors.terracotta,
    );
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        appBar: const PageHeader(title: 'Titolo'),
        body: ListView(
          children: [
            AppCard(onTap: () {}, child: const Text('Una scheda')),
            const EmptyState(title: 'Niente', text: 'Ancora niente qui.'),
            PetRingAvatar(pet: pet),
            const ListTile(title: Text('Riga')),
            const TextField(decoration: InputDecoration(labelText: 'Campo')),
          ],
        ),
      ),
    ));
    await tester.pump();

    final light = <String>[];
    for (final element in find.byType(Widget).evaluate()) {
      final render = element.renderObject;
      Color? ground;
      if (render is RenderDecoratedBox && render.decoration is BoxDecoration) {
        ground = (render.decoration as BoxDecoration).color;
      } else if (render is RenderPhysicalShape) {
        ground = render.color;
      }
      if (ground == null || ground.a < 0.5) continue;
      // The quokka's own paper and petrol, the only light ground allowed.
      if (ground == AppColors.brandPaper || ground == AppColors.brandDeep) continue;
      if (_luminance(ground) > 0.3) light.add('${element.widget.runtimeType}: $ground');
    }
    expect(light, isEmpty);

    final paragraphs = tester.renderObjectList<RenderParagraph>(find.byType(RichText));
    for (final paragraph in paragraphs) {
      final color = paragraph.text.style?.color;
      if (color != null) {
        expect(_luminance(color), greaterThan(0.3), reason: paragraph.text.toPlainText());
      }
    }
  });
}
