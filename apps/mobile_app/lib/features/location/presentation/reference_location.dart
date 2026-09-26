import '../domain/coordinates.dart';

/// Shared "where am I for distance purposes" resolution, used anywhere a
/// feature needs one coordinate to measure distance from (local activities,
/// marketplace, home dashboard). Honors the user's mode choice first -
/// "Residenza abituale" should actually change what these features treat
/// as the reference point, not just the label shown in Impostazioni - then
/// falls back to whichever of the two is actually set, then to [fallback].
Coordinates resolveReferenceLocation(UserLocationPreference preference, Coordinates fallback) {
  final preferred = preference.mode == LocationMode.homeResidence ? preference.home : preference.current;
  return preferred ?? preference.current ?? preference.home ?? fallback;
}
