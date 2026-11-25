import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/pet_loader.dart';
import '../../data/pet_demo_store.dart';
import '../../data/pet_photo_repository.dart';
import '../../domain/pet_models.dart';
import '../widgets/pet_avatar.dart';
import 'pet_gallery_page.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/page_header.dart';
import '../../../../shared/widgets/app_card.dart';

/// Attività > Galleria: one folder per pet, two columns. The cover is the
/// current profile photo (or the pet's avatar when there is none).
class GalleryFoldersPage extends StatefulWidget {
  const GalleryFoldersPage({super.key});

  @override
  State<GalleryFoldersPage> createState() => _GalleryFoldersPageState();
}

class _GalleryFoldersPageState extends State<GalleryFoldersPage> {
  late final Future<List<PetProfile>> _pets = _load();

  /// The captions of every folder, read together once the pets are known.
  Future<Map<String, PetMediaCounts>>? _counts;

  Future<List<PetProfile>> _load() async {
    await PetDemoStore.instance.ensureHydrated();
    final pets = PetDemoStore.instance
        .list()
        .where((pet) => !pet.isMemorial)
        .toList(growable: false);
    // One request for all the folders, not one full list per pet.
    _counts = PetPhotoRepository().countsForPets([for (final pet in pets) pet.id]);
    return pets;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PageHeader(title: context.l10n.petsMediaGalleryTitle, showBack: true),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: FutureBuilder<List<PetProfile>>(
                future: _pets,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                        child: PetLoader(label: context.l10n.petsMediaFoldersLoading));
                  }
                  final pets = snapshot.data ?? const <PetProfile>[];
                  if (pets.isEmpty) {
                    return CenteredPageState(
                      child: EmptyState(text: context.l10n.petsMediaFoldersEmpty),
                    );
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      0,
                      AppSpacing.page,
                      AppSpacing.lg,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: AppSpacing.md,
                      crossAxisSpacing: AppSpacing.md,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: pets.length,
                    itemBuilder: (context, index) => _FolderCard(
                      pet: pets[index],
                      counts: _counts!,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => PetGalleryPage(pet: pets[index])),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "12 foto", "12 foto · 2 video" or "1 video" for a folder's caption.
String galleryCountLabel(List<PetPhotoEntry> entries) {
  final videos = entries.where((entry) => entry.isVideo).length;
  return galleryCountLabelFor(PetMediaCounts(photos: entries.length - videos, videos: videos));
}

/// The same caption from counts already read (no list of entries needed).
String galleryCountLabelFor(PetMediaCounts counts) {
  final l10n = appL10n;
  final videos = counts.videos;
  final photos = counts.photos;
  if (videos == 0) return l10n.petsMediaCountPhotos(photos);
  if (photos == 0) return l10n.petsMediaCountVideos(videos);
  return l10n.petsMediaCountPhotosAndVideos(
    l10n.petsMediaCountPhotos(photos),
    l10n.petsMediaCountVideos(videos),
  );
}

class _FolderCard extends StatefulWidget {
  const _FolderCard({required this.pet, required this.counts, required this.onTap});

  final PetProfile pet;
  final Future<Map<String, PetMediaCounts>> counts;
  final VoidCallback onTap;

  @override
  State<_FolderCard> createState() => _FolderCardState();
}

class _FolderCardState extends State<_FolderCard> {
  late final Future<Uint8List?>? _cover = widget.pet.photoPath == null
      ? null
      : PetPhotoRepository().loadThumbnail(widget.pet.photoPath!);

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: widget.onTap,
      padding: EdgeInsets.zero,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _cover == null ? _avatarCover() : _photoCover()),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.pet.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.title.copyWith(fontSize: 16)),
                  const SizedBox(height: AppSpacing.xs),
                  FutureBuilder<Map<String, PetMediaCounts>>(
                    future: widget.counts,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return const SizedBox.shrink();
                      final counts = snapshot.data;
                      return Text(
                        counts == null
                            ? context.l10n.petsMediaFolderCounting
                            : galleryCountLabelFor(
                                counts[widget.pet.id] ?? const PetMediaCounts(),
                              ),
                        style: AppTextStyles.caption,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
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
