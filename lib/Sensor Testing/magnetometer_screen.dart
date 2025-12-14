import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'sensor_utils.dart';

class MagnetometerScreen extends StatefulWidget {
  const MagnetometerScreen({Key? key}) : super(key: key);

  @override
  State<MagnetometerScreen> createState() => _MagnetometerScreenState();
}

class _MagnetometerScreenState extends State<MagnetometerScreen> {
  StreamSubscription<MagnetometerEvent>? _magSub;

  double _mx = 0, _my = 0, _mz = 0;
  double _magnitude = 0;
  double _azimuthDeg = 0;

  @override
  void initState() {
    super.initState();
    _magSub = magnetometerEvents.listen(_onMag);
  }

  void _onMag(MagnetometerEvent event) {
    _mx = event.x;
    _my = event.y;
    _mz = event.z;

    _magnitude = vectorMagnitude(_mx, _my, _mz);

    // Simple compass azimuth (flat phone)
    double az = atan2(_my, _mx) * 180 / pi;
    if (az < 0) az += 360;
    _azimuthDeg = az;

    setState(() {});
  }

  @override
  void dispose() {
    _magSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
      AppBar(title: const Text('Magnetometer / Magnetic Fingerprint')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Magnetic Field (µT approx)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('x: ${_mx.toStringAsFixed(3)}'),
            Text('y: ${_my.toStringAsFixed(3)}'),
            Text('z: ${_mz.toStringAsFixed(3)}'),
            const SizedBox(height: 8),
            Text('Magnitude: ${_magnitude.toStringAsFixed(3)}'),
            const SizedBox(height: 12),
            Text(
              'Compass azimuth: ${_azimuthDeg.toStringAsFixed(2)}°',
              style:
              const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Test: Walk hallway; magnetic magnitude curves should match between phones.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
