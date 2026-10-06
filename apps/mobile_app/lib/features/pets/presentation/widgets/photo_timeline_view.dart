import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../shared/widgets/pet_loader.dart';
import '../../data/pet_photo_repository.dart';
import '../../domain/pet_video_rules.dart';

const _monthsIt = [
  'gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno',
  'luglio', 'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre',
];

/// Fixed layout of the timeline. Every height is derived from these and the
/// photo counts, so scroll offsets are exact rather than estimated.
const timelineColumns = 3;
const timelineTileSpacing = AppSpacing.xs;
const timelineHeaderHeight = 28.0;
const timelineSectionGap = AppSpacing.lg;
const timelineTopPadding = AppSpacing.md;
const timelineLeftPadding = AppSpacing.lg;
const timelineRightPadding = AppSpacing.xl;

/// Height of one section's grid: square tiles, [timelineColumns] per row.
double timelineGridHeight(int photoCount, double contentWidth) {
  if (photoCount == 0) return 0;
  final tile = (contentWidth - (timelineColumns - 1) * timelineTileSpacing) / timelineColumns;
  final rows = (photoCount + timelineColumns - 1) ~/ timelineColumns;
  return rows * tile + (rows - 1) * timelineTileSpacing;
}

/// Top offset of every section, in list order, measured from the top of the
/// list (padding included). The last entry is the end of the last section.
List<double> timelineSectionOffsets(List<int> photoCounts, double viewportWidth) {
  final contentWidth = viewportWidth - timelineLeftPadding - timelineRightPadding;
  final offsets = <double>[];
  var y = timelineTopPadding;
  for (final count in photoCounts) {
    offsets.add(y);
    y += timelineHeaderHeight + timelineGridHeight(count, contentWidth) + timelineSectionGap;
  }
  offsets.add(y);
  return offsets;
}

/// The section whose top is the last one at or above [offset].
int timelineSectionAt(List<double> offsets, double offset) {
  var low = 0;
  var high = offsets.length - 2;
  if (high < 0) return 0;
  while (low < high) {
    final mid = (low + high + 1) ~/ 2;
    if (offsets[mid] <= offset) {
      low = mid;
    } else {
      high = mid - 1;
    }
  }
  return low;
}

/// Photos grouped by the local day they were taken, newest first, with a
/// heading per day and a scrubber on the right. Shared by a pet's gallery and
/// the folders in Attività.
class PhotoTimelineView extends StatefulWidget {
  const PhotoTimelineView({
    required this.photos,
    required this.onOpen,
    this.onLongPress,
    super.key,
  });

  final List<PetPhotoEntry> photos;
  final void Function(PetPhotoEntry photo) onOpen;
  final void Function(PetPhotoEntry photo)? onLongPress;

  @override
  State<PhotoTimelineView> createState() => _PhotoTimelineViewState();
}

class _PhotoTimelineViewState extends State<PhotoTimelineView> {
  static const _labelLinger = Duration(seconds: 2);

  final _scroll = ScrollController();
  late List<PhotoDayGroup> _groups = groupPhotosByDay(widget.photos);
  String? _scrubLabel;
  Timer? _hideLabel;

  @override
  void didUpdateWidget(covariant PhotoTimelineView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photos != widget.photos) _groups = groupPhotosByDay(widget.photos);
  }

  @override
  void dispose() {
    _hideLabel?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  /// [fraction] is the drag position on the scrubber, 0 at the top, 1 at the
  /// bottom. It maps to the scroll offset exactly, and the label names the
  /// month of the section that offset falls in.
  void _scrubTo(double fraction, double viewportWidth) {
    if (_groups.isEmpty || !_scroll.hasClients) return;
    final target = fraction.clamp(0.0, 1.0) * _scroll.position.maxScrollExtent;
    final offsets = timelineSectionOffsets(
      [for (final group in _groups) group.photos.length],
      viewportWidth,
    );
    final section = timelineSectionAt(offsets, target);
    _scroll.jumpTo(target);
    _hideLabel?.cancel();
    setState(() => _scrubLabel = _groups[section].monthLabel);
  }

  void _releaseScrub() {
    _hideLabel?.cancel();
    _hideLabel = Timer(_labelLinger, () {
      if (mounted) setState(() => _scrubLabel = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final contentWidth = width - timelineLeftPadding - timelineRightPadding;
        return Stack(
          children: [
            ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(
                timelineLeftPadding,
                timelineTopPadding,
                timelineRightPadding,
                AppSpacing.xxl,
              ),
              itemCount: _groups.length,
              itemBuilder: (context, index) {
                final group = _groups[index];
                return SizedBox(
                  height: timelineHeaderHeight +
                      timelineGridHeight(group.photos.length, contentWidth) +
                      timelineSectionGap,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: timelineHeaderHeight,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(group.label, style: AppTextStyles.title.copyWith(fontSize: 16)),
                        ),
                      ),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: timelineColumns,
                        mainAxisSpacing: timelineTileSpacing,
                        crossAxisSpacing: timelineTileSpacing,
                        children: [
                          for (final photo in group.photos)
                            PhotoThumb(
                              key: ValueKey(photo.storagePath),
                              photo: photo,
                              onTap: () => widget.onOpen(photo),
                              onLongPress: widget.onLongPress == null
                                  ? null
                                  : () => widget.onLongPress!(photo),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: AppSpacing.xxxl,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragStart: (d) => _scrubTo(d.localPosition.dy / height, width),
                onVerticalDragUpdate: (d) => _scrubTo(d.localPosition.dy / height, width),
                onVerticalDragEnd: (_) => _releaseScrub(),
                onVerticalDragCancel: _releaseScrub,
                onTapDown: (d) => _scrubTo(d.localPosition.dy / height, width),
                onTapUp: (_) => _releaseScrub(),
                child: Align(
                  alignment: Alignment.topRight,
                  child: _scrubLabel == null
                      ? const SizedBox.shrink()
                      : Container(
                          margin: const EdgeInsets.only(top: AppSpacing.xl, right: AppSpacing.sm),
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                          child: Text(
                            _scrubLabel!,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.onPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One square thumbnail. Bytes load on first build, so a long list only pays
/// for the photos on screen.
class PhotoThumb extends StatefulWidget {
  const PhotoThumb({required this.photo, required this.onTap, this.onLongPress, super.key});

  final PetPhotoEntry photo;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  State<PhotoThumb> createState() => _PhotoThumbState();
}

class _PhotoThumbState extends State<PhotoThumb> {
  // A video is never downloaded for the grid: it gets a play tile instead
  // (no poster frame without a native thumbnail plugin).
  late final Future<Uint8List?>? _bytes =
      widget.photo.isVideo ? null : PetPhotoRepository().loadBytes(widget.photo.storagePath);

  @override
  Widget build(BuildContext context) {
    if (widget.photo.isVideo) {
      return InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          child: _VideoTile(durationSeconds: widget.photo.durationSeconds),
        ),
      );
    }
    return InkWell(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      borderRadius: BorderRadius.circular(AppRadii.medium),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        child: FutureBuilder<Uint8List?>(
          future: _bytes,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const ColoredBox(
                color: AppColors.surfaceElevated,
                child: Center(child: PetLoader.small()),
              );
            }
            final bytes = snapshot.data;
            if (bytes == null) {
              return const ColoredBox(
                color: AppColors.surfaceElevated,
                child: Icon(Icons.broken_image_outlined, color: AppColors.mutedText),
              );
            }
            return Image.memory(bytes, fit: BoxFit.cover, cacheWidth: 300);
          },
        ),
      ),
    );
  }
}

/// Dark tile with a play button and the length, standing in for a video's
/// first frame.
class _VideoTile extends StatelessWidget {
  const _VideoTile({this.durationSeconds});

  final int? durationSeconds;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Video',
      child: ColoredBox(
        color: const Color(0xFF163A35),
        child: Stack(
          children: [
            const Center(
              child: Icon(Icons.play_circle_fill_rounded, size: 40, color: Colors.white70),
            ),
            if (durationSeconds != null)
              Positioned(
                right: AppSpacing.xs,
                bottom: AppSpacing.xs,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    petVideoDurationLabel(durationSeconds!),
                    style: AppTextStyles.caption.copyWith(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class PhotoDayGroup {
  PhotoDayGroup(this.label, this.monthLabel, this.photos);

  final String label;
  final String monthLabel;
  final List<PetPhotoEntry> photos;
}

/// Groups by the local day of [PetPhotoEntry.createdAt], newest day first.
List<PhotoDayGroup> groupPhotosByDay(List<PetPhotoEntry> photos) {
  final sorted = [...photos]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final groups = <PhotoDayGroup>[];
  String? currentKey;
  for (final photo in sorted) {
    final local = photo.createdAt.toLocal();
    final key = '${local.year}-${local.month}-${local.day}';
    if (key != currentKey) {
      currentKey = key;
      groups.add(PhotoDayGroup(
        photoDayLabel(local),
        '${_monthsIt[local.month - 1]} ${local.year}',
        [],
      ));
    }
    groups.last.photos.add(photo);
  }
  return groups;
}

String photoDayLabel(DateTime local) => '${local.day} ${_monthsIt[local.month - 1]} ${local.year}';
