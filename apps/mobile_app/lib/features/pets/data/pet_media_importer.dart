import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../domain/pet_video_rules.dart';
import '../domain/video_metadata_scrubber.dart';
import 'pet_photo_repository.dart';

/// Reads how long a picked video lasts, or null when the player cannot tell.
typedef VideoDurationProbe = Future<Duration?> Function(XFile file);

/// Opens the file with the platform player just long enough to read its
/// length (the camera's own limit is not enforced for videos picked from the
/// gallery, so this is the only way to know).
Future<Duration?> probeVideoDuration(XFile file) async {
  // A blob URL on the web, a file path elsewhere - no dart:io needed.
  final uri = kIsWeb ? Uri.parse(file.path) : Uri.file(file.path);
  final controller = VideoPlayerController.networkUrl(uri);
  try {
    await controller.initialize().timeout(const Duration(seconds: 15));
    final duration = controller.value.duration;
    return duration == Duration.zero ? null : duration;
  } catch (_) {
    return null;
  } finally {
    await controller.dispose();
  }
}

class PetMediaImportResult {
  const PetMediaImportResult({
    this.photos = 0,
    this.videos = 0,
    this.problems = const [],
  });

  final int photos;
  final int videos;

  /// One readable line per file that was not added.
  final List<String> problems;

  int get added => photos + videos;
  bool get isEmpty => added == 0 && problems.isEmpty;

  /// "Caricati: 2 foto e 1 video" plus the first problem, ready for a SnackBar.
  String summary() {
    final parts = <String>[
      if (photos > 0) '$photos foto',
      if (videos > 0) '$videos video',
    ];
    final done = parts.isEmpty ? null : 'Caricati: ${parts.join(' e ')}';
    if (problems.isEmpty) return done ?? 'Niente da aggiungere.';
    final extra = problems.length > 1 ? ' (altri ${problems.length - 1} non aggiunti)' : '';
    return done == null ? '${problems.first}$extra' : '$done. ${problems.first}$extra';
  }
}

/// Takes what the pickers returned (any mix of photos and videos), checks it,
/// removes location data and uploads it one file at a time.
class PetMediaImporter {
  PetMediaImporter({PetPhotoRepository? repository, VideoDurationProbe? probe})
      : _repository = repository ?? PetPhotoRepository(),
        _probe = probe ?? probeVideoDuration;

  final PetPhotoRepository _repository;
  final VideoDurationProbe _probe;

  /// [onProgress] reports (file being handled, total) before each file, so the
  /// screen can say "Carico 2 di 5" from the first moment.
  Future<PetMediaImportResult> importAll({
    required String petId,
    required List<XFile> files,
    void Function(int current, int total)? onProgress,
  }) async {
    var photos = 0;
    var videos = 0;
    final problems = <String>[];

    for (var index = 0; index < files.length; index++) {
      onProgress?.call(index + 1, files.length);
      final file = files[index];
      try {
        final kind = classifyPickedMedia(fileName: file.name, mimeType: file.mimeType);
        final problem = kind == PetMediaKind.video
            ? await _importVideo(petId, file)
            : await _importPhoto(petId, file);
        if (problem != null) {
          problems.add(problem);
        } else if (kind == PetMediaKind.video) {
          videos++;
        } else {
          photos++;
        }
      } catch (_) {
        problems.add('Non sono riuscito a caricare ${_label(file)}.');
      }
    }
    return PetMediaImportResult(photos: photos, videos: videos, problems: problems);
  }

  static String _label(XFile file) => file.name.isEmpty ? 'un file' : '"${file.name}"';

  Future<String?> _importPhoto(String petId, XFile file) async {
    final raw = await file.readAsBytes();
    // Re-encoding drops the EXIF block (position, device) - see compressPetPhoto.
    final jpeg = await compute(compressPetPhoto, raw);
    final entry = await _repository.upload(petId: petId, compressedJpeg: jpeg, isProfile: false);
    return entry == null ? 'Il salvataggio delle foto non è disponibile senza connessione.' : null;
  }

  Future<String?> _importVideo(String petId, XFile file) async {
    final size = await file.length();
    final extension = fileExtension(file.name);

    // Cheap checks first; the player is only opened for a file that could pass.
    final early = checkPetVideo(fileName: file.name, sizeBytes: size, duration: Duration.zero);
    if (!early.isOk) return '${_label(file)}: ${early.message}';

    final duration = await _probe(file);
    final verdict = checkPetVideo(fileName: file.name, sizeBytes: size, duration: duration);
    if (!verdict.isOk) return '${_label(file)}: ${verdict.message}';

    final bytes = await file.readAsBytes();
    stripVideoLocationMetadata(bytes);
    final entry = await _repository.uploadVideo(
      petId: petId,
      bytes: bytes,
      extension: extension,
      durationSeconds: duration!.inSeconds,
    );
    return entry == null ? 'Il salvataggio dei video non è disponibile senza connessione.' : null;
  }
}
