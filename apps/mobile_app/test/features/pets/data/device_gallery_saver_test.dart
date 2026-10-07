import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:vet_app_mobile/features/pets/data/device_gallery_saver.dart';

void main() {
  final file = XFile('/cache/scatto.jpg');

  test('salva una foto scattata quando l\'interruttore è acceso', () async {
    final saved = <String>[];
    final saver = DeviceGallerySaver(
      isEnabled: () => true,
      ensureAccess: () async => true,
      putImage: (path) async => saved.add('img:$path'),
      putVideo: (path) async => saved.add('vid:$path'),
    );

    expect(await saver.save(file, isVideo: false), isTrue);
    expect(await saver.save(file, isVideo: true), isTrue);
    expect(saved, ['img:/cache/scatto.jpg', 'vid:/cache/scatto.jpg']);
  });

  test('non salva nulla con l\'interruttore spento', () async {
    var calls = 0;
    final saver = DeviceGallerySaver(
      isEnabled: () => false,
      putImage: (_) async => calls++,
      putVideo: (_) async => calls++,
    );

    expect(await saver.save(file, isVideo: false), isFalse);
    expect(calls, 0);
  });

  test('un errore del salvataggio locale non si propaga', () async {
    final saver = DeviceGallerySaver(
      isEnabled: () => true,
      ensureAccess: () async => true,
      putImage: (_) async => throw Exception('permesso negato'),
    );

    expect(await saver.save(file, isVideo: false), isFalse);
  });

  test('se il permesso è negato salta il salvataggio senza errori', () async {
    var calls = 0;
    final saver = DeviceGallerySaver(
      isEnabled: () => true,
      ensureAccess: () async => false,
      putImage: (_) async => calls++,
      putVideo: (_) async => calls++,
    );

    expect(await saver.save(file, isVideo: false), isFalse);
    expect(await saver.save(file, isVideo: true), isFalse);
    expect(calls, 0);
  });
}
