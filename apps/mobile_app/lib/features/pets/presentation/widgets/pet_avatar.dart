import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../design_system/responsive.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../data/pet_photo_repository.dart';

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
    this.photoPath,
  });

  final String label;
  final Color backgroundColor;
  final Color identityColor;
  final double size;
  final Uint8List? photoBytes;

  /// Storage path of a persisted photo, loaded when [photoBytes] isn't in
  /// memory (e.g. a pet fetched from Supabase on a fresh session).
  final String? photoPath;

  @override
  Widget build(BuildContext context) {
    final photo = photoBytes;
    // Scaled to the real screen width so the avatar keeps its proportions
    // on narrower/wider phones (see design_system/responsive.dart) instead
    // of staying pinned to its reference-width pixel size.
    final scaledSize = size * appScaleOf(context);
    final badgeSize = scaledSize * 0.44;

    final letter = Container(
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
    );

    final Widget content;
    if (photo != null) {
      content = Image.memory(photo, width: scaledSize, height: scaledSize, fit: BoxFit.cover);
    } else if (photoPath != null) {
      content = _StoredPetPhoto(path: photoPath!, size: scaledSize, fallback: letter);
    } else {
      content = letter;
    }

    return SizedBox(
      width: scaledSize,
      height: scaledSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipOval(child: content),
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

class _StoredPetPhoto extends StatefulWidget {
  const _StoredPetPhoto({required this.path, required this.size, required this.fallback});

  final String path;
  final double size;
  final Widget fallback;

  @override
  State<_StoredPetPhoto> createState() => _StoredPetPhotoState();
}

class _StoredPetPhotoState extends State<_StoredPetPhoto> {
  late Future<Uint8List?> _bytes = PetPhotoRepository().loadBytes(widget.path);

  @override
  void didUpdateWidget(covariant _StoredPetPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _bytes = PetPhotoRepository().loadBytes(widget.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _bytes,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) return widget.fallback;
        return Image.memory(bytes, width: widget.size, height: widget.size, fit: BoxFit.cover);
      },
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
