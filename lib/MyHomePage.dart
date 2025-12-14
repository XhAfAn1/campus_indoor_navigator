import 'dart:io';
import 'package:campus_indoor_navigator/backend/Authentication.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'Elevation test/altitude.dart';
import 'Location with sensor test/RSSI list.dart';
import 'Location with sensor test/test claude.dart' hide Position;
import 'Sensor Testing/testmain.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  MapboxMap? _mapboxMap;
  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(title: const Text("Map"),
      actions: [
        TextButton(onPressed:(){Authentication().signout(context);}, child: Icon(Icons.logout))
      ],
      ),

      drawer: Drawer(
        child: ListView(
          children: [
            ListTile(
              title: Text("Elevation"),
              onTap: (){
                Navigator.push(context, MaterialPageRoute(builder: (context) => ElevationApp()));
              },
            ),
            ListTile(
              title: Text("RSSI"),
              onTap: (){
                Navigator.push(context, MaterialPageRoute(builder: (context) => RSSIApp()));
              },
            ),
            ListTile(
              title: Text("WIFI FootPrint"),
              onTap: (){
                Navigator.push(context, MaterialPageRoute(builder: (context) => IndoorNavApp()));
              },
            ),
            ListTile(
              title: Text("Sensor Testing"),
              onTap: (){
                Navigator.push(context, MaterialPageRoute(builder: (context) => HomeScreen()));
              },
            )
          ],
        )
      ),

      body: MapWidget(
        key: const ValueKey("mapWidget"),
        cameraOptions: CameraOptions(
          // Your center point
          center: Point(coordinates: Position(90.425475, 23.768658)),
          zoom: 14.0,
        ),
        styleUri: MapboxStyles.MAPBOX_STREETS,
        onMapCreated: _onMapCreated,

      ),
    );
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    // --- 1. HIDE UI ELEMENTS (The correct way) ---
    //await mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    //await mapboxMap.compass.updateSettings(CompassSettings(enabled: false));
    //await mapboxMap.logo.updateSettings(LogoSettings(enabled: false));
    //await mapboxMap.attribution.updateSettings(AttributionSettings(enabled: false));

    await mapboxMap.setBounds(
      CameraBoundsOptions(
        maxZoom: 50.0,
        minZoom: 0.0,
      ),
    );

    /// Enable user location
    await mapboxMap.location.updateSettings(LocationComponentSettings(
      enabled: true,
     // pulsingEnabled: true,
      pulsingColor: Colors.blue.value,
      showAccuracyRing: true,
      puckBearingEnabled: true,

    ));


    // 1. Convert the asset to a file path so Mapbox Native can read it
    final String imagePath = await _copyAssetToTemp('assets/floorplan.jpg');


    final coordinates = [
      [90.425222, 23.769375], // Top-Left
      [90.426480, 23.768837], // Top-Right
      [90.425734, 23.767769], // Bottom-Right
      [90.424597, 23.768405], // Bottom-Left
    ];

    // 3. Add the Source (The Data)
    await mapboxMap.style.addSource(
      ImageSource(
        id: "floorplan-source",
        url: "file://$imagePath",
        coordinates: coordinates,
      ),
    );

    // 4. Add the Layer (The Visual)
    await mapboxMap.style.addLayer(
      RasterLayer(
        id: "floorplan-layer",
        sourceId: "floorplan-source",
        rasterOpacity: 0.8,
        rasterFadeDuration: 0.0,
      ),
    );
  }

  // Helper to copy asset to a temporary file
  Future<String> _copyAssetToTemp(String assetName) async {
    final bytes = await rootBundle.load(assetName);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/temp_floorplan.jpg');
    await file.writeAsBytes(bytes.buffer.asUint8List());
    return file.path;
  }

}

