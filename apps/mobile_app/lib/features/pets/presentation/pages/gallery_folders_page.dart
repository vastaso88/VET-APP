import 'package:flutter/material.dart';

import '../../../../design_system/responsive.dart';
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

/// Attività > Galleria: one folder per pet, two columns. The cover is the pet's
/// photo; a pet without photos is an invitation to add one.
class GalleryFoldersPage extends StatefulWidget {
  const GalleryFoldersPage({super.key});

  @override
  State<GalleryFoldersPage> createState() => _GalleryFoldersPageState();
}

class _GalleryFoldersPageState extends State<GalleryFoldersPage> {
  late final Future<void> _ready = PetDemoStore.instance.ensureHydrated();

  /// The captions of every folder, read together once the pets are known.
  Future<Map<String, PetMediaCounts>>? _counts;

  @override
  void initState() {
    super.initState();
    PetDemoStore.changes.addListener(_petsChanged);
  }

  @override
  void dispose() {
    PetDemoStore.changes.removeListener(_petsChanged);
    super.dispose();
  }

  void _petsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _open(PetProfile pet, {bool adding = false}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PetGalleryPage(pet: pet, startAdding: adding)),
    );
    // Photos may have been added or removed there.
    if (mounted) setState(() => _counts = null);
  }

  /// Two, but one with a text so large that a word would break in half a screen.
  int _columns(BuildContext context) {
    final half = (MediaQuery.sizeOf(context).width - 2 * AppSpacing.page - AppSpacing.md) / 2;
    final word = MediaQuery.textScalerOf(context).scale(14) * 6;
    return word <= half - 2 * AppSpacing.md ? 2 : 1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PageHeader(title: context.l10n.petsMediaGalleryTitle, showBack: true),
      body: SafeArea(
        top: false,
        child: FutureBuilder<void>(
          future: _ready,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: PetLoader(label: context.l10n.petsMediaFoldersLoading));
            }
            final pets = PetDemoStore.instance.list();
            if (pets.isEmpty) {
              return CenteredPageState(
                child: EmptyState(text: context.l10n.petsMediaFoldersEmpty),
              );
            }
            // One request for all the folders, not one full list per pet.
            final counts = _counts ??=
                PetPhotoRepository().countsForPets([for (final pet in pets) pet.id]);
            final columns = _columns(context);
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                0,
                AppSpacing.page,
                AppSpacing.lg,
              ),
              itemCount: (pets.length / columns).ceil(),
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
              // As tall as their texts need, the same in a row.
              itemBuilder: (context, row) => IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: AppSpacing.md,
                  children: [
                    for (var i = row * columns; i < (row + 1) * columns; i++)
                      Expanded(
                        child: i < pets.length
                            ? _FolderCard(pet: pets[i], counts: counts, onOpen: _open)
                            : const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
            );
          },
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

bool _hasFace(PetProfile pet) => pet.photoBytes != null || pet.photoPath != null;

class _FolderCard extends StatelessWidget {
  const _FolderCard({required this.pet, required this.counts, required this.onOpen});

  final PetProfile pet;
  final Future<Map<String, PetMediaCounts>> counts;
  final void Function(PetProfile pet, {bool adding}) onOpen;

  static const _coverHeight = 132.0;
  static const _faceSize = 40.0;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, PetMediaCounts>>(
      future: counts,
      builder: (context, snapshot) {
        final all = snapshot.data;
        final read = all == null ? null : all[pet.id] ?? const PetMediaCounts();
        final none = read != null && read.photos == 0 && read.videos == 0;
        if (none && !_hasFace(pet)) return _invitation(context);
        return _folder(
          context,
          switch (read) {
            _ when snapshot.hasError => null,
            null => context.l10n.petsMediaFolderCounting,
            // The face saved before the gallery existed is the one photo in it.
            _ when none && pet.photoPath != null =>
              galleryCountLabelFor(const PetMediaCounts(photos: 1)),
            final counts => galleryCountLabelFor(counts),
          },
        );
      },
    );
  }

  Widget _folder(BuildContext context, String? caption) {
    final scale = appScaleOf(context);
    final side = petRingAvatarExtent(context, _faceSize) + 2 * _faceEdge;
    return AppCard(
      onTap: () => onOpen(pet),
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: _coverHeight * scale, child: _cover()),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  _hasFace(pet) ? side / 2 + AppSpacing.xs : AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: _texts(
                  caption == null ? null : Text(caption, style: AppTextStyles.caption),
                ),
              ),
            ],
          ),
          if (_hasFace(pet))
            Positioned(
              left: AppSpacing.md,
              top: _coverHeight * scale - side / 2,
              child: Container(
                padding: const EdgeInsets.all(_faceEdge),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  shape: BoxShape.circle,
                ),
                child: PetRingAvatar(pet: pet, size: _faceSize),
              ),
            ),
        ],
      ),
    );
  }

  static const _faceEdge = 3.0;

  Widget _cover() {
    final figure = ColoredBox(
      color: AppColors.secondarySoft,
      child: Center(child: PetRingAvatar(pet: pet.copyWith(clearPhoto: true), size: 72)),
    );
    if (pet.photoBytes case final bytes?) {
      return PetPhoto(key: ObjectKey(bytes), bytes: bytes, side: _coverHeight, fallback: figure);
    }
    if (pet.photoPath case final path?) {
      return StoredPetPhoto(
        key: ValueKey(path),
        path: path,
        side: _coverHeight,
        fallback: figure,
      );
    }
    return figure;
  }

  Widget _invitation(BuildContext context) {
    final scale = appScaleOf(context);
    return AppCard(
      dashed: true,
      borderColor: AppColors.primary,
      onTap: () => onOpen(pet, adding: true),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: _coverHeight * scale,
            color: AppColors.primarySoft,
            alignment: Alignment.center,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              child: Icon(Icons.add_rounded, size: 28, color: AppColors.onPrimary),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: _texts(
              Text(
                context.l10n.petsFormPhotoAdd,
                style: AppTextStyles.caption.copyWith(color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _texts(Widget? caption) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            pet.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.title.copyWith(fontSize: 16),
          ),
          if (caption != null) ...[const SizedBox(height: AppSpacing.xs), caption],
        ],
      );
}
