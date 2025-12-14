import 'package:campus_indoor_navigator/Sensor%20Testing/pdr_path_screen.dart';
import 'package:campus_indoor_navigator/Sensor%20Testing/wifi_scan_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'accelerometer_step_screen.dart';
import 'barometer_screen.dart';
import 'gyroscope_heading_screen.dart';
import 'magnetometer_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final items = <_MenuItem>[
      _MenuItem('Accelerometer / Step Detection', const AccelerometerStepScreen()),
      _MenuItem('Gyroscope / Heading Drift', const GyroscopeHeadingScreen()),
      _MenuItem('Magnetometer / Magnetic Fingerprint', const MagnetometerScreen()),
      //_MenuItem('Barometer / Floor Change', const BarometerScreen()),
      _MenuItem('Wi-Fi Scan / Fingerprint', const WifiScanScreen()),
      _MenuItem('PDR Path (Steps + Heading)', const PdrPathScreen()),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Indoor Nav Sensor Lab')),
      body: ListView.builder(
        itemCount: items.length,
        itemBuilder: (_, i) {
          final item = items[i];
          return ListTile(
            title: Text(item.title),
            onTap: () => _open(context, item.screen),
          );
        },
      ),
    );
  }
}

class _MenuItem {
  final String title;
  final Widget screen;
  _MenuItem(this.title, this.screen);
}