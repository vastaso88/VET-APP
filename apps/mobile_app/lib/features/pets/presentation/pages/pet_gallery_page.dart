
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../shared/widgets/pet_loader.dart';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../data/pet_demo_store.dart';
import '../../data/pet_photo_repository.dart';
import '../../domain/pet_models.dart';
import '../widgets/pets_scaffold.dart';

/// Every photo of one pet, newest first: profile pictures saved over time
/// plus anything added from the camera or gallery here.
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

  Future<void> _add(ImageSource source) async {
    final file = await _picker.pickImage(source: source, imageQuality: 100);
    if (file == null) return;
    final raw = await file.readAsBytes();
    await _run(() async {
      final jpeg = await compute(compressPetPhoto, raw);
      await _repository.upload(petId: widget.pet.id, compressedJpeg: jpeg, isProfile: false);
    });
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
        title: const Text('Eliminare questa foto?'),
        content: const Text('La foto verrà rimossa definitivamente dalla galleria.'),
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
      MaterialPageRoute<void>(builder: (_) => _PhotoViewerPage(storagePath: photo.storagePath)),
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
            if (!photo.isProfile)
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
              title: const Text('Elimina foto'),
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
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Scatta una foto'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _add(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Scegli dalla galleria'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _add(ImageSource.gallery);
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
      actions: [
        IconButton(
          tooltip: 'Aggiungi foto',
          onPressed: _busy ? null : _showAddSheet,
          icon: const Icon(Icons.add_a_photo_outlined),
          color: Colors.white,
        ),
      ],
      body: FutureBuilder<List<PetPhotoEntry>>(
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
                  'Nessuna foto ancora. Aggiungine una dal pulsante in alto.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall,
                ),
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 160,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
            ),
            itemCount: photos.length,
            itemBuilder: (context, index) {
              final photo = photos[index];
              return _PhotoTile(
                key: ValueKey(photo.storagePath),
                photo: photo,
                onTap: () => _openViewer(photo),
                onLongPress: () => _showActions(photo),
              );
            },
          );
        },
      ),
    );
  }
}

class _PhotoTile extends StatefulWidget {
  const _PhotoTile({
    required this.photo,
    required this.onTap,
    required this.onLongPress,
    super.key,
  });

  final PetPhotoEntry photo;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  State<_PhotoTile> createState() => _PhotoTileState();
}

class _PhotoTileState extends State<_PhotoTile> {
  late final Future<Uint8List?> _bytes = PetPhotoRepository().loadBytes(widget.photo.storagePath);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      borderRadius: BorderRadius.circular(AppRadii.medium),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        child: Stack(
          fit: StackFit.expand,
          children: [
            FutureBuilder<Uint8List?>(
              future: _bytes,
              builder: (context, snapshot) {
                final bytes = snapshot.data;
                if (bytes == null) {
                  return const ColoredBox(color: AppColors.surfaceElevated);
                }
                return Image.memory(bytes, fit: BoxFit.cover);
              },
            ),
            if (widget.photo.isProfile)
              const Positioned(
                left: AppSpacing.xs,
                top: AppSpacing.xs,
                child: Icon(Icons.account_circle, color: Colors.white, size: 20),
              ),
          ],
        ),
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
