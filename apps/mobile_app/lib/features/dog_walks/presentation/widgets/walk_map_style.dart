import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../../shared/config/app_runtime_config_loader.dart';

/// CartoDB Positron: a light, minimal basemap, better contrast for the
/// route polyline than the raw OSM standard style (owner feedback after
/// trying the feature on a real walk, 2026-09-27). Shared by every place
/// that renders a walk's map (the live tracker and the history thumbnails
/// in pet_detail_page.dart) so switching style again means changing one
/// place.
///
/// CARTO started watermarking these tiles "API KEY REQUIRED" for anonymous
/// requests (2026-09-23) - free tier is generous (5M req/month
/// non-commercial) but does need a registered key, appended as `?key=`
/// (see carto.com/basemaps/apikey). Falls back to the bare URL when no key
/// is configured, which CARTO still serves, just watermarked.
TileLayer buildWalkTileLayer() {
  final config = const AppRuntimeConfigLoader().load();
  final keySuffix = config.hasCartoApiKey ? '?key=${config.cartoApiKey}' : '';
  return TileLayer(
    urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png$keySuffix',
    subdomains: const ['a', 'b', 'c', 'd'],
    userAgentPackageName: 'com.vetapp.mobile_app',
  );
}

Widget buildWalkMapAttribution() {
  return const RichAttributionWidget(
    attributions: [
      TextSourceAttribution('OpenStreetMap contributors'),
      TextSourceAttribution('CARTO'),
    ],
  );
}
