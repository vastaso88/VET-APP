
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../shared/widgets/pet_loader.dart';
import '../widgets/photo_timeline_view.dart';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../settings/data/gallery_save_settings_store.dart';
import '../../data/device_gallery_saver.dart';
import '../../data/pet_demo_store.dart';
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
  final _picker = ImagePicker();
  late Future<List<PetPhotoEntry>> _photosFuture = _load();
  bool _busy = false;

  /// "Carico 2 di 5..." while an import runs - null otherwise. Set the moment
  /// the picker returns, so the screen answers before any file is read.
  String? _importProgress;

  /// The running import (for "Annulla") and, while a video is being reduced
  /// on the phone, how far along it is (0..1).
  PetMediaImporter? _importer;
  double? _compressFraction;
  bool _cancelling = false;

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

  Future<void> _importFromGallery() async {
    final files = await _picker.pickMultipleMedia(imageQuality: 100);
    await _import(files);
  }

  Future<void> _takePhoto() async {
    final file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 100);
    if (file != null) await _saveCopyToDeviceGallery(file, isVideo: false);
    await _import([if (file != null) file]);
  }

  Future<void> _recordVideo() async {
    final file = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(seconds: petVideoMaxSeconds),
    );
    if (file != null) await _saveCopyToDeviceGallery(file, isVideo: true);
    await _import([if (file != null) file]);
  }

  /// Camera captures only (gallery imports are already on the phone). Runs
  /// before the upload so the copy exists even when the upload fails.
  Future<void> _saveCopyToDeviceGallery(XFile file, {required bool isVideo}) async {
    await GallerySaveSettingsStore.instance.ensureLoaded();
    await const DeviceGallerySaver().save(file, isVideo: isVideo);
  }

  Future<void> _import(List<XFile> files) async {
    if (files.isEmpty || !mounted) return;
    final importer = PetMediaImporter();
    var step = '';
    setState(() {
      _importer = importer;
      _importProgress = 'Preparo ${files.length == 1 ? 'il file' : '${files.length} file'}...';
    });
    try {
      final result = await importer.importAll(
        petId: widget.pet.id,
        files: files,
        onProgress: (current, total) {
          if (!mounted || _cancelling) return;
          step = total == 1 ? '' : ' $current di $total';
          setState(() {
            _compressFraction = null;
            _importProgress = total == 1 ? 'Carico il file...' : 'Carico $current di $total...';
          });
        },
        onCompressProgress: (fraction) {
          if (!mounted || _cancelling) return;
          setState(() {
            _compressFraction = fraction;
            _importProgress = fraction >= 1
                ? 'Carico il video$step...'
                : 'Riduco il video$step... ${(fraction * 100).round()}%';
          });
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.summary())));
    } finally {
      if (mounted) {
        setState(() {
          _importProgress = null;
          _compressFraction = null;
          _importer = null;
          _cancelling = false;
        });
        _reload();
      }
    }
  }

  void _cancelImport() {
    final importer = _importer;
    if (importer == null || _cancelling) return;
    setState(() {
      _cancelling = true;
      _compressFraction = null;
      _importProgress = 'Annullo...';
    });
    unawaited(importer.cancel());
  }

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
        title: Text(photo.isVideo ? 'Eliminare questo video?' : 'Eliminare questa foto?'),
        content: Text(
          photo.isVideo
              ? 'Il video verrà rimosso definitivamente dalla galleria.'
              : 'La foto verrà rimossa definitivamente dalla galleria.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Elimina'),
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
          const SnackBar(content: Text('Non sono riuscito a completare l\'operazione. Riprova.')),
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
            ? _VideoViewerPage(storagePath: photo.storagePath)
            : _PhotoViewerPage(storagePath: photo.storagePath),
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
                title: const Text('Imposta come foto profilo'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _setProfile(photo);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text(photo.isVideo ? 'Elimina video' : 'Elimina foto'),
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
              title: const Text('Importa dalla galleria'),
              subtitle: const Text('Foto e video, anche più di uno'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _importFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Scatta foto'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _takePhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Registra video'),
              subtitle: const Text('Fino a $petVideoMaxSeconds secondi'),
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

  @override
  Widget build(BuildContext context) {
    final pet = _pet;
    return PetsScaffold(
      title: 'Galleria di ${pet.name}',
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
                      'Nessuna foto o video ancora. Usa il pulsante "Aggiungi" qui sotto.',
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
              );
            },
          ),
          Positioned(
            right: AppSpacing.md,
            bottom: AppSpacing.md,
            child: FloatingActionButton.extended(
              heroTag: 'pet-gallery-add',
              onPressed: _busy || _importProgress != null ? null : _showAddSheet,
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Aggiungi'),
            ),
          ),
          if (_busy || _importProgress != null)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.35),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PetLoader(label: _importProgress, color: Colors.white),
                      if (_compressFraction case final fraction?) ...[
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
                      if (_importer != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        OutlinedButton(
                          onPressed: _cancelling ? null : _cancelImport,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white70),
                          ),
                          child: const Text('Annulla'),
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
class _PhotoViewerPage extends StatefulWidget {
  const _PhotoViewerPage({required this.storagePath});

  final String storagePath;

  @override
  State<_PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<_PhotoViewerPage> {
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
          return InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
          );
        },
      ),
    );
  }
}

/// Fullscreen video, streamed from a short-lived signed link (the bucket is
/// private) instead of being downloaded whole. Tap toggles play/pause.
class _VideoViewerPage extends StatefulWidget {
  const _VideoViewerPage({required this.storagePath});

  final String storagePath;

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
          ? const Center(
              child: Text(
                'Non riesco a riprodurre questo video.',
                style: TextStyle(color: Colors.white),
              ),
            )
          : controller == null
              ? const Center(child: PetLoader(label: 'Carico il video...', color: Colors.white))
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
