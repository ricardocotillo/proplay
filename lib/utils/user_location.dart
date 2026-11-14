import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Best-effort user location. Returns null when unavailable or denied;
/// callers must work without it (feed is then sorted by date).
Future<({double lat, double lng})?> loadUserLocation() async {
  try {
    if (kIsWeb) {
      // permission_handler has no web support; the browser prompts natively.
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return (lat: p.latitude, lng: p.longitude);
    }

    final granted =
        (await Permission.location.status).isGranted ||
        (await Permission.locationWhenInUse.status).isGranted;
    if (!granted) return null;

    // Last known first (works better on emulators), then a fresh fix.
    final p =
        await Geolocator.getLastKnownPosition() ??
        await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 10),
          ),
        );
    return (lat: p.latitude, lng: p.longitude);
  } catch (_) {
    return null;
  }
}
