import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'sensor_utils.dart';

class PdrPathScreen extends StatefulWidget {
  const PdrPathScreen({Key? key}) : super(key: key);

  @override
  State<PdrPathScreen> createState() => _PdrPathScreenState();
}

class _PdrPathScreenState extends State<PdrPathScreen> {
  // Subscriptions
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<MagnetometerEvent>? _magSub;

  // Filters
  final LowPassFilter _accelLow = LowPassFilter(alpha: 0.1);
  final HighPassFilter _accelHigh = HighPassFilter(alpha: 0.1);

  // Step detection
  final double _stepThreshold = 1.0;
  final double _minStepIntervalMs = 250;
  double _lastPeakTime = 0;
  int _steps = 0;

  // Magnetometer
  double _mx = 0, _my = 0;

  // Heading & position
  double _headingDeg = 0;
  Offset _position = Offset.zero;
  List<Offset> _path = [Offset.zero];

  @override
  void initState() {
    super.initState();

    _accelSub = accelerometerEvents.listen(_onAccel);
    _magSub = magnetometerEvents.listen(_onMag);
  }

  // ---------- STEP DETECTION ----------
  void _onAccel(AccelerometerEvent event) {
    final now = DateTime.now().millisecondsSinceEpoch.toDouble();

    final mag = vectorMagnitude(event.x, event.y, event.z);
    final low = _accelLow.filter(mag);
    final high = _accelHigh.filter(low);

    if (high > _stepThreshold &&
        now - _lastPeakTime > _minStepIntervalMs) {
      _lastPeakTime = now;
      _steps++;
      _updatePosition();
    }

    setState(() {});
  }

  // ---------- HEADING FROM MAGNETOMETER ----------
  void _onMag(MagnetometerEvent event) {
    _mx = event.x;
    _my = event.y;

    // Simple azimuth (flat-device assumption)
    double az = atan2(_my, _mx) * 180 / pi;
    if (az < 0) az += 360;
    _headingDeg = az;
  }

  // ---------- POSITION UPDATE ----------
  void _updatePosition() {
    const double stepLengthMeters = 0.7;

    final headingRad = _headingDeg * pi / 180;
    final dx = stepLengthMeters * sin(headingRad);
    final dy = -stepLengthMeters * cos(headingRad); // screen Y down

    _position = Offset(_position.dx + dx, _position.dy + dy);
    _path = List.of(_path)..add(_position);
  }

  void _reset() {
    setState(() {
      _steps = 0;
      _position = Offset.zero;
      _path = [Offset.zero];
    });
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _magSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PDR Path (Steps + Heading)')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Steps: $_steps',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Heading: ${_headingDeg.toStringAsFixed(1)}°'),
                Text(
                    'Position: (${_position.dx.toStringAsFixed(2)}, ${_position.dy.toStringAsFixed(2)}) m'),
                const SizedBox(height: 8),
                ElevatedButton(onPressed: _reset, child: const Text('Reset')),
              ],
            ),
          ),
          Expanded(
            child: CustomPaint(
              painter: _PathPainter(_path),
              child: Container(color: Colors.black12),
            ),
          ),
        ],
      ),
    );
  }
}

class _PathPainter extends CustomPainter {
  final List<Offset> path;

  _PathPainter(this.path);

  @override
  void paint(Canvas canvas, Size size) {
    if (path.isEmpty) return;

    double minX = path.first.dx, maxX = path.first.dx;
    double minY = path.first.dy, maxY = path.first.dy;

    for (final p in path) {
      minX = min(minX, p.dx);
      maxX = max(maxX, p.dx);
      minY = min(minY, p.dy);
      maxY = max(maxY, p.dy);
    }

    final width = maxX - minX;
    final height = maxY - minY;

    final scaleX = width == 0 ? 1.0 : size.width / (width * 1.2);
    final scaleY = height == 0 ? 1.0 : size.height / (height * 1.2);
    final scale = min(scaleX, scaleY);

    final offsetX = size.width / 2;
    final offsetY = size.height / 2;

    final pathPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final pathObj = Path();
    bool first = true;

    for (final p in path) {
      final x = (p.dx - (minX + maxX) / 2) * scale + offsetX;
      final y = (p.dy - (minY + maxY) / 2) * scale + offsetY;

      if (first) {
        pathObj.moveTo(x, y);
        first = false;
      } else {
        pathObj.lineTo(x, y);
      }
    }

    canvas.drawPath(pathObj, pathPaint);

    // Draw current position
    final last = path.last;
    final lx = (last.dx - (minX + maxX) / 2) * scale + offsetX;
    final ly = (last.dy - (minY + maxY) / 2) * scale + offsetY;

    canvas.drawCircle(
      Offset(lx, ly),
      6,
      Paint()..color = Colors.red,
    );
  }

  @override
  bool shouldRepaint(covariant _PathPainter oldDelegate) =>
      oldDelegate.path != path;
}
