import 'package:flutter/material.dart';
import '../../../design_system/tokens/app_colors.dart';

/// Curated, mutually distinguishable colors a pet owner can pick as their
/// pet's identity color — used for the small avatar badge, the Home
/// calendar markers, and the calendar legend, so the same color always
/// means the same pet across the app.
const List<Color> petIdentityColors = [
  AppIdentityColors.green, // verde
  AppIdentityColors.amber, // ambra
  AppIdentityColors.blue, // blu
  AppIdentityColors.terracotta, // terracotta
  AppIdentityColors.teal, // teal
  AppIdentityColors.violet, // viola
  AppIdentityColors.coral, // corallo
  AppIdentityColors.olive, // oliva
];

Color defaultIdentityColorForIndex(int index) =>
    petIdentityColors[index % petIdentityColors.length];

/// The color of a pet saved without one: always the same for the same pet, and usually not the
/// same for two of them (the species tint, used before, was pale and equal for every dog).
Color defaultIdentityColorForId(String id) => defaultIdentityColorForIndex(
      id.codeUnits.fold(0, (sum, unit) => (sum * 31 + unit) & 0x3fffffff),
    );
