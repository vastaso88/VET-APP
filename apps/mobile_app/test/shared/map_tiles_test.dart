import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/shared/maps/map_tiles.dart';

void main() {
  test('the map tiles are asked for with our own name, not the library one', () {
    final layer = quokkaTileLayer(urlTemplate: 'https://tile.example.com/{z}/{x}/{y}.png');

    expect(layer.tileProvider.headers['User-Agent'], kMapUserAgent);
    expect(kMapUserAgent, startsWith('Quokka'));
  });
}
