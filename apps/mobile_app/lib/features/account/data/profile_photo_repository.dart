import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/auth/current_user.dart';
import '../../../shared/config/app_runtime_config_loader.dart';
import '../../../shared/files/image_metadata.dart';
import '../../pets/data/pet_photo_repository.dart';

/// The owner's profile photo, kept in the private `pet-photos` bucket under
/// `<user id>/account/avatar.jpg`. That bucket's storage policy already lets
/// each user read and write only their own `<user id>/` folder, so this needs
/// no new SQL; the account deletion removes the whole folder.
///
/// The path is saved in the account's metadata (`avatar_path`); the bytes are
/// cached in memory for the session.
class ProfilePhotoRepository {
  ProfilePhotoRepository({SupabaseClient? client}) : _client = client;

  static const bucket = PetPhotoRepository.bucket;
  static final Map<String, Uint8List> _cache = {};

  /// Forgets cached photos (sign-out, account deletion).
  static void clearLocalCache() => _cache.clear();

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

  /// A phone-sized, metadata-free JPEG of [picked].
  static Uint8List prepare(Uint8List picked) => stripImageMetadata(compressPetPhoto(picked));

  /// Uploads [jpeg] and returns its storage path, or null without a backend
  /// (demo/offline).
  Future<String?> upload(Uint8List jpeg) async {
    final client = _resolveClient();
    final ownerId = CurrentUser.get()?.id;
    if (client == null || ownerId == null) return null;

    final path = '$ownerId/account/avatar.jpg';
    await client.storage.from(bucket).uploadBinary(
          path,
          jpeg,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
    _cache[path] = jpeg;
    return path;
  }

  Future<Uint8List?> download(String path) async {
    final cached = _cache[path];
    if (cached != null) return cached;
    final client = _resolveClient();
    if (client == null) return null;
    try {
      final bytes = await client.storage.from(bucket).download(path);
      _cache[path] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Future<void> remove(String path) async {
    _cache.remove(path);
    final client = _resolveClient();
    if (client == null) return;
    try {
      await client.storage.from(bucket).remove([path]);
    } catch (_) {
      // An orphan is cleaned up by the account deletion; not worth failing for.
    }
  }
}
