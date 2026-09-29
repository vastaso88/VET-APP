import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../../shared/config/app_runtime_config_loader.dart';

/// Which basemap to render for a walk's map (the live tracker in
/// active_walk_page.dart and the history thumbnails in pet_detail_page.dart
/// both read from this one file, so switching style means changing one
/// place). OSM standard is the default - the owner tried CARTO Positron
/// (2026-09-27) but preferred the original look back (2026-09-29). CARTO
/// stays available behind WALK_MAP_STYLE=carto instead of being deleted, in
/// case that preference changes again.
enum WalkMapStyle { osm, carto }

WalkMapStyle _resolveStyle(AppRuntimeConfigLoader loader) {
  final style = loader.load().walkMapStyle.trim().toLowerCase();
  return style == 'carto' ? WalkMapStyle.carto : WalkMapStyle.osm;
}

TileLayer buildWalkTileLayer() {
  const loader = AppRuntimeConfigLoader();
  if (_resolveStyle(loader) == WalkMapStyle.carto) {
    // CARTO now watermarks its free raster basemaps ("API KEY REQUIRED")
    // without one - free tier is plenty for this app's volume
    // (carto.com/basemaps/apikey), just needs registering as CARTO_API_KEY.
    final config = loader.load();
    final keySuffix = config.hasCartoApiKey ? '?key=${config.cartoApiKey}' : '';
    return TileLayer(
      urlTemplate:
          'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png$keySuffix',
      subdomains: const ['a', 'b', 'c', 'd'],
      userAgentPackageName: 'com.vetapp.mobile_app',
    );
  }

  // Official tile.openstreetmap.org: single host, no {s}/{r} placeholders
  // (it doesn't shard across subdomains or serve retina tiles).
  return TileLayer(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    userAgentPackageName: 'com.vetapp.mobile_app',
  );
}

Widget buildWalkMapAttribution() {
  const loader = AppRuntimeConfigLoader();
  return RichAttributionWidget(
    attributions: [
      const TextSourceAttribution('OpenStreetMap contributors'),
      if (_resolveStyle(loader) == WalkMapStyle.carto)
        const TextSourceAttribution('CARTO'),
    ],
  );
}
