import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

import 'coordinates.dart';

const double _earthRadiusMeters = 6371008.8;

/// Mirrors packages/core/domain/geo/models.py:haversine_distance_km (here
/// in meters directly). The mobile app writes straight to Supabase with
/// no backend API in between, so this Dart copy is what actually runs for
/// every "distance to me" computation on the client.
double haversineMeters(Coordinates a, Coordinates b) {
  final lat1 = a.latitude * math.pi / 180;
  final lat2 = b.latitude * math.pi / 180;
  final deltaLat = (b.latitude - a.latitude) * math.pi / 180;
  final deltaLon = (b.longitude - a.longitude) * math.pi / 180;

  final h = math.pow(math.sin(deltaLat / 2), 2) +
      math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(deltaLon / 2), 2);
  return 2 * _earthRadiusMeters * math.asin(math.sqrt(h));
}

/// Mirrors packages/core/domain/geo/models.py:fuzz_coordinates byte-for-byte
/// (same SHA-256 seeding, same 300-800m polar offset). Kept as a literal
/// port rather than a "close enough" reimplementation because the Python
/// version's own unit tests are the source of truth for the algorithm; a
/// fixture-based Dart test (features/location tests) pins one known
/// input/output pair computed from the Python side to catch drift.
Coordinates fuzzCoordinates(Coordinates exact, String listingId) {
  final digest = sha256.convert(utf8.encode(listingId)).bytes;
  final bearingSeed = _bytesToUint32(digest.sublist(0, 4));
  final distanceSeed = _bytesToUint32(digest.sublist(4, 8));

  const maxUint32 = 4294967295; // 0xFFFFFFFF
  final bearingRadians = (bearingSeed / maxUint32) * 2 * math.pi;
  final distanceMeters = 300 + (distanceSeed / maxUint32) * 500;

  const metersPerDegreeLatitude = 111320.0;
  final cosLatitude = math.cos(exact.latitude * math.pi / 180);
  final metersPerDegreeLongitude =
      cosLatitude != 0 ? metersPerDegreeLatitude * cosLatitude : metersPerDegreeLatitude;

  final deltaLat = (distanceMeters * math.cos(bearingRadians)) / metersPerDegreeLatitude;
  final deltaLon = (distanceMeters * math.sin(bearingRadians)) / metersPerDegreeLongitude;

  return Coordinates(
    latitude: (exact.latitude + deltaLat).clamp(-90.0, 90.0),
    longitude: (exact.longitude + deltaLon).clamp(-180.0, 180.0),
  );
}

int _bytesToUint32(List<int> bytes) {
  return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
}
