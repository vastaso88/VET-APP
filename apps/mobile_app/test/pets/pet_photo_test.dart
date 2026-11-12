import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vet_app_mobile/features/pets/data/pet_photo_repository.dart';

Uint8List _png(int width, int height) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(200, 120, 40));
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  group('compressPetPhoto', () {
    test('downscales the longest side to 1600px and returns JPEG', () {
      final out = compressPetPhoto(_png(3200, 2000));

      expect(out.sublist(0, 2), [0xFF, 0xD8], reason: 'JPEG SOI marker');
      final decoded = img.decodeJpg(out)!;
      expect(decoded.width, petPhotoMaxSide);
      expect(decoded.height, 1000);
    });

    test('downscales a tall photo by its height', () {
      final out = compressPetPhoto(_png(1200, 4000));

      final decoded = img.decodeJpg(out)!;
      expect(decoded.height, petPhotoMaxSide);
      expect(decoded.width, 480);
    });

    test('never upscales an image already within the limit', () {
      final out = compressPetPhoto(_png(800, 600));

      final decoded = img.decodeJpg(out)!;
      expect(decoded.width, 800);
      expect(decoded.height, 600);
    });

    test('rejects bytes that are not an image', () {
      expect(
        () => compressPetPhoto(Uint8List.fromList([1, 2, 3, 4])),
        throwsFormatException,
      );
    });
  });

  test('storage path is owner/pet/photo.jpg so the bucket policy can key on the owner', () {
    expect(
      petPhotoStoragePath(ownerId: 'owner-1', petId: 'pet-9', photoId: 'photo-7'),
      'owner-1/pet-9/photo-7.jpg',
    );
  });
}
