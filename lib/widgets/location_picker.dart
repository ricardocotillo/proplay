import 'package:flutter/material.dart';
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

  LatLng _initialPosition = _limaDefault;
  bool _isLoadingPosition = true;

  @override
  void initState() {
    super.initState();
    _loadInitialPosition();
  }

  Future<void> _loadInitialPosition() async {
    // If user already selected a location, use that
    if (widget.initialLat != null && widget.initialLng != null) {
      setState(() {
        _initialPosition = LatLng(widget.initialLat!, widget.initialLng!);
        _isLoadingPosition = false;
      });
      return;
    }

    try {
      // Try last known position first (faster)
      Position? position = await Geolocator.getLastKnownPosition();

      // If no last known position, try getting current position
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (mounted && position != null) {
        setState(() {
          _initialPosition = LatLng(position!.latitude, position.longitude);
        });
      }
    } catch (e) {
      // Keep Lima default if location fetch fails
      debugPrint('Error getting initial position: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingPosition = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingPosition) {
      return const Center(child: CircularProgressIndicator());
    }

    return MapLocationPicker(
      config: MapLocationPickerConfig(
        apiKey: AppConstants.googleMapsApiKey,
        initialPosition: _initialPosition,
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
        apiKey: AppConstants.googleMapsApiKey,
        searchHintText: 'Buscar ubicación...',
        hideOnEmpty: true,
      ),
    );
  }
}
