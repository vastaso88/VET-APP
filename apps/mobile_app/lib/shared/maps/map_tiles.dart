import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';

/// The name the app gives to the map tile servers (docs/compliance/20 §22): always ours, with
/// the page where the operator can be found. A browser sends its own name, which a page cannot
/// change, so on the web nothing is set.
const kMapUserAgent = 'Quokka/1.0 (+https://quokkapet.net)';

/// Every map of the app takes its tiles from here, so that the name is always the same.
TileLayer quokkaTileLayer({
  required String urlTemplate,
  List<String> subdomains = const ['a', 'b', 'c'],
}) {
  return TileLayer(
    urlTemplate: urlTemplate,
    subdomains: subdomains,
    userAgentPackageName: 'net.quokkapet.app',
    tileProvider: NetworkTileProvider(
      headers: kIsWeb ? null : <String, String>{'User-Agent': kMapUserAgent},
    ),
  );
}
