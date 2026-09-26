import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../design_system/responsive.dart';
import '../../../../design_system/tokens/app_colors.dart';

/// A pet's avatar: a big circle holding either its photo or its initial
/// letter, with a colored identity badge on its bottom-right edge so the
/// same pet reads as the same color everywhere (calendar, legend, lists) —
/// whether or not it has a photo.
class PetAvatar extends StatelessWidget {
  const PetAvatar({
    required this.label,
    required this.backgroundColor,
    required this.identityColor,
    super.key,
    this.size = 72,
    this.photoBytes,
  });

  final String label;
  final Color backgroundColor;
  final Color identityColor;
  final double size;
  final Uint8List? photoBytes;

  @override
  Widget build(BuildContext context) {
    final photo = photoBytes;
    // Scaled to the real screen width so the avatar keeps its proportions
    // on narrower/wider phones (see design_system/responsive.dart) instead
    // of staying pinned to its reference-width pixel size.
    final scaledSize = size * appScaleOf(context);
    final badgeSize = scaledSize * 0.44;

    return SizedBox(
      width: scaledSize,
      height: scaledSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipOval(
            child: photo != null
                ? Image.memory(photo, width: scaledSize, height: scaledSize, fit: BoxFit.cover)
                : Container(
                    width: scaledSize,
                    height: scaledSize,
                    color: backgroundColor,
                    alignment: Alignment.center,
                    child: _NoTextScaling(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: scaledSize * 0.42,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                  ),
          ),
          Positioned(
            right: -badgeSize * 0.05,
            bottom: -badgeSize * 0.05,
            child: Container(
              width: badgeSize,
              height: badgeSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: identityColor,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surfaceElevated, width: 2.5),
                boxShadow: const [
                  BoxShadow(color: AppColors.shadow, blurRadius: 4, offset: Offset(0, 1)),
                ],
              ),
              child: _NoTextScaling(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: badgeSize * 0.46,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The avatar letter's size is already derived from [appScaleOf] above via
/// `scaledSize`, so it shouldn't also be multiplied by the ambient
/// [TextScaler] the app sets globally — that would double-scale it.
class _NoTextScaling extends StatelessWidget {
  const _NoTextScaling({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: child,
    );
  }
}
