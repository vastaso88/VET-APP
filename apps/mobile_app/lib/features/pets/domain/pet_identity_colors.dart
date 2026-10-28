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
