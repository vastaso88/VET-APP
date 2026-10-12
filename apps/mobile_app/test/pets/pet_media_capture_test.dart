import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vet_app_mobile/features/pets/data/pet_media_capture.dart';
import 'package:vet_app_mobile/features/pets/data/pet_media_importer.dart';

/// Stands in for the system camera / gallery: answers with whatever the test
/// set, and records which door was knocked on.
class _FakePicker implements ImagePicker {
  XFile? photo;
  XFile? video;
  List<XFile> gallery = const [];
  final calls = <String>[];
  Duration? videoMaxDuration;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName;
    if (name == #pickImage) {
      calls.add('pickImage:${invocation.namedArguments[#source]}:'
          'quality=${invocation.namedArguments[#imageQuality]}');
      return Future<XFile?>.value(photo);
    }
    if (name == #pickVideo) {
      calls.add('pickVideo:${invocation.namedArguments[#source]}');
      videoMaxDuration = invocation.namedArguments[#maxDuration] as Duration?;
      return Future<XFile?>.value(video);
    }
    if (name == #pickMultipleMedia) {
      calls.add('pickMultipleMedia:quality=${invocation.namedArguments[#imageQuality]}');
      return Future<List<XFile>>.value(gallery);
    }
    return super.noSuchMethod(invocation);
  }
}

class _FakeImporter extends PetMediaImporter {
  _FakeImporter(this.onImport);

  final Future<PetMediaImportResult> Function(
    String petId,
    List<XFile> files,
    DateTime? capturedAt,
    void Function(int current, int total)? onProgress,
    void Function(double fraction)? onCompressProgress,
  ) onImport;
  bool cancelled = false;

  @override
  Future<void> cancel() async => cancelled = true;

  @override
  Future<PetMediaImportResult> importAll({
    required String petId,
    required List<XFile> files,
    void Function(int current, int total)? onProgress,
    void Function(double fraction)? onCompressProgress,
    DateTime? capturedAt,
  }) =>
      onImport(petId, files, capturedAt, onProgress, onCompressProgress);
}

XFile _file(String name) => XFile.fromData(Uint8List(4), name: name, path: '/cache/$name');

void main() {
  final shot = DateTime(2026, 10, 12, 9, 30);
  late _FakePicker picker;
  late List<String> events;
  late DateTime? importedCapturedAt;
  late String? importedPetId;

  PetMediaCapture build({
    Future<PetMediaImportResult> Function(
      void Function(int, int)? progress,
      void Function(double)? compress,
    )? during,
    _FakeImporter? importer,
  }) {
    return PetMediaCapture(
      picker: picker,
      now: () => shot,
      saveCopy: (file, {required isVideo}) async =>
          events.add('copy:${isVideo ? 'video' : 'photo'}:${file.name}'),
      importerFactory: () =>
          importer ??
          _FakeImporter((petId, files, capturedAt, onProgress, onCompress) async {
            events.add('import');
            importedPetId = petId;
            importedCapturedAt = capturedAt;
            if (during != null) return during(onProgress, onCompress);
            return PetMediaImportResult(
              photos: files.where((f) => f.name.endsWith('.jpg')).length,
              videos: files.where((f) => f.name.endsWith('.mp4')).length,
            );
          }),
    );
  }

  setUp(() {
    picker = _FakePicker();
    events = [];
    importedCapturedAt = null;
    importedPetId = null;
  });

  test('a photo from the system camera goes to the pet, stamped with the moment of the shot', () async {
    picker.photo = _file('shot.jpg');
    final capture = build();

    final result = await capture.takePhoto('thor');

    expect(result!.photos, 1);
    expect(importedPetId, 'thor');
    expect(importedCapturedAt, shot, reason: 'what makes the walk caption and map pin appear');
    expect(picker.calls.single, startsWith('pickImage:ImageSource.camera'));
  });

  test('the system picker is used as it is: no re-encoding quality that could drop the EXIF time', () async {
    picker
      ..photo = _file('shot.jpg')
      ..gallery = [_file('a.jpg')];
    final capture = build();

    await capture.takePhoto('thor');
    await capture.importFromGallery('thor');

    expect(picker.calls, ['pickImage:ImageSource.camera:quality=null', 'pickMultipleMedia:quality=null']);
  });

  test('the copy for the VetApp album is made before the upload starts', () async {
    picker.photo = _file('shot.jpg');

    await build().takePhoto('thor');

    expect(events, ['copy:photo:/cache/shot.jpg', 'import']);
  });

  test('a video is recorded for at most 30 seconds and its copy saved as a video', () async {
    picker.video = _file('clip.mp4');

    final result = await build().recordVideo('thor');

    expect(result!.videos, 1);
    expect(picker.videoMaxDuration, const Duration(seconds: 30));
    expect(events.first, 'copy:video:/cache/clip.mp4');
    expect(importedCapturedAt, shot);
  });

  test('backing out of the camera does nothing at all', () async {
    picker.photo = null;
    final capture = build();

    final result = await capture.takePhoto('thor');

    expect(result, isNull);
    expect(events, isEmpty, reason: 'no copy, no upload');
    expect(capture.busy, isFalse);
  });

  test('gallery files are not stamped with a shot time (their own EXIF is used)', () async {
    picker.gallery = [_file('a.jpg'), _file('b.mp4')];

    final result = await build().importFromGallery('thor');

    expect(result!.photos, 1);
    expect(result.videos, 1);
    expect(importedCapturedAt, isNull);
    expect(events, ['import'], reason: 'imported files are already on the phone: no album copy');
  });

  test('an empty gallery pick returns null', () async {
    picker.gallery = const [];

    expect(await build().importFromGallery('thor'), isNull);
  });

  test('the screen can show progress from the first moment and it is cleared afterwards', () async {
    picker.photo = _file('shot.jpg');
    final seen = <String?>[];
    final release = Completer<void>();
    final capture = build(during: (onProgress, onCompress) async {
      onProgress?.call(1, 1);
      await release.future;
      return const PetMediaImportResult(photos: 1);
    });
    capture.addListener(() => seen.add(capture.progress));

    final pending = capture.takePhoto('thor');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(capture.busy, isTrue);
    expect(seen.first, 'Preparo il file...', reason: 'immediate feedback before any work');
    expect(capture.progress, 'Carico il file...');

    release.complete();
    await pending;

    expect(capture.busy, isFalse);
    expect(capture.progress, isNull);
    expect(capture.compressFraction, isNull);
  });

  test('a video being reduced reports percentage, and Annulla reaches the importer', () async {
    picker.video = _file('clip.mp4');
    final release = Completer<void>();
    final importer = _FakeImporter((petId, files, capturedAt, onProgress, onCompress) async {
      onCompress?.call(0.4);
      await release.future;
      return const PetMediaImportResult(cancelled: true);
    });
    final capture = build(importer: importer);

    final pending = capture.recordVideo('thor');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(capture.progress, 'Riduco il video... 40%');
    expect(capture.compressFraction, 0.4);
    expect(capture.canCancel, isTrue);

    capture.cancel();
    expect(capture.cancelling, isTrue);
    expect(capture.progress, 'Annullo...');
    expect(importer.cancelled, isTrue);

    release.complete();
    final result = await pending;
    expect(result!.cancelled, isTrue);
    expect(capture.busy, isFalse);
  });

  test('a second shot while one is being sent is ignored', () async {
    picker.photo = _file('shot.jpg');
    final release = Completer<void>();
    var imports = 0;
    final capture = build(during: (_, __) async {
      imports++;
      await release.future;
      return const PetMediaImportResult(photos: 1);
    });

    final first = capture.takePhoto('thor');
    await Future<void>.delayed(Duration.zero);
    final second = await capture.takePhoto('thor');
    release.complete();
    await first;

    expect(second, isNull);
    expect(imports, 1);
  });

  test('disposing mid-upload is safe', () async {
    picker.photo = _file('shot.jpg');
    final release = Completer<void>();
    final capture = build(during: (onProgress, _) async {
      await release.future;
      onProgress?.call(1, 1);
      return const PetMediaImportResult(photos: 1);
    });

    final pending = capture.takePhoto('thor');
    await Future<void>.delayed(Duration.zero);
    capture.dispose();
    release.complete();

    expect((await pending)!.photos, 1);
  });

  group('confirmation', () {
    test('one photo: the confirmation names the pet gallery', () {
      expect(const PetMediaImportResult(photos: 1).confirmation('Thor'),
          'Foto aggiunta alla galleria di Thor');
    });

    test('one video', () {
      expect(const PetMediaImportResult(videos: 1).confirmation('Thor'),
          'Video aggiunto alla galleria di Thor');
    });

    test('several files, a problem or a cancel fall back to the summary', () {
      expect(const PetMediaImportResult(photos: 2).confirmation('Thor'), 'Caricati: 2 foto');
      expect(
        const PetMediaImportResult(problems: ['Video troppo lungo.']).confirmation('Thor'),
        'Video troppo lungo.',
      );
      expect(const PetMediaImportResult(cancelled: true).confirmation('Thor'),
          'Caricamento annullato.');
    });
  });
}
