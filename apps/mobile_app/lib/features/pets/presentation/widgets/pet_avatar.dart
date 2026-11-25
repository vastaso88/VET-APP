import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../design_system/responsive.dart';
import '../../data/pet_photo_repository.dart';
import '../../domain/pet_models.dart';
import 'species_figure.dart';

/// Side on screen of a [PetRingAvatar] of [size].
double petRingAvatarExtent(BuildContext context, double size) => size * appScaleOf(context);

/// The pet's face in a ring of its own colour, the same on every page: its
/// photo or, without one, the flat figure of its species.
class PetRingAvatar extends StatelessWidget {
  PetRingAvatar({super.key, required PetProfile pet, this.size = 48})
      : species = pet.species,
        breed = pet.breed,
        photoBytes = pet.photoBytes,
        photoPath = pet.photoPath,
        color = pet.identityColor;

  /// An animal still being written (the form).
  const PetRingAvatar.draft({
    super.key,
    required this.species,
    this.breed,
    this.photoBytes,
    this.photoPath,
    required this.color,
    this.size = 48,
  });

  /// In the header of a page about one animal.
  static const headerSize = 40.0;

  final String species;
  final String? breed;

  /// A photo picked in this session.
  final Uint8List? photoBytes;

  /// Storage path of the saved photo, loaded when [photoBytes] isn't in memory
  /// (e.g. a pet fetched from Supabase on a fresh session).
  final String? photoPath;

  /// The pet's identity colour.
  final Color color;
  final double size;

  static const _ring = 3.0;

  @override
  Widget build(BuildContext context) {
    final extent = petRingAvatarExtent(context, size);
    final inner = extent - 2 * _ring;
    final figure = SpeciesFigure(species: species, breed: breed, size: inner);

    final photo = photoBytes;
    final path = photoPath;
    final Widget face;
    if (photo != null) {
      face = PetPhoto(key: ObjectKey(photo), bytes: photo, side: inner, fallback: figure);
    } else if (path != null) {
      face = StoredPetPhoto(key: ValueKey(path), path: path, side: inner, fallback: figure);
    } else {
      face = figure;
    }

    return ExcludeSemantics(
      child: Container(
        width: extent,
        height: extent,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: _ring),
        ),
        child: ClipOval(child: SizedBox.square(dimension: inner, child: face)),
      ),
    );
  }
}

/// A photo of the animal filling its box, decoded for a box [side] wide and not
/// at its own size (a picked photo can be 12 megapixels). Give it the bytes as key.
class PetPhoto extends StatelessWidget {
  const PetPhoto({super.key, required this.bytes, required this.side, required this.fallback});

  final Uint8List bytes;
  final double side;

  /// Shown when the bytes are not a picture.
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    // Twice the side: a photo up to twice as long as wide still fills the box sharp.
    final pixels = (side * 2 * MediaQuery.devicePixelRatioOf(context)).ceil();
    return Image(
      image: ResizeImage(
        MemoryImage(bytes),
        width: pixels,
        height: pixels,
        policy: ResizeImagePolicy.fit,
      ),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}

/// The thumbnail of a saved photo, [fallback] until it is there. Give it the
/// path as key: a list that changes must not show one animal with another's photo.
class StoredPetPhoto extends StatefulWidget {
  const StoredPetPhoto({
    required this.path,
    required this.side,
    required this.fallback,
    super.key,
  });

  final String path;
  final double side;
  final Widget fallback;

  @override
  State<StoredPetPhoto> createState() => _StoredPetPhotoState();
}

class _StoredPetPhotoState extends State<StoredPetPhoto> {
  late final Future<Uint8List?> _bytes = PetPhotoRepository().loadThumbnail(widget.path);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _bytes,
      // Already seen in this session: there at once, no flash of the figure.
      initialData: PetPhotoRepository.thumbnailInMemory(widget.path),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) return widget.fallback;
        return PetPhoto(bytes: bytes, side: widget.side, fallback: widget.fallback);
      },
    );
  }
}
