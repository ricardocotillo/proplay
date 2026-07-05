import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class SessionMapScreen extends StatelessWidget {
  final String title;
  final double latitude;
  final double longitude;
  final String? address;

  const SessionMapScreen({
    super.key,
    required this.title,
    required this.latitude,
    required this.longitude,
    this.address,
  });

  @override
  Widget build(BuildContext context) {
    final LatLng position = LatLng(latitude, longitude);
<<<<<<< HEAD

    return Scaffold(
      appBar: AppBar(title: Text(title), centerTitle: true),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: position, zoom: 15),
=======
    
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: position,
              zoom: 15,
            ),
>>>>>>> f90b32edf759e3763100e686d1a03dd096e8d967
            markers: {
              Marker(
                markerId: const MarkerId('session_location'),
                position: position,
<<<<<<< HEAD
                infoWindow: InfoWindow(title: title, snippet: address),
=======
                infoWindow: InfoWindow(
                  title: title,
                  snippet: address,
                ),
>>>>>>> f90b32edf759e3763100e686d1a03dd096e8d967
              ),
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
            mapToolbarEnabled: true,
          ),
          if (address != null && address!.isNotEmpty)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          address!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
