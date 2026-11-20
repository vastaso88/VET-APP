// Draws the web icons from the same resources as the Android launcher icon:
// the approved Quokka head in "Carta" on the "Petrolio" ground
// (android/app/src/main/res/values/brand_colors.xml: ic_launcher_background).
//
// Run from apps/mobile_app:  dart run tool/make_web_icons.dart
//
// Writes web/favicon.png and web/icons/Icon-{192,512}.png (the head fills the
// square, like the launcher icon) and Icon-maskable-{192,512}.png (the head
// kept inside the 80% safe zone that a maskable icon allows).
import 'dart:io';

import 'package:image/image.dart' as img;

const _ground = (r: 0x0E, g: 0x3B, b: 0x47); // Petrolio, #0E3B47

void main() {
  final source = img.decodePng(File('assets/brand/quokka_head_paper.png').readAsBytesSync());
  if (source == null) throw StateError('assets/brand/quokka_head_paper.png cannot be read');
  final head = _trimmed(source);

  _write('web/favicon.png', 32, head, fill: 0.84);
  _write('web/icons/Icon-192.png', 192, head, fill: 0.62);
  _write('web/icons/Icon-512.png', 512, head, fill: 0.62);
  _write('web/icons/Icon-maskable-192.png', 192, head, fill: 0.5);
  _write('web/icons/Icon-maskable-512.png', 512, head, fill: 0.5);
}

/// The head without the transparent margin around it.
img.Image _trimmed(img.Image source) {
  var left = source.width, top = source.height, right = -1, bottom = -1;
  for (final pixel in source) {
    if (pixel.a > 16) {
      if (pixel.x < left) left = pixel.x;
      if (pixel.x > right) right = pixel.x;
      if (pixel.y < top) top = pixel.y;
      if (pixel.y > bottom) bottom = pixel.y;
    }
  }
  if (right < 0) throw StateError('the head image is empty');
  return img.copyCrop(source, x: left, y: top, width: right - left + 1, height: bottom - top + 1);
}

void _write(String path, int size, img.Image head, {required double fill}) {
  final canvas = img.Image(width: size, height: size, numChannels: 4)
    ..clear(img.ColorRgba8(_ground.r, _ground.g, _ground.b, 255));
  final target = (size * fill).round();
  final scaled = head.width >= head.height
      ? img.copyResize(head, width: target, interpolation: img.Interpolation.cubic)
      : img.copyResize(head, height: target, interpolation: img.Interpolation.cubic);
  img.compositeImage(
    canvas,
    scaled,
    dstX: (size - scaled.width) ~/ 2,
    dstY: (size - scaled.height) ~/ 2,
  );
  File(path).writeAsBytesSync(img.encodePng(canvas));
  stdout.writeln('$path  ${size}x$size');
}
