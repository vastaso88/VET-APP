import 'package:flutter/widgets.dart';

/// How much of the phone's text-size setting the pages follow: up to twice the
/// size the same phone shows without it (WCAG 1.4.4), whatever its width. Proved
/// at 320 px by test/widget/text_scale_overflow_test.dart.
const maxSystemTextScale = 2.0;

/// The chat has a text size of its own (Impostazioni, Layout) that multiplies
/// this one: there the total growth stops here.
const maxChatTextScale = 1.5;

/// The text size the owner chose in the phone's settings (accessibility), up to
/// [maxSystemTextScale], multiplied by the app's own factor for the screen width
/// ([appFactor], see responsive.dart).
///
/// Works with non-linear system scalers (Android 14+) because it asks the
/// system scaler for the size instead of reading a single number.
class AppTextScaler extends TextScaler {
  const AppTextScaler({required this.system, required this.appFactor});

  final TextScaler system;
  final double appFactor;

  @override
  double scale(double fontSize) {
    final base = fontSize * appFactor;
    final scaled = system.scale(base);
    final cap = base * maxSystemTextScale;
    return scaled > cap ? cap : scaled;
  }

  @override
  double get textScaleFactor => scale(14) / 14;

  @override
  bool operator ==(Object other) =>
      other is AppTextScaler && other.system == system && other.appFactor == appFactor;

  @override
  int get hashCode => Object.hash(system, appFactor);
}
