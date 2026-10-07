import '../../location/domain/coordinates.dart';

/// Grid cells per degree: every listing position is snapped to a 0.01° grid,
/// ~1.1 km north-south and ~0.8 km east-west at Italian latitudes.
const listingLocationStepsPerDegree = 100;

/// Snaps an exact position to the nearest point of a fixed ~1 km grid.
///
/// Replaces the per-listing random offset (geo_math.dart:fuzzCoordinates)
/// used before 2026-10-07: an offset that changes with every listing can be
/// averaged away across one seller's listings, while a snapped position is
/// the same for everyone in the cell and reveals nothing finer than the
/// cell itself. Mirrored in packages/core/domain/geo/models.py:
/// approximate_coordinates.
Coordinates approximateListingLocation(Coordinates exact) {
  return Coordinates(
    latitude: _snap(exact.latitude).clamp(-90.0, 90.0),
    longitude: _snap(exact.longitude).clamp(-180.0, 180.0),
  );
}

double _snap(double value) {
  // Integer steps first, then divide: multiplying back by 0.01 would leave
  // float noise (45.46000000000001) and two equal cells could compare unequal.
  return (value * listingLocationStepsPerDegree).round() / listingLocationStepsPerDegree;
}
