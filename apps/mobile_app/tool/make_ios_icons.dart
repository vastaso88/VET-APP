// Export the approved brand to Apple's required opaque icon sizes.
// Run from apps/mobile_app: dart run tool/make_ios_icons.dart
import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final source = img
      .decodePng(File('assets/brand/quokka_head_paper.png').readAsBytesSync());
  if (source == null) {
    throw StateError('Approved brand image cannot be decoded');
  }
  var left = source.width, top = source.height, right = -1, bottom = -1;
  for (final pixel in source) {
    if (pixel.a <= 16) continue;
    if (pixel.x < left) left = pixel.x;
    if (pixel.x > right) right = pixel.x;
    if (pixel.y < top) top = pixel.y;
    if (pixel.y > bottom) bottom = pixel.y;
  }
  if (right < 0) throw StateError('Approved brand image is empty');
  final head = img.copyCrop(source,
      x: left, y: top, width: right - left + 1, height: bottom - top + 1);
  const base = 'ios/Runner/Assets.xcassets';
  final contents = jsonDecode(
          File('$base/AppIcon.appiconset/Contents.json').readAsStringSync())
      as Map<String, dynamic>;
  for (final entry in contents['images'] as List<dynamic>) {
    final item = entry as Map<String, dynamic>;
    final points = double.parse((item['size'] as String).split('x').first);
    final scale = double.parse((item['scale'] as String).replaceAll('x', ''));
    final size = (points * scale).round();
    final icon = img.Image(width: size, height: size, numChannels: 3)
      ..clear(img.ColorRgb8(0x0E, 0x3B, 0x47));
    final target = (size * 0.62).round();
    final scaled = img.copyResize(head,
        width: target, interpolation: img.Interpolation.cubic);
    img.compositeImage(icon, scaled,
        dstX: (size - scaled.width) ~/ 2, dstY: (size - scaled.height) ~/ 2);
    File('$base/AppIcon.appiconset/${item['filename']}')
        .writeAsBytesSync(img.encodePng(icon));
  }
  // Transparent launch head, matching the launch storyboard's fixed point size.
  for (final scale in [1, 2, 3]) {
    final launch = img.copyResize(head,
        width: 120 * scale, interpolation: img.Interpolation.cubic);
    final suffix = scale == 1 ? '' : '@${scale}x';
    File('$base/LaunchImage.imageset/LaunchImage$suffix.png')
        .writeAsBytesSync(img.encodePng(launch));
  }
  stdout.writeln('Exported opaque App Store icons and launch images.');
}
