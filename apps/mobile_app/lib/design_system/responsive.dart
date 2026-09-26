import 'package:flutter/widgets.dart';

/// Reference viewport this app's mobile layouts are tuned against — sizes,
/// spacing and fonts read correctly at this width. [appScaleOf] derives a
/// scale factor from the current screen width relative to this reference,
/// so the same proportions hold on narrower or wider phones instead of
/// clipping/overflowing at one fixed size or floating unchanged on another.
const double referenceScreenWidth = 339;

/// Scale factor for non-text sizes (avatars, icons, calendar markers) that
/// don't go through [TextScaler] and so need to opt into scaling
/// explicitly. Clamped to the realistic phone range so a wide desktop
/// preview window doesn't blow icons up absurdly.
double appScaleOf(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return (width / referenceScreenWidth).clamp(0.85, 1.35);
}
