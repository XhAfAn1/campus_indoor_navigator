
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class ElevationApp extends StatefulWidget {
  const ElevationApp({super.key});

  @override
  _ElevationAppState createState() => _ElevationAppState();
}

class _ElevationAppState extends State<ElevationApp> {
  double? _elevation;
  double? _lat;
  double? _long;

  @override
  void initState() {
    super.initState();
    _getElevation();
  }

  Future<void> _getElevation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      _elevation = position.altitude;
      _lat = position.latitude;
      _long = position.longitude;

      debugPrint('$_elevation');
    } catch (e) {
      print("Error getting elevation: $e");
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ElevationApp'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Elevation test:',
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 10),
            Text(
              _elevation != null ? '$_elevation meters' : 'Fetching elevation...',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            const Text(
              'at position:',
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 10),
            Text(
              _long != null ? 'Long: $_long' : 'Fetching position...',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              _lat != null ? 'Lat: $_lat' : 'Fetching position...',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            ElevatedButton(
                onPressed: _getElevation,
                child:
                const Text('Get Location Again'))
          ],
        ),
      ),
    );
  }
}