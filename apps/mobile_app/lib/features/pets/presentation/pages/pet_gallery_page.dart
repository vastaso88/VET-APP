
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/launch/route_restoration.dart';
import '../../../../shared/widgets/pet_loader.dart';
import '../widgets/photo_timeline_view.dart';

import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/auth/current_owner.dart';
import '../../../dog_walks/data/dog_walks_repository.dart';
import '../../../dog_walks/domain/photo_walk_match.dart';
import '../../../dog_walks/domain/walk_session.dart';
import '../../data/pet_demo_store.dart';
import '../../data/pet_media_capture.dart';
import '../../data/pet_media_importer.dart';
import '../../data/pet_photo_repository.dart';
import '../../domain/pet_models.dart';
import '../../domain/pet_video_rules.dart';
import '../widgets/pets_scaffold.dart';

/// Every photo and short video of one pet, newest first: profile pictures
/// saved over time plus anything imported from the gallery or recorded here.
class PetGalleryPage extends StatefulWidget {
  const PetGalleryPage({required this.pet, super.key});

  final PetProfile pet;

  @override
  State<PetGalleryPage> createState() => _PetGalleryPageState();
}

class _PetGalleryPageState extends State<PetGalleryPage> {
  final _repository = PetPhotoRepository();
  late Future<List<PetPhotoEntry>> _photosFuture = _load();
  bool _busy = false;

  /// This pet's walks, for the "Passeggiata del ..." captions. Empty until
  /// loaded (or for a pet that never walks): photos just show no caption.
  List<WalkSession> _walks = const [];

  @override
  void initState() {
    super.initState();
    _loadWalks();
  }

  @override
  void dispose() {
    _capture.dispose();
    super.dispose();
  }

  Future<void> _loadWalks() async {
    try {
      final walks = await DogWalksRepository().loadWalks(resolveCurrentOwnerId());
      if (!mounted) return;
      setState(() {
        _walks = [
          for (final walk in walks)
            if (walk.petId == widget.pet.id && walk.status != WalkStatus.discarded) walk,
        ];
      });
    } catch (_) {
      // Captions are a nicety: the gallery works the same without them.
    }
  }

  /// "Passeggiata del 07/10/26" when the photo was taken during one of this
  /// pet's walks (owner request, 2026-10-07); null otherwise or when the
  /// shooting time is unknown.
  String? _walkCaption(PetPhotoEntry photo) {
    final takenAt = photo.takenAt;
    if (takenAt == null || _walks.isEmpty) return null;
    final walk = walkForPhoto(takenAt, _walks);
    return walk == null ? null : walkPhotoLabel(walk);
  }

  /// The shared camera / import flow (also behind the walk's camera button):
  /// its progress drives the overlay below.
  late final PetMediaCapture _capture = PetMediaCapture()..addListener(_onCaptureChanged);

  void _onCaptureChanged() {
    if (mounted) setState(() {});
  }

  PetProfile get _pet =>
      PetDemoStore.instance.list().where((p) => p.id == widget.pet.id).firstOrNull ?? widget.pet;

  Future<List<PetPhotoEntry>> _load() async {
    final photos = await _repository.list(widget.pet.id);
    final profilePath = _pet.photoPath;
    if (profilePath != null && photos.every((p) => p.storagePath != profilePath)) {
      // A profile photo saved before the gallery existed has no pet_photos row.
      return [
        PetPhotoEntry(
          id: 'profile',
          petId: widget.pet.id,
          storagePath: profilePath,
          createdAt: DateTime.now(),
          isProfile: true,
        ),
        ...photos,
      ];
    }
    return photos;
  }

  void _reload() => setState(() => _photosFuture = _load());

  /// Runs one of the capture actions, then confirms it and refreshes the grid.
  Future<void> _runCapture(Future<PetMediaImportResult?> Function() action) async {
    final result = await action();
    if (!mounted || result == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.confirmation(_pet.name))),
    );
    _reload();
  }

  Future<void> _importFromGallery() => _runCapture(() => _capture.importFromGallery(widget.pet.id));

  Future<void> _takePhoto() => _runCapture(() => _capture.takePhoto(widget.pet.id));

  Future<void> _recordVideo() => _runCapture(() => _capture.recordVideo(widget.pet.id));

  Future<void> _setProfile(PetPhotoEntry photo) async {
    await _run(() async {
      await _repository.setProfile(photo);
      await PetDemoStore.instance.upsert(
        _pet.copyWith(photoPath: photo.storagePath, clearPhoto: true),
      );
    });
  }

  Future<void> _delete(PetPhotoEntry photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(photo.isVideo
            ? context.l10n.petsMediaDeleteVideoTitle
            : context.l10n.petsMediaDeletePhotoTitle),
        content: Text(
          photo.isVideo
              ? context.l10n.petsMediaDeleteVideoBody
              : context.l10n.petsMediaDeletePhotoBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() async {
      await _repository.delete(photo);
      if (photo.isProfile) {
        await PetDemoStore.instance.upsert(_pet.copyWith(clearPhoto: true));
      }
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.petsMediaOperationFailed)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _reload();
      }
    }
  }

  void _openViewer(PetPhotoEntry photo) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => photo.isVideo
            ? _VideoViewerPage(storagePath: photo.storagePath, caption: _walkCaption(photo))
            : PetPhotoViewerPage(storagePath: photo.storagePath, caption: _walkCaption(photo)),
      ),
    );
  }

  void _showActions(PetPhotoEntry photo) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!photo.isProfile && !photo.isVideo)
              ListTile(
                leading: const Icon(Icons.account_circle_outlined),
                title: Text(context.l10n.petsMediaSetAsProfile),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _setProfile(photo);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text(photo.isVideo
                  ? context.l10n.petsMediaDeleteVideoAction
                  : context.l10n.petsMediaDeletePhotoAction),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _delete(photo);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(context.l10n.petsMediaImportFromGallery),
              subtitle: Text(context.l10n.petsMediaImportFromGalleryHint),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _importFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(context.l10n.petsMediaTakePhoto),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _takePhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: Text(context.l10n.petsMediaRecordVideo),
              subtitle: Text(context.l10n.petsMediaRecordVideoLimit(petVideoMaxSeconds)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _recordVideo();
              },
            ),
          ],
        ),
      ),
    );
  }

  // Remembered while open, so it can be reopened after a restart (restoration).
  @override
  Widget build(BuildContext context) {
    return RestorationMarker(
      kind: 'pet_gallery',
      args: () => {'petId': widget.pet.id},
      child: _buildPage(context),
    );
  }

  Widget _buildPage(BuildContext context) {
    final pet = _pet;
    return PetsScaffold(
      title: context.l10n.petsMediaGalleryOf(pet.name),
      onBack: () => Navigator.of(context).maybePop(),
      body: Stack(
        children: [
          FutureBuilder<List<PetPhotoEntry>>(
            future: _photosFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: PetLoader());
              }
              final photos = snapshot.data ?? const <PetPhotoEntry>[];
              if (photos.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Center(
                    child: Text(
                      context.l10n.petsMediaGalleryEmpty,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall,
                    ),
                  ),
                );
              }
              return PhotoTimelineView(
                photos: photos,
                onOpen: _openViewer,
                onLongPress: _showActions,
                captionFor: _walkCaption,
              );
            },
          ),
          Positioned(
            right: AppSpacing.md,
            bottom: AppSpacing.md,
            child: FloatingActionButton.extended(
              heroTag: 'pet-gallery-add',
              onPressed: _busy || _capture.busy ? null : _showAddSheet,
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: Text(context.l10n.commonAdd),
            ),
          ),
          if (_busy || _capture.busy)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.35),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PetLoader(label: _capture.progress, color: Colors.white),
                      if (_capture.compressFraction case final fraction?) ...[
                        const SizedBox(height: AppSpacing.sm),
                        SizedBox(
                          width: 200,
                          child: LinearProgressIndicator(
                            value: fraction,
                            color: Colors.white,
                            backgroundColor: Colors.white24,
                          ),
                        ),
                      ],
                      if (_capture.canCancel) ...[
                        const SizedBox(height: AppSpacing.md),
                        OutlinedButton(
                          onPressed: _capture.cancelling ? null : _capture.cancel,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white70),
                          ),
                          child: Text(context.l10n.commonCancel),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Fullscreen photo. Rotation is allowed here only: the app is otherwise
/// portrait-locked, so the lock is restored when the viewer closes.
class PetPhotoViewerPage extends StatefulWidget {
  const PetPhotoViewerPage({required this.storagePath, this.caption, super.key});

  final String storagePath;

  /// "Passeggiata del ..." under the photo, when it was taken on a walk.
  final String? caption;

  @override
  State<PetPhotoViewerPage> createState() => _PetPhotoViewerPageState();
}

class _PetPhotoViewerPageState extends State<PetPhotoViewerPage> {
  late final Future<Uint8List?> _bytes = PetPhotoRepository().loadBytes(widget.storagePath);

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<Uint8List?>(
        future: _bytes,
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes == null) {
            return const Center(
              child: PetLoader(color: Colors.white),
            );
          }
          final caption = widget.caption;
          return Column(
            children: [
              Expanded(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
                ),
              ),
              if (caption != null) _ViewerCaption(caption),
            ],
          );
        },
      ),
    );
  }
}

/// Fullscreen video, streamed from a short-lived signed link (the bucket is
/// private) instead of being downloaded whole. Tap toggles play/pause.
class _VideoViewerPage extends StatefulWidget {
  const _VideoViewerPage({required this.storagePath, this.caption});

  final String storagePath;
  final String? caption;

  @override
  State<_VideoViewerPage> createState() => _VideoViewerPageState();
}

class _VideoViewerPageState extends State<_VideoViewerPage> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _open();
  }

  Future<void> _open() async {
    final url = await PetPhotoRepository().signedVideoUrl(widget.storagePath);
    if (url == null) {
      if (mounted) setState(() => _failed = true);
      return;
    }
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await controller.initialize();
    } catch (_) {
      await controller.dispose();
      if (mounted) setState(() => _failed = true);
      return;
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }
    controller.addListener(_onTick);
    setState(() => _controller = controller);
    await controller.play();
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.isPlaying) {
      controller.pause();
    } else if (controller.value.position >= controller.value.duration) {
      controller.seekTo(Duration.zero).then((_) => controller.play());
    } else {
      controller.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _failed
          ? Center(
              child: Text(
                context.l10n.petsMediaVideoPlaybackFailed,
                style: const TextStyle(color: Colors.white),
              ),
            )
          : controller == null
              ? Center(child: PetLoader(label: context.l10n.petsMediaVideoLoading, color: Colors.white))
              : Column(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _togglePlay,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Center(
                              child: AspectRatio(
                                aspectRatio: controller.value.aspectRatio,
                                child: VideoPlayer(controller),
                              ),
                            ),
                            if (!controller.value.isPlaying)
                              const Icon(Icons.play_circle_fill_rounded, size: 72, color: Colors.white70),
                          ],
                        ),
                      ),
                    ),
                    if (widget.caption != null) _ViewerCaption(widget.caption!),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: VideoProgressIndicator(
                        controller,
                        allowScrubbing: true,
                        colors: const VideoProgressColors(
                          playedColor: Colors.white,
                          bufferedColor: Colors.white38,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

/// The walk caption under a full-screen photo or video.
class _ViewerCaption extends StatelessWidget {
  const _ViewerCaption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pets_rounded, size: 16, color: Colors.white70),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                text,
                style: AppTextStyles.bodySmall.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
