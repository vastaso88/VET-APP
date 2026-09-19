import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTextStyles {
  static TextStyle get display => GoogleFonts.fraunces(
        fontSize: 36,
        height: 1.12,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.7,
        color: AppColors.text,
      );

  static TextStyle get heading => GoogleFonts.fraunces(
        fontSize: 24,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.35,
        color: AppColors.text,
      );

  static TextStyle get title => GoogleFonts.fraunces(
        fontSize: 20,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: AppColors.text,
      );

  static TextStyle get body => GoogleFonts.figtree(
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: AppColors.secondaryText,
      );

  static TextStyle get bodySmall => GoogleFonts.figtree(
        fontSize: 14,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: AppColors.secondaryText,
      );

  static TextStyle get caption => GoogleFonts.figtree(
        fontSize: 12,
        height: 1.35,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: AppColors.mutedText,
      );

  static TextStyle get button => GoogleFonts.figtree(
        fontSize: 16,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
      );
}
