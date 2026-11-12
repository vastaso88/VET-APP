import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/config/app_runtime_config_loader.dart';
import '../../../shared/files/image_metadata.dart';
import '../../pets/data/pet_photo_repository.dart';

/// Most photos one listing can carry.
const maxListingPhotos = 6;

/// Same pipeline as pet photos (pets/data/pet_photo_repository.dart):
/// upright, resized to 1600 px, re-encoded as JPEG with the EXIF block
/// (GPS position, device, time) cleared. The byte-level strip on top is a
/// second net for anything the encoder might still carry. Pure, so it runs
/// in an isolate via [compute].
Uint8List prepareListingPhoto(Uint8List picked) => stripImageMetadata(compressPetPhoto(picked));

/// Listing photos live in the PUBLIC `marketplace-photos` bucket (listings
/// are readable by everyone, so are their photos) under
/// `<owner>/<listing>/<photo>.jpg`; the bucket's storage policies only let
/// the owner write or delete inside their own folder
/// (scripts/setup/marketplace_v2.sql). Without a backend the bytes stay in
/// memory for the session under a `memory://` url, which [ListingPhoto]
/// resolves.
class ListingPhotoStore {
  ListingPhotoStore({SupabaseClient? client, bool localOnly = false})
      : _client = client,
        _localOnly = localOnly;

  static const bucket = 'marketplace-photos';
  static const _memoryScheme = 'memory://';
  static final Map<String, Uint8List> _memory = {};

  final SupabaseClient? _client;
  final bool _localOnly;

  /// Bytes of a photo kept in memory (demo mode), null for a real url.
  static Uint8List? memoryBytes(String url) => _memory[url];

  /// [preparedJpeg] must already have gone through [prepareListingPhoto].
  Future<String> upload({
    required String ownerId,
    required String listingId,
    required Uint8List preparedJpeg,
  }) async {
    final photoId =
        '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32).toRadixString(16)}';
    final client = _resolveClient();
    if (client == null) {
      final url = '$_memoryScheme$listingId/$photoId';
      _memory[url] = preparedJpeg;
      return url;
    }

    final path = '$ownerId/$listingId/$photoId.jpg';
    await client.storage.from(bucket).uploadBinary(
          path,
          preparedJpeg,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false),
        );
    return client.storage.from(bucket).getPublicUrl(path);
  }

  /// Best effort: a leftover object is recoverable, a failed delete of the
  /// listing itself because of it would not be.
  Future<void> remove(List<String> urls) async {
    if (urls.isEmpty) return;
    urls.where((url) => url.startsWith(_memoryScheme)).forEach(_memory.remove);

    final paths = urls.map(storagePathFromPublicUrl).whereType<String>().toList();
    final client = _resolveClient();
    if (client == null || paths.isEmpty) return;
    try {
      await client.storage.from(bucket).remove(paths);
    } catch (_) {}
  }

  SupabaseClient? _resolveClient() {
    if (_localOnly) return null;
    if (_client != null) return _client;
    if (!const AppRuntimeConfigLoader().load().hasSupabaseCredentials) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }
}

/// `.../storage/v1/object/public/marketplace-photos/<path>` -> `<path>`.
String? storagePathFromPublicUrl(String url) {
  const marker = '/object/public/${ListingPhotoStore.bucket}/';
  final index = url.indexOf(marker);
  if (index == -1) return null;
  final path = url.substring(index + marker.length).split('?').first;
  return path.isEmpty ? null : Uri.decodeComponent(path);
}
