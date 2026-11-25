import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/auth/current_user.dart';
import '../../../shared/config/app_runtime_config_loader.dart';
import '../../billing/data/plan_access_refusal.dart';
import '../domain/pet_video_rules.dart';
import 'pet_photo_disk_cache.dart';
import 'pet_photo_fetch_queue.dart';

/// Longest side and JPEG quality every pet photo is normalised to before
/// upload — keeps the private bucket small without visible loss on a phone.
const petPhotoMaxSide = 1600;
const petPhotoJpegQuality = 80;

/// The small copy every grid tile, avatar and folder cover shows instead of the
/// full photo (about 30 KB against 300-500 KB). 512 px keeps a three-column grid
/// and the half-screen folder covers sharp on a phone screen.
const petPhotoThumbSide = 512;
const petPhotoThumbQuality = 75;

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

/// What one pet's gallery folder counts.
class PetMediaCounts {
  const PetMediaCounts({this.photos = 0, this.videos = 0});

  final int photos;
  final int videos;
}

/// Reads one page of the light `pet_photos` rows (`pet_id` and, when
/// [withMediaType], `media_type`) of [petIds]: the source of
/// [PetPhotoRepository.countsForPets], replaceable in tests.
typedef PetMediaCountRows = Future<List<dynamic>> Function(
  List<String> petIds, {
  required bool withMediaType,
  required int from,
  required int to,
});

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

/// Shrinks an already normalised pet photo to the thumbnail size. Pure, so it
/// runs in an isolate via [compute] and is unit-testable without a device.
/// A picture that is already small is only re-encoded, never enlarged.
Uint8List compressPetPhotoThumbnail(Uint8List input) {
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
  final resized = longest <= petPhotoThumbSide
      ? decoded
      : img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? petPhotoThumbSide : null,
          height: decoded.height > decoded.width ? petPhotoThumbSide : null,
          interpolation: img.Interpolation.average,
        );
  resized.exif = img.ExifData();
  return Uint8List.fromList(img.encodeJpg(resized, quality: petPhotoThumbQuality));
}

/// Where the thumbnail of the photo at [storagePath] lives: beside it, with a
/// `_t.jpg` ending (`<owner>/<pet>/<id>.jpg` -> `<owner>/<pet>/<id>_t.jpg`).
/// It is a Storage object only: there is no `pet_photos` row for it, so counts,
/// limits and the account export never see it, and deleting the pet's folder
/// or the account removes it with everything else.
String petPhotoThumbPath(String storagePath) {
  final dot = storagePath.lastIndexOf('.');
  final slash = storagePath.lastIndexOf('/');
  final stem = dot > slash ? storagePath.substring(0, dot) : storagePath;
  return '${stem}_t.jpg';
}

/// The three Storage operations the photo cache needs, so the loading logic can
/// be tested without a Supabase client.
abstract class PetPhotoObjectStore {
  Future<Uint8List> download(String path);

  Future<void> upload(String path, Uint8List bytes, {required String contentType});

  Future<void> remove(List<String> paths);
}

class _SupabasePhotoObjects implements PetPhotoObjectStore {
  const _SupabasePhotoObjects(this._client);

  final SupabaseClient _client;

  @override
  Future<Uint8List> download(String path) =>
      _client.storage.from(PetPhotoRepository.bucket).download(path);

  @override
  Future<void> upload(String path, Uint8List bytes, {required String contentType}) async {
    await _client.storage.from(PetPhotoRepository.bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
  }

  @override
  Future<void> remove(List<String> paths) async {
    await _client.storage.from(PetPhotoRepository.bucket).remove(paths);
  }
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
  PetPhotoRepository({
    SupabaseClient? client,
    PetPhotoDiskCache? diskCache,
    PetPhotoObjectStore? objects,
    String? Function()? ownerIdResolver,
    PetMediaCountRows? mediaCountRows, // test seam: replaces the read of the counts
  })  : _client = client,
        _disk = diskCache ?? PetPhotoDiskCache.instance,
        _objects = objects,
        _ownerIdResolver = ownerIdResolver,
        _mediaCountRows = mediaCountRows;

  static const bucket = 'pet-photos';

  /// Full-size photos, only the few opened in the viewer (it was unbounded
  /// before the 2026-11-16 performance pass: every photo ever shown stayed).
  static final LruCache<Uint8List> _fullMemory = LruCache<Uint8List>(12);

  /// Thumbnails, what grids and avatars show: ~20 KB each.
  static final LruCache<Uint8List> _thumbMemory = LruCache<Uint8List>(800);

  /// At most 6 downloads at once, newest request first, one per photo.
  static final KeyedFetchQueue<Uint8List> _fullQueue = KeyedFetchQueue<Uint8List>(maxConcurrent: 4);
  static final KeyedFetchQueue<Uint8List> _thumbQueue = KeyedFetchQueue<Uint8List>(maxConcurrent: 6);

  /// Photos known to have no thumbnail object yet (photos uploaded before
  /// thumbnails existed): not asked for again this session.
  static final Set<String> _noRemoteThumb = {};

  /// Thumbnails already offered to Storage this session.
  static final Set<String> _thumbUploadTried = {};

  @visibleForTesting
  static void resetMemoryForTests() {
    _fullMemory.clear();
    _thumbMemory.clear();
    _noRemoteThumb.clear();
    _thumbUploadTried.clear();
  }

  /// Ticks when a photo is added or removed, so screens that show a pet's
  /// photos beside something else (the walk history's photo dots) can reload.
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  /// Forgets every photo held on this device (memory and disk) - the next
  /// account to sign in must not see the previous one's pets.
  static Future<void> clearLocalCaches() async {
    resetMemoryForTests();
    await PetPhotoDiskCache.instance.clear();
  }

  final SupabaseClient? _client;
  final PetPhotoDiskCache _disk;
  final PetPhotoObjectStore? _objects;
  final String? Function()? _ownerIdResolver;
  final PetMediaCountRows? _mediaCountRows;

  PetPhotoObjectStore? _objectStore() {
    final injected = _objects;
    if (injected != null) return injected;
    final client = _resolveClient();
    return client == null ? null : _SupabasePhotoObjects(client);
  }

  String? _currentOwnerId() => (_ownerIdResolver ?? () => CurrentUser.get()?.id)();

  /// Paths start with the owner id: only the signed-in account's own photos
  /// are ever served from disk, even if a sign-out was missed.
  bool _isOwnPath(String storagePath) {
    final ownerId = _currentOwnerId();
    return ownerId != null && storagePath.startsWith('$ownerId/');
  }

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
    _fullMemory.put(path, compressedJpeg);
    await _disk.write(path, compressedJpeg);
    // The small copy is made and stored behind the owner's back: the photo is
    // already saved, and a failure here only means the grid builds the
    // thumbnail itself later (see [loadThumbnail]).
    unawaited(_storeThumbnailFor(client, path, compressedJpeg));
    changes.value++;
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
    changes.value++;
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

  Future<void> _storeThumbnailFor(SupabaseClient client, String path, Uint8List jpeg) async {
    try {
      final thumb = await compute(compressPetPhotoThumbnail, jpeg);
      _thumbMemory.put(path, thumb);
      final thumbPath = petPhotoThumbPath(path);
      await _disk.write(thumbPath, thumb);
      _thumbUploadTried.add(path);
      await _SupabasePhotoObjects(client).upload(thumbPath, thumb, contentType: 'image/jpeg');
    } catch (_) {
      // Best effort: see [loadThumbnail].
    }
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
    try {
      await client.storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: false),
          );
    } catch (error) {
      // Trial over: the Storage policy answers a bare 403 (no code of its own),
      // told apart from other refusals by the account having no access.
      await _failIfPlanRefused(error, storagePetPhotos: true);
      rethrow;
    }
    try {
      await _insertRow(client, row);
    } catch (error) {
      try {
        await client.storage.from(bucket).remove([path]);
      } catch (_) {
        // Best effort: an orphan is recoverable, hiding the real error is not.
      }
      await _failIfPlanRefused(error);
      rethrow;
    }
  }

  /// A write the plan refused: sends the owner to the paywall (or shows the
  /// limit) and throws [PlanAccessRefusedException] so the importer can say why.
  /// Anything else returns, and the caller rethrows the original error.
  static Future<void> _failIfPlanRefused(Object error, {bool storagePetPhotos = false}) async {
    final refusal = await resolvePlanRefusal(error, storagePetPhotos: storagePetPhotos);
    if (refusal == null) return;
    applyPlanRefusal(refusal);
    throw PlanAccessRefusedException(refusal);
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

  /// How many photos and videos each of [petIds] has, for the folder captions
  /// of the gallery: ONE request for the whole group (two light columns per
  /// row, never the full rows [list] returns), instead of one full list per pet.
  /// A pet with no media is simply absent from the map (read it as 0 and 0).
  ///
  /// Only the requested pets are counted, and the table's row-level policy
  /// (`pet_photos_select_own`) already hides every other account's rows.
  /// Rows written before videos existed carry no `media_type` and are photos.
  /// Throws on a failed read, so the caller can tell "no media" from "unknown".
  Future<Map<String, PetMediaCounts>> countsForPets(Iterable<String> petIds) async {
    final ids = petIds.toSet().toList(growable: false);
    if (ids.isEmpty) return const {};
    final fetch = _mediaCountRows ?? _selectMediaCountRows;
    if (_mediaCountRows == null && _resolveClient() == null) return const {};
    try {
      return await _countMedia(ids, fetch, withMediaType: true);
    } on PostgrestException catch (error) {
      // The video column is not on a table the migration has not reached: count
      // every row as a photo, as the gallery did before videos. Any other error
      // is a real failure and stays one.
      if (error.code != '42703' && error.code != 'PGRST204') rethrow;
      return _countMedia(ids, fetch, withMediaType: false);
    }
  }

  Future<Map<String, PetMediaCounts>> _countMedia(
    List<String> ids,
    PetMediaCountRows fetch, {
    required bool withMediaType,
  }) async {
    final wanted = ids.toSet();
    final photos = <String, int>{};
    final videos = <String, int>{};
    // The server returns at most 1000 rows a request: a bigger gallery is read in
    // pages, so a count is never silently cut short.
    for (var from = 0;; from += _countPageSize) {
      final rows = await fetch(
        ids,
        withMediaType: withMediaType,
        from: from,
        to: from + _countPageSize - 1,
      );
      for (final row in rows) {
        final map = row as Map<String, dynamic>;
        final petId = map['pet_id'].toString();
        if (!wanted.contains(petId)) continue;
        final target = map['media_type'] == 'video' ? videos : photos;
        target[petId] = (target[petId] ?? 0) + 1;
      }
      if (rows.length < _countPageSize) break;
    }
    return {
      for (final petId in {...photos.keys, ...videos.keys})
        petId: PetMediaCounts(photos: photos[petId] ?? 0, videos: videos[petId] ?? 0),
    };
  }

  static const _countPageSize = 1000;

  Future<List<dynamic>> _selectMediaCountRows(
    List<String> petIds, {
    required bool withMediaType,
    required int from,
    required int to,
  }) async {
    final client = _resolveClient();
    if (client == null) return const [];
    final rows = await client
        .from('pet_photos')
        .select(withMediaType ? 'pet_id, media_type' : 'pet_id')
        .inFilter('pet_id', petIds)
        .order('id')
        .range(from, to);
    return rows as List<dynamic>;
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
    final thumbPath = petPhotoThumbPath(photo.storagePath);
    await client.storage.from(bucket).remove([photo.storagePath, thumbPath]);
    await client.from('pet_photos').delete().eq('id', photo.id);
    _fullMemory.remove(photo.storagePath);
    _thumbMemory.remove(photo.storagePath);
    await _disk.remove(photo.storagePath);
    await _disk.remove(thumbPath);
    changes.value++;
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
      // A listing answers at most `limit` entries: page through it, or a pet
      // with a big gallery (photos plus their thumbnails) would keep files.
      const page = 100;
      final names = <String>[];
      for (var offset = 0;; offset += page) {
        final files = await client.storage
            .from(bucket)
            .list(path: prefix, searchOptions: SearchOptions(limit: page, offset: offset));
        names.addAll([for (final file in files) '$prefix/${file.name}']);
        if (files.length < page) break;
      }
      if (names.isEmpty) return;
      await client.storage.from(bucket).remove(names);
      _fullMemory.removeWhere((key) => key.startsWith('$prefix/'));
      _thumbMemory.removeWhere((key) => key.startsWith('$prefix/'));
      await _disk.removeFolder(prefix);
    } catch (_) {
      // Orphaned objects are recoverable later; the pet deletion must still succeed.
    }
  }

  /// Bytes for [storagePath] from the session cache, else the disk cache,
  /// else downloaded once. Null when there's no backend or the download fails.
  /// Photos never change once uploaded (a new one gets a new path), so a
  /// cached copy is never stale.
  ///
  /// For the photo viewer only: a grid tile, an avatar or a cover wants
  /// [loadThumbnail], a twentieth of the size.
  Future<Uint8List?> loadBytes(String storagePath) async {
    final cached = _fullMemory.get(storagePath);
    if (cached != null) return cached;

    final store = _objectStore();
    if (store == null) return null;
    return _fullQueue.run(storagePath, () => _fetchFull(store, storagePath));
  }

  Future<Uint8List?> _fetchFull(PetPhotoObjectStore store, String storagePath) async {
    final own = _isOwnPath(storagePath);
    final onDisk = own ? await _disk.read(storagePath) : null;
    if (onDisk != null) {
      _fullMemory.put(storagePath, onDisk);
      return onDisk;
    }
    final Uint8List bytes;
    try {
      bytes = await store.download(storagePath);
    } catch (_) {
      return null;
    }
    _fullMemory.put(storagePath, bytes);
    if (own) await _disk.write(storagePath, bytes);
    return bytes;
  }

  /// The thumbnail of [storagePath] when this session already has it: no disk, no
  /// network, no wait.
  static Uint8List? thumbnailInMemory(String storagePath) => _thumbMemory.get(storagePath);

  /// The small picture of [storagePath] for grids, avatars and covers (about
  /// 20 KB against 300-500 KB for the photo itself).
  ///
  /// In order: this session's memory, the phone's disk, the thumbnail object
  /// Storage keeps beside the photo, and for photos that have none yet (every
  /// one uploaded before 2026-11-16) the photo itself, shrunk here, kept on the
  /// phone and offered back to Storage so the next device (or reinstall) gets
  /// the small file. Null when nothing can be loaded.
  Future<Uint8List?> loadThumbnail(String storagePath) async {
    final cached = _thumbMemory.get(storagePath);
    if (cached != null) return cached;

    final store = _objectStore();
    if (store == null) return null;
    final own = _isOwnPath(storagePath);
    final thumbPath = petPhotoThumbPath(storagePath);
    final onDisk = own ? await _disk.read(thumbPath) : null;
    if (onDisk != null) {
      _thumbMemory.put(storagePath, onDisk);
      return onDisk;
    }
    return _thumbQueue.run(storagePath, () => _buildThumbnail(store, storagePath, thumbPath, own));
  }

  Future<Uint8List?> _buildThumbnail(
    PetPhotoObjectStore store,
    String storagePath,
    String thumbPath,
    bool own,
  ) async {
    // The full photo may already be on the phone (viewed before, or cached by an
    // older build): shrinking it costs no network at all.
    var full = _fullMemory.get(storagePath);
    if (full == null && own) full = await _disk.read(storagePath);

    if (full == null) {
      if (!_noRemoteThumb.contains(storagePath)) {
        try {
          final bytes = await store.download(thumbPath);
          _thumbMemory.put(storagePath, bytes);
          if (own) await _disk.write(thumbPath, bytes);
          return bytes;
        } catch (_) {
          _noRemoteThumb.add(storagePath);
        }
      }
      try {
        full = await store.download(storagePath);
      } catch (_) {
        return null;
      }
    }

    final Uint8List thumb;
    try {
      thumb = await compute(compressPetPhotoThumbnail, full);
    } catch (_) {
      return null;
    }
    _thumbMemory.put(storagePath, thumb);
    if (own) {
      await _disk.write(thumbPath, thumb);
      if (_thumbUploadTried.add(storagePath)) {
        unawaited(_offerThumbnail(store, thumbPath, thumb));
      }
    }
    return thumb;
  }

  /// Best effort and silent: no paywall, no message. A refusal (trial over,
  /// offline, already there) just leaves the thumbnail on this phone only.
  Future<void> _offerThumbnail(PetPhotoObjectStore store, String thumbPath, Uint8List thumb) async {
    try {
      await store.upload(thumbPath, thumb, contentType: 'image/jpeg');
    } catch (_) {
      // See above.
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
