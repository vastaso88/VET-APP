import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';

class PetAvatar extends StatelessWidget {
  const PetAvatar({
    required this.label,
    required this.backgroundColor,
    super.key,
    this.size = 72,
    this.photoBytes,
    this.identityColor,
  });

  final String label;
  final Color backgroundColor;
  final double size;

  /// When set, the avatar shows this photo (circular) instead of the plain
  /// letter tile, with a small [identityColor] badge on its bottom-right
  /// edge so the pet stays recognizable by color even with a photo.
  final Uint8List? photoBytes;
  final Color? identityColor;

  @override
  Widget build(BuildContext context) {
    final photo = photoBytes;
    if (photo == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(AppRadii.large),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: size * 0.42,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
        ),
      );
    }

    final badgeSize = size * 0.38;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipOval(
            child: Image.memory(
              photo,
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            right: -badgeSize * 0.08,
            bottom: -badgeSize * 0.08,
            child: Container(
              width: badgeSize,
              height: badgeSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: identityColor ?? backgroundColor,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 2),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: badgeSize * 0.48,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
