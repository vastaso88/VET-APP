import 'package:flutter/material.dart';

/// Curated, mutually distinguishable colors a pet owner can pick as their
/// pet's identity color — used for the small avatar badge, the Home
/// calendar markers, and the calendar legend, so the same color always
/// means the same pet across the app.
const List<Color> petIdentityColors = [
  Color(0xFF2F9E68), // verde
  Color(0xFFD98C3D), // ambra
  Color(0xFF5B7FD6), // blu
  Color(0xFFB5563C), // terracotta
  Color(0xFF3D9E9E), // teal
  Color(0xFF9B6BD7), // viola
  Color(0xFFC94F6D), // corallo
  Color(0xFF7A8C3D), // oliva
];

Color defaultIdentityColorForIndex(int index) =>
    petIdentityColors[index % petIdentityColors.length];
