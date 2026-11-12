import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../data/profile_photo_repository.dart';

/// The owner's round avatar: their photo when they have one, otherwise the
/// first letter of their name on the brand colour.
class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({
    super.key,
    required this.letter,
    this.avatarPath,
    this.previewBytes,
    this.size = 40,
  });

  final String letter;
  final String? avatarPath;

  /// A photo just picked and not saved yet; shown instead of the stored one.
  final Uint8List? previewBytes;
  final double size;

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatarPath != widget.avatarPath) _load();
  }

  Future<void> _load() async {
    final path = widget.avatarPath;
    if (path == null) {
      if (_bytes != null) setState(() => _bytes = null);
      return;
    }
    final bytes = await ProfilePhotoRepository().download(path);
    if (mounted && path == widget.avatarPath) setState(() => _bytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.previewBytes ?? _bytes;
    return Container(
      width: widget.size,
      height: widget.size,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(color: AppColors.primaryStrong, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: photo != null
          ? Image.memory(photo, width: widget.size, height: widget.size, fit: BoxFit.cover)
          : Text(
              widget.letter,
              style: AppTextStyles.title.copyWith(
                color: AppColors.onPrimary,
                fontSize: widget.size * 0.4,
              ),
            ),
    );
  }
}
