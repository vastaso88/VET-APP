import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../domain/pet_video_rules.dart';
import '../domain/video_metadata_scrubber.dart';
import 'pet_photo_repository.dart';
import 'pet_video_compressor.dart';

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
    this.cancelled = false,
  });

  final int photos;
  final int videos;

  /// One readable line per file that was not added.
  final List<String> problems;

  /// The owner stopped the import; files already uploaded stay.
  final bool cancelled;

  int get added => photos + videos;
  bool get isEmpty => added == 0 && problems.isEmpty && !cancelled;

  /// "Caricati: 2 foto e 1 video" plus the first problem, ready for a SnackBar.
  String summary() {
    final parts = <String>[
      if (photos > 0) '$photos foto',
      if (videos > 0) '$videos video',
    ];
    final done = parts.isEmpty ? null : 'Caricati: ${parts.join(' e ')}';
    if (cancelled) return done == null ? 'Caricamento annullato.' : 'Caricamento annullato. $done.';
    if (problems.isEmpty) return done ?? 'Niente da aggiungere.';
    final extra = problems.length > 1 ? ' (altri ${problems.length - 1} non aggiunti)' : '';
    return done == null ? '${problems.first}$extra' : '$done. ${problems.first}$extra';
  }
}

/// Takes what the pickers returned (any mix of photos and videos), checks it,
/// removes location data and uploads it one file at a time. On the phone
/// videos are re-encoded to 720p first ([PetVideoCompressor]).
///
/// One instance per import: [cancel] stops this import for good.
class PetMediaImporter {
  PetMediaImporter({
    PetPhotoRepository? repository,
    VideoDurationProbe? probe,
    PetVideoCompressor? compressor,
  })  : _repository = repository ?? PetPhotoRepository(),
        _probe = probe ?? probeVideoDuration,
        _compressor = compressor ?? PetVideoCompressor();

  final PetPhotoRepository _repository;
  final VideoDurationProbe _probe;
  final PetVideoCompressor _compressor;

  bool _cancelled = false;

  /// Stops the video being re-encoded and skips the files not started yet.
  /// An upload already under way is let finish (it can't be half-done).
  Future<void> cancel() async {
    _cancelled = true;
    await _compressor.cancel();
  }

  /// [onProgress] reports (file being handled, total) before each file, so the
  /// screen can say "Carico 2 di 5" from the first moment. [onCompressProgress]
  /// reports 0..1 while a video is being reduced (phone only).
  Future<PetMediaImportResult> importAll({
    required String petId,
    required List<XFile> files,
    void Function(int current, int total)? onProgress,
    void Function(double fraction)? onCompressProgress,
  }) async {
    var photos = 0;
    var videos = 0;
    final problems = <String>[];

    for (var index = 0; index < files.length && !_cancelled; index++) {
      onProgress?.call(index + 1, files.length);
      final file = files[index];
      try {
        final kind = classifyPickedMedia(fileName: file.name, mimeType: file.mimeType);
        final outcome = kind == PetMediaKind.video
            ? await _importVideo(petId, file, onCompressProgress)
            : _uploaded(await _importPhoto(petId, file));
        if (outcome.problem case final problem?) {
          problems.add(problem);
        } else if (!outcome.uploaded) {
          // Stopped while this video was being reduced: nothing went up.
        } else if (kind == PetMediaKind.video) {
          videos++;
        } else {
          photos++;
        }
      } catch (_) {
        problems.add('Non sono riuscito a caricare ${_label(file)}.');
      } finally {
        await _compressor.discardPickedCopy(file);
      }
    }
    return PetMediaImportResult(
      photos: photos,
      videos: videos,
      problems: problems,
      cancelled: _cancelled,
    );
  }

  static String _label(XFile file) => file.name.isEmpty ? 'un file' : '"${file.name}"';

  Future<String?> _importPhoto(String petId, XFile file) async {
    final raw = await file.readAsBytes();
    // Re-encoding drops the EXIF block (position, device) - see compressPetPhoto.
    final jpeg = await compute(compressPetPhoto, raw);
    final entry = await _repository.upload(petId: petId, compressedJpeg: jpeg, isProfile: false);
    return entry == null ? 'Il salvataggio delle foto non è disponibile senza connessione.' : null;
  }

  static _Outcome _uploaded(String? problem) => (uploaded: problem == null, problem: problem);

  static _Outcome _refused(XFile file, PetVideoCheck check) =>
      (uploaded: false, problem: '${_label(file)}: ${check.message}');

  static const _Outcome _stopped = (uploaded: false, problem: null);

  Future<_Outcome> _importVideo(
    String petId,
    XFile file,
    void Function(double fraction)? onCompressProgress,
  ) async {
    final size = await file.length();
    final willCompress = _compressor.isAvailable;

    // Cheap checks first; the player is only opened for a file that could pass.
    final early = checkPetVideo(
      fileName: file.name,
      sizeBytes: size,
      duration: Duration.zero,
      willCompress: willCompress,
    );
    if (!early.isOk) return _refused(file, early);

    final duration = await _probe(file);
    final verdict = checkPetVideo(
      fileName: file.name,
      sizeBytes: size,
      duration: duration,
      willCompress: willCompress,
    );
    if (!verdict.isOk) return _refused(file, verdict);

    try {
      var upload = file;
      var extension = fileExtension(file.name);
      var uploadSize = size;
      if (willCompress) {
        final reduced = await _compressor.compress(file, onProgress: onCompressProgress);
        if (_cancelled) return _stopped;
        final reducedSize = reduced == null ? null : await reduced.length();
        // A clip already smaller than 720p can come out larger: keep the smaller.
        if (reduced != null && reducedSize! > 0 && reducedSize < size) {
          upload = reduced;
          extension = 'mp4';
          uploadSize = reducedSize;
        }
        final fits = checkPetVideoUploadSize(
          sizeBytes: uploadSize,
          wasCompressed: reduced != null,
        );
        if (!fits.isOk) return _refused(file, fits);
      }

      final bytes = await upload.readAsBytes();
      stripVideoLocationMetadata(bytes);
      final entry = await _repository.uploadVideo(
        petId: petId,
        bytes: bytes,
        extension: extension,
        durationSeconds: duration!.inSeconds,
      );
      return _uploaded(
        entry == null ? 'Il salvataggio dei video non è disponibile senza connessione.' : null,
      );
    } finally {
      // Re-encoded copies are only needed until the upload is over.
      if (willCompress) await _compressor.releaseTemporaryFiles();
    }
  }
}

typedef _Outcome = ({bool uploaded, String? problem});
