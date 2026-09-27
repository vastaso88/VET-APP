import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

/// CartoDB Positron: a light, minimal basemap - free, no API key, better
/// contrast for the route polyline than the raw OSM standard style (owner
/// feedback after trying the feature on a real walk, 2026-09-27). Shared by
/// every place that renders a walk's map (the live tracker and the history
/// thumbnails in pet_detail_page.dart) so switching style again means
/// changing one place.
TileLayer buildWalkTileLayer() {
  return TileLayer(
    urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
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
