import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../shared/widgets/pet_loader.dart';
import '../../data/pet_demo_store.dart';
import '../../data/pet_photo_repository.dart';
import '../../domain/pet_models.dart';
import '../widgets/pet_avatar.dart';
import '../widgets/pets_scaffold.dart';
import 'pet_gallery_page.dart';

/// Attività > Galleria: one folder per pet, two columns. The cover is the
/// current profile photo (or the pet's avatar when there is none).
class GalleryFoldersPage extends StatefulWidget {
  const GalleryFoldersPage({super.key});

  @override
  State<GalleryFoldersPage> createState() => _GalleryFoldersPageState();
}

class _GalleryFoldersPageState extends State<GalleryFoldersPage> {
  late final Future<List<PetProfile>> _pets = _load();

  Future<List<PetProfile>> _load() async {
    await PetDemoStore.instance.ensureHydrated();
    return PetDemoStore.instance.list().where((pet) => !pet.isMemorial).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return PetsScaffold(
      title: 'Galleria',
      subtitle: 'Le foto dei tuoi animali, per cartella.',
      onBack: () => Navigator.of(context).maybePop(),
      body: FutureBuilder<List<PetProfile>>(
        future: _pets,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: PetLoader(label: 'Carico le cartelle…'));
          }
          final pets = snapshot.data ?? const <PetProfile>[];
          if (pets.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  'Aggiungi un animale per creare la sua cartella di foto.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall,
                ),
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 0.82,
            ),
            itemCount: pets.length,
            itemBuilder: (context, index) => _FolderCard(
              pet: pets[index],
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => PetGalleryPage(pet: pets[index])),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FolderCard extends StatefulWidget {
  const _FolderCard({required this.pet, required this.onTap});

  final PetProfile pet;
  final VoidCallback onTap;

  @override
  State<_FolderCard> createState() => _FolderCardState();
}

class _FolderCardState extends State<_FolderCard> {
  late final Future<List<PetPhotoEntry>> _photos = PetPhotoRepository().list(widget.pet.id);
  late final Future<Uint8List?>? _cover =
      widget.pet.photoPath == null ? null : PetPhotoRepository().loadBytes(widget.pet.photoPath!);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(AppRadii.large),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.large),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _cover == null ? _avatarCover() : _photoCover()),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.pet.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.title.copyWith(fontSize: 16)),
                  const SizedBox(height: AppSpacing.xs),
                  FutureBuilder<List<PetPhotoEntry>>(
                    future: _photos,
                    builder: (context, snapshot) {
                      final count = snapshot.data?.length;
                      return Text(
                        count == null ? 'Conto le foto…' : '$count foto',
                        style: AppTextStyles.caption,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarCover() {
    return Center(
      child: PetAvatar(
        label: widget.pet.avatarEmoji,
        backgroundColor: widget.pet.accentColor,
        identityColor: widget.pet.identityColor,
        size: 84,
      ),
    );
  }

  Widget _photoCover() {
    return FutureBuilder<Uint8List?>(
      future: _cover,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) return _avatarCover();
        return Image.memory(bytes, fit: BoxFit.cover, width: double.infinity);
      },
    );
  }
}
