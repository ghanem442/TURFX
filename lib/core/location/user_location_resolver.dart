import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Coordinates used for "near me" field search.
class GeoSearchParams {
  final double latitude;
  final double longitude;
  final int radiusKm;

  const GeoSearchParams({
    required this.latitude,
    required this.longitude,
    this.radiusKm = 10,
  });

  static const cairoFallback = GeoSearchParams(
    latitude: 30.0444,
    longitude: 31.2357,
    radiusKm: 10,
  );
}

/// Tries GPS; on denial, disabled service, or timeout returns [GeoSearchParams.cairoFallback].
Future<GeoSearchParams> resolveGeoSearchParams() async {
  try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return GeoSearchParams.cairoFallback;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return GeoSearchParams.cairoFallback;
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
      ),
    ).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw TimeoutException('location'),
    );

    return GeoSearchParams(
      latitude: pos.latitude,
      longitude: pos.longitude,
      radiusKm: 10,
    );
  } on Object {
    return GeoSearchParams.cairoFallback;
  }
}
