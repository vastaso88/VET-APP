/// Shared "how far" formatting, used anywhere a distance-to-me is shown
/// (marketplace listings, local activities).
String formatDistance(double distanceMeters) {
  if (distanceMeters < 1000) {
    return '${distanceMeters.round()} m';
  }
  return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
}
