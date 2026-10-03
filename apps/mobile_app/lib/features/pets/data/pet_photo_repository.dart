import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/auth/current_user.dart';
import '../../../shared/config/app_runtime_config_loader.dart';

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
  });

  final String id;
  final String petId;
  final String storagePath;
  final DateTime createdAt;
  final bool isProfile;
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
  final longest = max(decoded.width, decoded.height);
  final resized = longest <= petPhotoMaxSide
      ? decoded
      : img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? petPhotoMaxSide : null,
          height: decoded.height > decoded.width ? petPhotoMaxSide : null,
        );
  return Uint8List.fromList(img.encodeJpg(resized, quality: petPhotoJpegQuality));
}

/// `<owner>/<pet>/<photo>.jpg` — the first segment is the owner id, which the
/// bucket's storage policy checks against `auth.uid()`.
String petPhotoStoragePath({
  required String ownerId,
  required String petId,
  required String photoId,
}) =>
    '$ownerId/$petId/$photoId.jpg';

/// Photos for pets, kept in the private `pet-photos` Storage bucket and the
/// `pet_photos` table. Downloaded bytes are cached in memory for the session;
/// there is no cross-restart disk cache (the app is web-first, and dart:io
/// isn't available there).
class PetPhotoRepository {
  PetPhotoRepository({SupabaseClient? client}) : _client = client;

  static const bucket = 'pet-photos';
  static final Map<String, Uint8List> _memoryCache = {};

  final SupabaseClient? _client;

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
  }) async {
    final client = _resolveClient();
    final ownerId = CurrentUser.get()?.id;
    if (client == null || ownerId == null) return null;

    final photoId =
        '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32).toRadixString(16)}';
    final path = petPhotoStoragePath(ownerId: ownerId, petId: petId, photoId: photoId);
    await client.storage.from(bucket).uploadBinary(
          path,
          compressedJpeg,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false),
        );
    final createdAt = DateTime.now().toUtc();
    await client.from('pet_photos').insert({
      'id': photoId,
      'owner_id': ownerId,
      'pet_id': petId,
      'storage_path': path,
      'created_at': createdAt.toIso8601String(),
      'is_profile': isProfile,
    });
    _memoryCache[path] = compressedJpeg;
    return PetPhotoEntry(
      id: photoId,
      petId: petId,
      storagePath: path,
      createdAt: createdAt,
      isProfile: isProfile,
    );
  }

  Future<List<PetPhotoEntry>> list(String petId) async {
    final client = _resolveClient();
    if (client == null) return const [];
    final rows = await client
        .from('pet_photos')
        .select('id,pet_id,storage_path,created_at,is_profile')
        .eq('pet_id', petId)
        .order('created_at', ascending: false);
    return (rows as List<dynamic>).map((row) {
      final map = row as Map<String, dynamic>;
      return PetPhotoEntry(
        id: map['id'].toString(),
        petId: map['pet_id'].toString(),
        storagePath: map['storage_path'].toString(),
        createdAt: DateTime.parse(map['created_at'].toString()),
        isProfile: map['is_profile'] == true,
      );
    }).toList(growable: false);
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
    } catch (_) {
      // Orphaned objects are recoverable later; the pet deletion must still succeed.
    }
  }

  /// Bytes for [storagePath] from the session cache, else downloaded once.
  /// Null when there's no backend or the download fails.
  Future<Uint8List?> loadBytes(String storagePath) async {
    final cached = _memoryCache[storagePath];
    if (cached != null) return cached;

    final client = _resolveClient();
    if (client == null) return null;
    try {
      final bytes = await client.storage.from(bucket).download(storagePath);
      _memoryCache[storagePath] = bytes;
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
    final jpeg = await compute(compressPetPhoto, raw);
    final entry = await PetPhotoRepository().upload(
      petId: petId,
      compressedJpeg: jpeg,
      isProfile: true,
    );
    return entry?.storagePath;
  } catch (_) {
    return null;
  }
}
