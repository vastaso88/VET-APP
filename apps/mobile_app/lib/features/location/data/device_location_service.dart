import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../domain/coordinates.dart';

enum LocationRequestFailure {
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
  timeout,
  unsupported,
}

class DeviceLocationResult {
  const DeviceLocationResult.success(this.coordinates) : failure = null;

  const DeviceLocationResult.failure(this.failure) : coordinates = null;

  final Coordinates? coordinates;
  final LocationRequestFailure? failure;

  bool get isSuccess => coordinates != null;
}

/// Injectable boundary around `geolocator` so callers/tests can substitute
/// a fake position without a real device/browser permission prompt — the
/// one piece of the "Località" foundation that genuinely can't be
/// unit-tested end-to-end (see docs/maps/).
abstract class LocationSampler {
  Future<DeviceLocationResult> requestCurrentPosition();
}

class GeolocatorLocationSampler implements LocationSampler {
  const GeolocatorLocationSampler();

  @override
  Future<DeviceLocationResult> requestCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const DeviceLocationResult.failure(LocationRequestFailure.serviceDisabled);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return const DeviceLocationResult.failure(LocationRequestFailure.permissionDenied);
      }
      if (permission == LocationPermission.deniedForever) {
        return const DeviceLocationResult.failure(LocationRequestFailure.permissionDeniedForever);
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return DeviceLocationResult.success(
        Coordinates(latitude: position.latitude, longitude: position.longitude),
      );
    } on LocationServiceDisabledException {
      return const DeviceLocationResult.failure(LocationRequestFailure.serviceDisabled);
    } on TimeoutException {
      return const DeviceLocationResult.failure(LocationRequestFailure.timeout);
    } catch (_) {
      return const DeviceLocationResult.failure(LocationRequestFailure.unsupported);
    }
  }
}
