import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/auth/current_user.dart';
import '../../../shared/config/app_runtime_config_loader.dart';
import '../domain/pet_video_rules.dart';
import 'pet_photo_disk_cache.dart';

/// Longest side and JPEG quality every pet photo is normalised to before
/// upload — keeps the private bucket small without visible loss on a phone.
const petPhotoMaxSide = 1600;
const petPhotoJpegQuality = 80;

class PetPhotoEntry {
  const PetPhotoEntry({
    required this.id,
    required this.petId,
    required this.storagePath,
    required this.createdAt,
    required this.isProfile,
    this.kind = PetMediaKind.photo,
    this.durationSeconds,
    this.takenAt,
  });

  final String id;
  final String petId;
  final String storagePath;
  final DateTime createdAt;
  final bool isProfile;

  /// A gallery entry is a photo or, since 2026-10-06, a short video.
  final PetMediaKind kind;

  /// Videos only.
  final int? durationSeconds;

  /// When the shot was actually taken: the moment the in-app camera returned
  /// it, or the original EXIF date of an imported photo. Null when unknown
  /// (imported videos, photos without EXIF, rows saved before 2026-10-07) -
  /// [createdAt] is only the upload time, so it is never used in its place.
  final DateTime? takenAt;

  bool get isVideo => kind == PetMediaKind.video;
}

/// One `pet_photos` row as an entry; rows without `media_type` (every row
/// written before videos existed) are photos.
PetPhotoEntry petPhotoEntryFromRow(Map<String, dynamic> map) {
  final isVideo = map['media_type'] == 'video';
  return PetPhotoEntry(
    id: map['id'].toString(),
    petId: map['pet_id'].toString(),
    storagePath: map['storage_path'].toString(),
    createdAt: DateTime.parse(map['created_at'].toString()),
    isProfile: map['is_profile'] == true,
    kind: isVideo ? PetMediaKind.video : PetMediaKind.photo,
    durationSeconds: isVideo ? (map['duration_seconds'] as num?)?.toInt() : null,
    takenAt: DateTime.tryParse(map['taken_at']?.toString() ?? ''),
  );
}

/// The original shooting time recorded by the camera in [raw]'s EXIF
/// (DateTimeOriginal, else DateTime), read before compressPetPhoto strips
/// the block. EXIF stores local wall time without a zone, so it is read as
/// the phone's local time. Null when absent or unreadable.
DateTime? photoTakenAtFromExif(Uint8List raw) {
  try {
    final exif = img.decodeJpgExif(raw);
    if (exif == null) return null;
    final value = exif.exifIfd['DateTimeOriginal'] ?? exif.imageIfd['DateTime'];
    final match = RegExp(r'^(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})')
        .firstMatch(value?.toString().trim() ?? '');
    if (match == null) return null;
    final parts = [for (var i = 1; i <= 6; i++) int.parse(match.group(i)!)];
    if (parts[0] < 1990 || parts[1] < 1 || parts[1] > 12 || parts[2] < 1) return null;
    return DateTime(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5]);
  } catch (_) {
    return null;
  }
}

/// Resizes and re-encodes a picked image as JPEG. Pure, so it runs in an
/// isolate via [compute] and is unit-testable without a device.
Uint8List compressPetPhoto(Uint8List input) {
  final img.Image? decoded;
  try {
    decoded = img.decodeImage(input);
  } catch (_) {
    throw const FormatException('Immagine non valida');
  }
  if (decoded == null) {
    throw const FormatException('Immagine non valida');
  }
  // Orientation is baked into the pixels first: once the EXIF block is gone
  // below, a portrait shot would otherwise come out lying on its side.
  final upright = img.bakeOrientation(decoded);
  final longest = max(upright.width, upright.height);
  final resized = longest <= petPhotoMaxSide
      ? upright
      : img.copyResize(
          upright,
          width: upright.width >= upright.height ? petPhotoMaxSide : null,
          height: upright.height > upright.width ? petPhotoMaxSide : null,
        );
  // The encoder writes whatever EXIF the image carries - GPS position, device,
  // time. None of it may reach the server (owner request, 2026-10-06).
  resized.exif = img.ExifData();
  return Uint8List.fromList(img.encodeJpg(resized, quality: petPhotoJpegQuality));
}

/// `<owner>/<pet>/<photo>.jpg` — the first segment is the owner id, which the
/// bucket's storage policy checks against `auth.uid()`. Videos use their own
/// extension (mp4/mov) in the same folder.
String petPhotoStoragePath({
  required String ownerId,
  required String petId,
  required String photoId,
  String extension = 'jpg',
}) =>
    '$ownerId/$petId/$photoId.$extension';

/// Photos for pets, kept in the private `pet-photos` Storage bucket and the
/// `pet_photos` table. Downloaded bytes are cached in memory for the session
/// and, on the phone, on disk across launches ([PetPhotoDiskCache]) - both
/// wiped by [clearLocalCaches] on sign-out.
class PetPhotoRepository {
  PetPhotoRepository({SupabaseClient? client, PetPhotoDiskCache? diskCache})
      : _client = client,
        _disk = diskCache ?? PetPhotoDiskCache.instance;

  static const bucket = 'pet-photos';
  static final Map<String, Uint8List> _memoryCache = {};

  /// Forgets every photo held on this device (memory and disk) - the next
  /// account to sign in must not see the previous one's pets.
  static Future<void> clearLocalCaches() async {
    _memoryCache.clear();
    await PetPhotoDiskCache.instance.clear();
  }

  final SupabaseClient? _client;
  final PetPhotoDiskCache _disk;

  SupabaseClient? _resolveClient() {
    if (_client != null) return _client;
    if (!const AppRuntimeConfigLoader().load().hasSupabaseCredentials) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Uploads [compressedJpeg] for [petId] and records it in `pet_photos`.
  /// Returns null without a backend (demo/offline), so callers keep the bytes
  /// in memory only.
  Future<PetPhotoEntry?> upload({
    required String petId,
    required Uint8List compressedJpeg,
    required bool isProfile,
    DateTime? takenAt,
  }) async {
    final client = _resolveClient();
    final ownerId = CurrentUser.get()?.id;
    if (client == null || ownerId == null) return null;

    final photoId = _newMediaId();
    final path = petPhotoStoragePath(ownerId: ownerId, petId: petId, photoId: photoId);
    final createdAt = DateTime.now().toUtc();
    await _store(
      client,
      path: path,
      bytes: compressedJpeg,
      contentType: 'image/jpeg',
      row: {
        'id': photoId,
        'owner_id': ownerId,
        'pet_id': petId,
        'storage_path': path,
        'created_at': createdAt.toIso8601String(),
        'is_profile': isProfile,
        if (takenAt != null) 'taken_at': takenAt.toUtc().toIso8601String(),
      },
    );
    _memoryCache[path] = compressedJpeg;
    await _disk.write(path, compressedJpeg);
    return PetPhotoEntry(
      id: photoId,
      petId: petId,
      storagePath: path,
      createdAt: createdAt,
      isProfile: isProfile,
      takenAt: takenAt,
    );
  }

  /// Uploads an already checked and scrubbed video (see [checkPetVideo] and
  /// [stripVideoLocationMetadata]). Null without a backend. Not kept in the
  /// session cache: a video is streamed from a signed URL, never held in
  /// memory for the grid.
  Future<PetPhotoEntry?> uploadVideo({
    required String petId,
    required Uint8List bytes,
    required String extension,
    required int durationSeconds,
    DateTime? takenAt,
  }) async {
    final client = _resolveClient();
    final ownerId = CurrentUser.get()?.id;
    if (client == null || ownerId == null) return null;

    final photoId = _newMediaId();
    final path = petPhotoStoragePath(
      ownerId: ownerId,
      petId: petId,
      photoId: photoId,
      extension: extension,
    );
    final createdAt = DateTime.now().toUtc();
    await _store(
      client,
      path: path,
      bytes: bytes,
      contentType: petVideoContentType(extension),
      row: {
        'id': photoId,
        'owner_id': ownerId,
        'pet_id': petId,
        'storage_path': path,
        'created_at': createdAt.toIso8601String(),
        'is_profile': false,
        'media_type': 'video',
        'duration_seconds': durationSeconds,
        'size_bytes': bytes.length,
        if (takenAt != null) 'taken_at': takenAt.toUtc().toIso8601String(),
      },
    );
    return PetPhotoEntry(
      id: photoId,
      petId: petId,
      storagePath: path,
      createdAt: createdAt,
      isProfile: false,
      kind: PetMediaKind.video,
      durationSeconds: durationSeconds,
      takenAt: takenAt,
    );
  }

  static String _newMediaId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32).toRadixString(16)}';

  /// Object first, row second - and if the row is refused (for instance the
  /// video columns have not been added to the live table yet) the object is
  /// removed again rather than left orphaned in the bucket.
  Future<void> _store(
    SupabaseClient client, {
    required String path,
    required Uint8List bytes,
    required String contentType,
    required Map<String, Object?> row,
  }) async {
    await client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
    try {
      await _insertRow(client, row);
    } catch (_) {
      try {
        await client.storage.from(bucket).remove([path]);
      } catch (_) {
        // Best effort: an orphan is recoverable, hiding the real error is not.
      }
      rethrow;
    }
  }

  /// `taken_at` arrived 2026-10-07 (scripts/setup/supabase_schema.sql): until
  /// the live table has it, the row is saved without it rather than losing
  /// the upload - the photo then just carries no walk caption.
  static Future<void> _insertRow(SupabaseClient client, Map<String, Object?> row) async {
    try {
      await client.from('pet_photos').insert(row);
    } catch (_) {
      if (!row.containsKey('taken_at')) rethrow;
      await client.from('pet_photos').insert({...row}..remove('taken_at'));
    }
  }

  /// Short-lived link the video player streams from (the bucket is private).
  /// Null without a backend or when the link cannot be created.
  Future<String?> signedVideoUrl(String storagePath) async {
    final client = _resolveClient();
    if (client == null) return null;
    try {
      return await client.storage.from(bucket).createSignedUrl(storagePath, 3600);
    } catch (_) {
      return null;
    }
  }

  Future<List<PetPhotoEntry>> list(String petId) async {
    final client = _resolveClient();
    if (client == null) return const [];
    // select() without a column list: the video columns may not exist yet on a
    // table the migration has not reached, and naming them would break the
    // whole gallery.
    final rows = await client
        .from('pet_photos')
        .select()
        .eq('pet_id', petId)
        .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((row) => petPhotoEntryFromRow(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Makes [photo] the profile picture: flips `is_profile` on the pet's
  /// gallery rows and points `pet_profiles.photo_path` at it.
  Future<void> setProfile(PetPhotoEntry photo) async {
    final client = _resolveClient();
    if (client == null) return;
    await client.from('pet_photos').update({'is_profile': false}).eq('pet_id', photo.petId);
    await client.from('pet_photos').update({'is_profile': true}).eq('id', photo.id);
    await client
        .from('pet_profiles')
        .update({'photo_path': photo.storagePath})
        .eq('id', photo.petId);
  }

  Future<void> delete(PetPhotoEntry photo) async {
    final client = _resolveClient();
    if (client == null) return;
    await client.storage.from(bucket).remove([photo.storagePath]);
    await client.from('pet_photos').delete().eq('id', photo.id);
    _memoryCache.remove(photo.storagePath);
    await _disk.remove(photo.storagePath);
  }

  /// Removes every file under `<owner>/<pet>/` — called when the pet itself is
  /// deleted, because the `pet_photos` rows go by cascade but Storage objects
  /// don't. Best-effort: a failure leaves orphaned files, never blocks deletion.
  Future<void> deleteAllForPet(String petId) async {
    try {
      final client = _resolveClient();
      final ownerId = CurrentUser.get()?.id;
      if (client == null || ownerId == null) return;

      final prefix = '$ownerId/$petId';
      final files = await client.storage.from(bucket).list(path: prefix);
      if (files.isEmpty) return;
      await client.storage.from(bucket).remove([for (final file in files) '$prefix/${file.name}']);
      _memoryCache.removeWhere((key, _) => key.startsWith('$prefix/'));
      await _disk.removeFolder(prefix);
    } catch (_) {
      // Orphaned objects are recoverable later; the pet deletion must still succeed.
    }
  }

  /// Bytes for [storagePath] from the session cache, else the disk cache,
  /// else downloaded once. Null when there's no backend or the download fails.
  /// Photos never change once uploaded (a new one gets a new path), so a
  /// cached copy is never stale.
  Future<Uint8List?> loadBytes(String storagePath) async {
    final cached = _memoryCache[storagePath];
    if (cached != null) return cached;

    final client = _resolveClient();
    if (client == null) return null;
    // Paths start with the owner id: only the signed-in account's own photos
    // are ever served from disk, even if a sign-out was missed.
    final ownerId = CurrentUser.get()?.id;
    final ownPhoto = ownerId != null && storagePath.startsWith('$ownerId/');
    final onDisk = ownPhoto ? await _disk.read(storagePath) : null;
    if (onDisk != null) {
      _memoryCache[storagePath] = onDisk;
      return onDisk;
    }
    try {
      final bytes = await client.storage.from(bucket).download(storagePath);
      _memoryCache[storagePath] = bytes;
      if (ownPhoto) await _disk.write(storagePath, bytes);
      return bytes;
    } catch (_) {
      return null;
    }
  }
}

/// Compresses [raw] and stores it as [petId]'s profile photo. Returns the
/// storage path, or null when there's no backend or the upload fails — the
/// pet still saves, and the photo stays in memory for this session.
Future<String?> saveProfilePhoto({required String petId, required Uint8List raw}) async {
  try {
    final takenAt = photoTakenAtFromExif(raw);
    final jpeg = await compute(compressPetPhoto, raw);
    final entry = await PetPhotoRepository().upload(
      petId: petId,
      compressedJpeg: jpeg,
      isProfile: true,
      takenAt: takenAt,
    );
    return entry?.storagePath;
  } catch (_) {
    return null;
  }
}
