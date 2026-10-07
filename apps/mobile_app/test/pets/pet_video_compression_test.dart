import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vet_app_mobile/features/pets/data/pet_media_importer.dart';
import 'package:vet_app_mobile/features/pets/data/pet_photo_repository.dart';
import 'package:vet_app_mobile/features/pets/data/pet_video_compressor.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_video_rules.dart';

class _RecordingRepository extends PetPhotoRepository {
  final uploads = <({int size, String extension})>[];

  @override
  Future<PetPhotoEntry?> uploadVideo({
    required String petId,
    required Uint8List bytes,
    required String extension,
    required int durationSeconds,
    DateTime? takenAt,
  }) async {
    uploads.add((size: bytes.length, extension: extension));
    return PetPhotoEntry(
      id: '${uploads.length}',
      petId: petId,
      storagePath: 'o/$petId/${uploads.length}.$extension',
      createdAt: DateTime(2026, 10, 7),
      isProfile: false,
      kind: PetMediaKind.video,
      durationSeconds: durationSeconds,
    );
  }
}

class _FakeCompressor implements PetVideoCompressor {
  _FakeCompressor({this.outputSize, this.wait});

  /// Size of the "re-encoded" file; null simulates a failed re-encode.
  final int? outputSize;

  /// When set, compress() waits for it (to test cancelling mid-way).
  final Completer<void>? wait;

  var compressed = 0;
  var released = 0;
  final discarded = <String>[];
  var cancelled = false;

  @override
  bool get isAvailable => true;

  @override
  Future<XFile?> compress(XFile video, {void Function(double fraction)? onProgress}) async {
    compressed++;
    onProgress?.call(0.5);
    if (wait != null) await wait!.future;
    if (cancelled || outputSize == null) return null;
    onProgress?.call(1);
    return XFile.fromData(Uint8List(outputSize!), name: 'out.mp4', mimeType: 'video/mp4');
  }

  @override
  Future<void> cancel() async {
    cancelled = true;
    if (wait != null && !wait!.isCompleted) wait!.complete();
  }

  @override
  Future<void> releaseTemporaryFiles() async => released++;

  @override
  Future<void> discardPickedCopy(XFile file) async => discarded.add(file.path);
}

XFile _video(String name, int size) => XFile.fromData(
      Uint8List(size),
      name: name,
      path: '/cache/$name',
      mimeType: 'video/mp4',
      length: size,
    );

void main() {
  group('checkPetVideoUploadSize', () {
    test('accepts up to the stored limit', () {
      expect(
        checkPetVideoUploadSize(sizeBytes: petVideoMaxBytes, wasCompressed: true).isOk,
        isTrue,
      );
    });

    test('names what happened when the file is still too big', () {
      final reduced = checkPetVideoUploadSize(sizeBytes: petVideoMaxBytes + 1, wasCompressed: true);
      final failed = checkPetVideoUploadSize(sizeBytes: petVideoMaxBytes + 1, wasCompressed: false);

      expect(reduced.message, contains('Anche ridotto'));
      expect(failed.message, contains('Non sono riuscito a ridurre'));
    });
  });

  group('PetMediaImporter on the phone', () {
    Future<Duration?> thirtySeconds(XFile _) async => const Duration(seconds: 30);

    test('a heavy video is reduced and the reduced mp4 is uploaded', () async {
      final repository = _RecordingRepository();
      final compressor = _FakeCompressor(outputSize: 9 * 1000 * 1000);
      final progress = <double>[];
      final importer = PetMediaImporter(
        repository: repository,
        probe: thirtySeconds,
        compressor: compressor,
      );

      final result = await importer.importAll(
        petId: 'p',
        files: [_video('clip.mov', 70 * 1000 * 1000)],
        onCompressProgress: progress.add,
      );

      expect(result.videos, 1);
      expect(repository.uploads.single, (size: 9 * 1000 * 1000, extension: 'mp4'));
      expect(progress, [0.5, 1]);
      expect(compressor.released, 1, reason: 're-encoded files are deleted after the upload');
      expect(compressor.discarded, ['/cache/clip.mov'], reason: "the picker's copy is dropped too");
    });

    test('when re-encoding fails a small original still goes up as it is', () async {
      final repository = _RecordingRepository();
      final importer = PetMediaImporter(
        repository: repository,
        probe: thirtySeconds,
        compressor: _FakeCompressor(),
      );

      final result = await importer.importAll(petId: 'p', files: [_video('a.mov', 5000)]);

      expect(result.videos, 1);
      expect(repository.uploads.single, (size: 5000, extension: 'mov'));
    });

    test('when re-encoding fails a heavy original is refused, nothing uploaded', () async {
      final repository = _RecordingRepository();
      final compressor = _FakeCompressor();
      final importer = PetMediaImporter(
        repository: repository,
        probe: thirtySeconds,
        compressor: compressor,
      );

      final result = await importer.importAll(
        petId: 'p',
        files: [_video('a.mp4', petVideoMaxBytes + 1)],
      );

      expect(result.added, 0);
      expect(result.problems.single, contains('Non sono riuscito a ridurre'));
      expect(repository.uploads, isEmpty);
      expect(compressor.released, 1);
    });

    test('a reduced file larger than the original is not used', () async {
      final repository = _RecordingRepository();
      final importer = PetMediaImporter(
        repository: repository,
        probe: thirtySeconds,
        compressor: _FakeCompressor(outputSize: 8000),
      );

      await importer.importAll(petId: 'p', files: [_video('piccolo.mp4', 4000)]);

      expect(repository.uploads.single, (size: 4000, extension: 'mp4'));
    });

    test('cancelling stops the video being reduced and skips the rest', () async {
      final repository = _RecordingRepository();
      final compressor = _FakeCompressor(outputSize: 1000, wait: Completer<void>());
      final importer = PetMediaImporter(
        repository: repository,
        probe: thirtySeconds,
        compressor: compressor,
      );

      final running = importer.importAll(
        petId: 'p',
        files: [_video('a.mp4', 30 * 1000 * 1000), _video('b.mp4', 30 * 1000 * 1000)],
      );
      await Future<void>.delayed(Duration.zero);
      await importer.cancel();
      final result = await running;

      expect(result.cancelled, isTrue);
      expect(result.added, 0);
      expect(result.problems, isEmpty);
      expect(result.summary(), 'Caricamento annullato.');
      expect(repository.uploads, isEmpty);
      expect(compressor.compressed, 1, reason: 'the second video is never started');
      expect(compressor.released, 1);
    });
  });
}
