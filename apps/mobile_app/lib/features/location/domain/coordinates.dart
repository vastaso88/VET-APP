class Coordinates {
  const Coordinates({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  @override
  bool operator ==(Object other) =>
      other is Coordinates && other.latitude == latitude && other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

enum LocationMode { currentPosition, homeResidence }

enum LocationSource { deviceGps, manual }

/// Mirrors the backend's UserLocation shape (packages/core/domain/geo).
/// `mode` picks which of `home`/`current` other features should read; the
/// exact UI toggle label is a presentation decision, not modeled here (see
/// docs/settings/01_brainstorm.md).
class UserLocationPreference {
  const UserLocationPreference({
    this.mode = LocationMode.currentPosition,
    this.home,
    this.homeLabel,
    this.homeCountryCode,
    this.homeCity,
    this.homeSavedAt,
    this.current,
    this.currentLabel,
    this.currentSource,
    this.currentCapturedAt,
  });

  final LocationMode mode;
  final Coordinates? home;
  final String? homeLabel;
  final String? homeCountryCode;
  final String? homeCity;
  final DateTime? homeSavedAt;
  final Coordinates? current;
  final String? currentLabel;
  final LocationSource? currentSource;
  final DateTime? currentCapturedAt;

  UserLocationPreference copyWith({
    LocationMode? mode,
    Coordinates? home,
    String? homeLabel,
    String? homeCountryCode,
    String? homeCity,
    DateTime? homeSavedAt,
    Coordinates? current,
    String? currentLabel,
    LocationSource? currentSource,
    DateTime? currentCapturedAt,
  }) {
    return UserLocationPreference(
      mode: mode ?? this.mode,
      home: home ?? this.home,
      homeLabel: homeLabel ?? this.homeLabel,
      // A changed residence must not inherit the previous country's metadata.
      homeCountryCode: home != null ? homeCountryCode : homeCountryCode ?? this.homeCountryCode,
      homeCity: home != null ? homeCity : homeCity ?? this.homeCity,
      homeSavedAt: home != null ? homeSavedAt : homeSavedAt ?? this.homeSavedAt,
      current: current ?? this.current,
      currentLabel: currentLabel ?? this.currentLabel,
      currentSource: currentSource ?? this.currentSource,
      currentCapturedAt: currentCapturedAt ?? this.currentCapturedAt,
    );
  }
}
