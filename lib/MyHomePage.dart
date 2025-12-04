import 'package:campus_indoor_navigator/backend/Authentication.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  final CameraPosition _initialPosition =
  const CameraPosition(target: LatLng(23.768658449880945, 90.42547549236623), zoom: 18);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Navigator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Authentication().signout(context);
            },
          )
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: _initialPosition,
        mapType: MapType.normal,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        zoomControlsEnabled: true,
      ),
    );
  }
}
