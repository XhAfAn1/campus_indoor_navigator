import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

class GyroscopeHeadingScreen extends StatefulWidget {
  const GyroscopeHeadingScreen({Key? key}) : super(key: key);

  @override
  State<GyroscopeHeadingScreen> createState() => _GyroscopeHeadingScreenState();
}

class _GyroscopeHeadingScreenState extends State<GyroscopeHeadingScreen> {
  StreamSubscription<GyroscopeEvent>? _gyroSub;

  double _rawX = 0, _rawY = 0, _rawZ = 0;
  double _headingDeg = 0;
  int? _lastTimestampUs;

  @override
  void initState() {
    super.initState();
    _gyroSub = gyroscopeEvents.listen(_onGyro);
  }

  void _onGyro(GyroscopeEvent event) {
    final nowUs = DateTime.now().microsecondsSinceEpoch;
    if (_lastTimestampUs == null) {
      _lastTimestampUs = nowUs;
      return;
    }
    final dt = (nowUs - _lastTimestampUs!) / 1e6; // seconds
    _lastTimestampUs = nowUs;

    _rawX = event.x;
    _rawY = event.y;
    _rawZ = event.z;

    // integrate z-axis rotation to heading (assuming phone is flat)
    _headingDeg += _rawZ * (180 / pi) * dt;

    // normalize
    _headingDeg %= 360;
    if (_headingDeg < 0) _headingDeg += 360;

    setState(() {});
  }

  @override
  void dispose() {
    _gyroSub?.cancel();
    super.dispose();
  }

  void _resetHeading() {
    setState(() {
      _headingDeg = 0;
      _lastTimestampUs = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gyroscope / Heading Drift')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Raw gyroscope (rad/s)', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('x: ${_rawX.toStringAsFixed(4)}'),
            Text('y: ${_rawY.toStringAsFixed(4)}'),
            Text('z: ${_rawZ.toStringAsFixed(4)}'),
            const SizedBox(height: 12),
            Text(
              'Integrated heading (deg): ${_headingDeg.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _resetHeading,
              child: const Text('Reset heading'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Test: Put phones flat, reset heading, rotate 90° left/right and compare final heading.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
