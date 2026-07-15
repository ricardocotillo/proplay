import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:map_location_picker/map_location_picker.dart';

import 'package:proplay/utils/constants.dart';

/// Data class for location selection result
class LocationResult {
  final double lat;
  final double lng;
  final String? address;

  const LocationResult({required this.lat, required this.lng, this.address});
}

/// A reusable location picker widget that uses the user's current location
/// as the initial position, with fallback to last known location and Lima default.
class LocationPicker extends StatefulWidget {
  /// Called when the user selects a location and taps next
  final void Function(LocationResult result) onLocationSelected;

  /// Initial latitude if user already selected a location
  final double? initialLat;

  /// Initial longitude if user already selected a location
  final double? initialLng;

  const LocationPicker({
    super.key,
    required this.onLocationSelected,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  static const LatLng _limaDefault = LatLng(-12.0464, -77.0428);

  late final Future<LatLng> _initialPositionFuture;

  @override
  void initState() {
    super.initState();
    _initialPositionFuture = _getInitialPosition();
  }

  Future<LatLng> _getInitialPosition() async {
    // If user already selected a location, use that
    if (widget.initialLat != null && widget.initialLng != null) {
      return LatLng(widget.initialLat!, widget.initialLng!);
    }

    // Try current position first (with broad catch for web JS errors)
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('Error getting current position: $e');
    }

    // getLastKnownPosition is not supported on web - skip on web platform
    if (!kIsWeb) {
      try {
        final position = await Geolocator.getLastKnownPosition();
        if (position != null) {
          return LatLng(position.latitude, position.longitude);
        }
      } catch (e) {
        debugPrint('Error getting last known position: $e');
      }
    }

    return _limaDefault;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LatLng>(
      future: _initialPositionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final initialPosition = snapshot.data ?? _limaDefault;
        final apiKey = AppConstants.googleMapsApiKey;

        if (apiKey.isEmpty) {
          return const Center(
            child: Text('Error: Google Maps API key is missing'),
          );
        }

        return MapLocationPicker(
          config: MapLocationPickerConfig(
            apiKey: apiKey,
            initialPosition: initialPosition,
            onNext: (result) {
              if (result != null && result.geometry != null) {
                widget.onLocationSelected(
                  LocationResult(
                    lat: result.geometry!.location.lat,
                    lng: result.geometry!.location.lng,
                    address: result.formattedAddress,
                  ),
                );
              }
            },
          ),
          searchConfig: SearchConfig(
            apiKey: apiKey,
            searchHintText: 'Buscar ubicación...',
            hideOnEmpty: true,
          ),
        );
      },
    );
  }
}
