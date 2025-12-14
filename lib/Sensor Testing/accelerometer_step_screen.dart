import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'sensor_utils.dart';

class AccelerometerStepScreen extends StatefulWidget {
  const AccelerometerStepScreen({Key? key}) : super(key: key);

  @override
  State<AccelerometerStepScreen> createState() => _AccelerometerStepScreenState();
}

class _AccelerometerStepScreenState extends State<AccelerometerStepScreen> {
  StreamSubscription<AccelerometerEvent>? _accelSub;

  double _rawX = 0, _rawY = 0, _rawZ = 0;
  double _mag = 0;
  double _filteredMag = 0;
  int _steps = 0;
  double _lastPeakTime = 0;

  final _lowPass = LowPassFilter(alpha: 0.1);
  final _highPass = HighPassFilter(alpha: 0.1);

  // tuning parameters
  final double _peakThreshold = 1.0; // g after gravity removal
  final double _minStepIntervalMs = 250; // min 0.25s between steps

  @override
  void initState() {
    super.initState();
    _accelSub = accelerometerEvents.listen(_onAccel);
  }

  void _onAccel(AccelerometerEvent event) {
    final now = DateTime.now().millisecondsSinceEpoch.toDouble();

    // raw
    _rawX = event.x;
    _rawY = event.y;
    _rawZ = event.z;
    _mag = vectorMagnitude(_rawX, _rawY, _rawZ);

    // we want magnitude around 1g; remove gravity with high-pass
    double magFilteredLow = _lowPass.filter(_mag);
    double magHigh = _highPass.filter(magFilteredLow);

    // peak detection: detect upward zero-crossing above threshold
    // very simple heuristic; you can refine later
    if (magHigh > _peakThreshold) {
      if (now - _lastPeakTime > _minStepIntervalMs) {
        _lastPeakTime = now;
        _steps++;
      }
    }

    setState(() {
      _filteredMag = magHigh;
    });
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accelerometer / Steps')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Raw accelerometer (m/s²)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('x: ${_rawX.toStringAsFixed(3)}'),
            Text('y: ${_rawY.toStringAsFixed(3)}'),
            Text('z: ${_rawZ.toStringAsFixed(3)}'),
            const SizedBox(height: 8),
            Text('Magnitude: ${_mag.toStringAsFixed(3)}'),
            Text('Filtered (high-pass): ${_filteredMag.toStringAsFixed(3)}'),
            const SizedBox(height: 16),
            Text(
              'Detected steps: $_steps',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _steps = 0;
                });
              },
              child: const Text('Reset steps'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Test: Walk 20–30 steps with phones side-by-side and compare step counts.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
