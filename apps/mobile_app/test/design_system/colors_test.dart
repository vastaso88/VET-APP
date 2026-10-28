import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/design_system/tokens/app_colors.dart';

/// Files that may still write a colour themselves, with the reason.
const _allowed = <String, String>{
  // The PDF of the clinical history is drawn with the `pdf` package's own
  // colour type, outside the Flutter widgets (paper-friendly greys).
  'lib/features/medical_records/presentation/history_pdf.dart': 'PdfColor, printed paper',
};

final _hardCodedColor = RegExp(
  r'(^|[^A-Za-z])(Color\(0x|Color\.from(ARGB|RGBO)\(|Colors\.(?!transparent\b)[a-zA-Z])',
);

double _luminance(Color color) {
  double channel(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) + 0.7152 * channel(color.g) + 0.0722 * channel(color.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  test('no page writes a colour of its own: everything comes from AppColors', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (path.startsWith('lib/design_system/tokens/') || _allowed.containsKey(path)) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trimLeft();
        if (line.startsWith('//')) continue;
        if (_hardCodedColor.hasMatch(line)) offenders.add('$path:${i + 1}: ${line.trim()}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Add the colour to lib/design_system/tokens/app_colors.dart (60% neutral, '
          '30% secondary, 10% accent, or a status/media/category colour) and use the '
          'token. Offenders:\n${offenders.join('\n')}',
    );
  });

  group('contrast (WCAG AA) of the pairs that carry text', () {
    final pairs = <String, (Color, Color, double)>{
      'text on background': (AppColors.text, AppColors.background, 4.5),
      'text on surface': (AppColors.text, AppColors.surface, 4.5),
      'secondaryText on background': (AppColors.secondaryText, AppColors.background, 4.5),
      'mutedText on background': (AppColors.mutedText, AppColors.background, 4.5),
      'mutedText on surface': (AppColors.mutedText, AppColors.surface, 4.5),
      'mutedText on white': (AppColors.mutedText, AppColors.surfaceElevated, 4.5),
      'onPrimary on primary': (AppColors.onPrimary, AppColors.primary, 4.5),
      'onPrimary on primaryStrong': (AppColors.onPrimary, AppColors.primaryStrong, 4.5),
      'primary on background': (AppColors.primary, AppColors.background, 4.5),
      'primary on secondarySoft': (AppColors.primary, AppColors.secondarySoft, 4.5),
      'primary on primarySoft': (AppColors.primary, AppColors.primarySoft, 4.5),
      'primaryStrong on secondarySoft': (AppColors.primaryStrong, AppColors.secondarySoft, 4.5),
      'secondaryStrong on secondarySoft': (AppColors.secondaryStrong, AppColors.secondarySoft, 4.5),
      'secondaryStrong on background': (AppColors.secondaryStrong, AppColors.background, 4.5),
      'danger on background': (AppColors.danger, AppColors.background, 4.5),
      'onPrimary on danger': (AppColors.onPrimary, AppColors.danger, 4.5),
      'dangerStrong on dangerSoft': (AppColors.dangerStrong, AppColors.dangerSoft, 4.5),
      'warningStrong on warningSoft': (AppColors.warningStrong, AppColors.warningSoft, 4.5),
      'successStrong on successSoft': (AppColors.successStrong, AppColors.successSoft, 4.5),
      'infoStrong on infoSoft': (AppColors.infoStrong, AppColors.infoSoft, 4.5),
      'secondary icons on background': (AppColors.secondary, AppColors.background, 3.0),
      'success icon on background': (AppColors.success, AppColors.background, 3.0),
      'warning icon on background': (AppColors.warning, AppColors.background, 3.0),
      'info icon on background': (AppColors.info, AppColors.background, 3.0),
    };
    pairs.forEach((name, spec) {
      test(name, () {
        expect(_contrast(spec.$1, spec.$2), greaterThanOrEqualTo(spec.$3));
      });
    });
  });

  test('the accent stays clear of the radar category colours', () {
    final categories = [
      AppCategoryColors.veterinary,
      AppCategoryColors.shop,
      AppCategoryColors.dogPark,
      AppCategoryColors.shelter,
      AppCategoryColors.association,
      AppCategoryColors.grooming,
      AppCategoryColors.hotel,
      AppCategoryColors.school,
      AppCategoryColors.petSitting,
      AppCategoryColors.breeder,
      AppCategoryColors.other,
    ];
    double distance(Color a, Color b) =>
        math.sqrt(math.pow((a.r - b.r) * 255, 2) + math.pow((a.g - b.g) * 255, 2) + math.pow((a.b - b.b) * 255, 2));

    for (final category in categories) {
      expect(distance(category, AppColors.primary), greaterThan(40), reason: '$category vs accent');
      expect(distance(category, AppColors.secondary), greaterThan(40), reason: '$category vs sage');
    }
    for (var i = 0; i < categories.length; i++) {
      for (var j = i + 1; j < categories.length; j++) {
        expect(distance(categories[i], categories[j]), greaterThan(30),
            reason: 'categories $i and $j must stay distinguishable');
      }
    }
  });

  test('the page gradient is the same three steps everywhere', () {
    expect(AppColors.backgroundGradient, [AppColors.surface, AppColors.background, AppColors.backgroundDeep]);
  });
}
