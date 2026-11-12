import 'package:flutter/widgets.dart';

/// Largest total growth of any text: the phone's text-size setting times the
/// app's own screen-width factor. Past this, screens stop fitting.
const maxTextScaleFactor = 1.5;

/// The text size the owner chose in the phone's settings (accessibility),
/// multiplied by the app's own factor for the screen width ([appFactor], see
/// responsive.dart), and capped at [maxTextScaleFactor] overall.
///
/// Works with non-linear system scalers (Android 14+) because it asks the
/// system scaler for the size instead of reading a single number.
class AppTextScaler extends TextScaler {
  const AppTextScaler({required this.system, required this.appFactor});

  final TextScaler system;
  final double appFactor;

  @override
  double scale(double fontSize) {
    final scaled = system.scale(fontSize * appFactor);
    final cap = fontSize * maxTextScaleFactor;
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
