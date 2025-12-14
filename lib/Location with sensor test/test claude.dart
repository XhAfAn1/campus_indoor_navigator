import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:math';
import 'dart:collection';


class IndoorNavApp extends StatelessWidget {
  const IndoorNavApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Campus Navigator',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const NavigatorHomePage(),
    );
  }
}

class NavigatorHomePage extends StatefulWidget {
  const NavigatorHomePage({Key? key}) : super(key: key);

  @override
  State<NavigatorHomePage> createState() => _NavigatorHomePageState();
}

class _NavigatorHomePageState extends State<NavigatorHomePage> {
  // Current position estimate
  double currentX = 0;
  double currentY = 0;
  double currentFloor = 0;
  double currentHeading = 0;
  double confidenceLevel = 0.0;

  // Enhanced step detection
  int stepCount = 0;
  double stepLength = 0.7;
  Queue<double> accelBuffer = Queue();
  DateTime? lastStepTime;

  // WiFi positioning
  List<WiFiAccessPoint> nearbyWiFi = [];
  String estimatedLocation = "Initializing...";
  Timer? wifiScanTimer;

  // Sensor data
  double basePressure = 1013.25; // Standard atmospheric pressure
  Vector3 gravity = Vector3(0, 0, 9.8);
  Vector3 linearAccel = Vector3(0, 0, 0);

  // Sensor subscriptions
  StreamSubscription<AccelerometerEvent>? accelSubscription;
  StreamSubscription<GyroscopeEvent>? gyroSubscription;
  StreamSubscription<MagnetometerEvent>? magnetSubscription;

  // Mode
  bool isMappingMode = false;

  // Fingerprint database
  Map<String, LocationFingerprint> fingerprintDB = {};

  // Particle filter for sensor fusion
  List<Particle> particles = [];
  final int particleCount = 100;

  // Movement history for path visualization
  List<Position> pathHistory = [];

  @override
  void initState() {
    super.initState();
    _initializeParticles();
    _requestPermissions();
    _initializeSensors();
    _startPeriodicWiFiScan();
  }

  Future<void> _requestPermissions() async {
    await Permission.location.request();
    await Permission.locationWhenInUse.request();
  }

  void _initializeParticles() {
    particles = List.generate(particleCount, (i) => Particle(
      x: currentX + (Random().nextDouble() - 0.5) * 10,
      y: currentY + (Random().nextDouble() - 0.5) * 10,
      heading: Random().nextDouble() * 360,
      weight: 1.0 / particleCount,
    ));
  }

  void _initializeSensors() {
    // Enhanced step detection with buffer
    accelSubscription = accelerometerEventStream().listen((AccelerometerEvent event) {
      double magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

      accelBuffer.add(magnitude);
      if (accelBuffer.length > 20) accelBuffer.removeFirst();

      _detectStep();
      _updateLinearAcceleration(event);
    });

    // Gyroscope for rotation
    gyroSubscription = gyroscopeEventStream().listen((GyroscopeEvent event) {
      // Integrate gyroscope to update heading
      double dt = 0.02; // ~50Hz sample rate
      setState(() {
        currentHeading += event.z * dt * 180 / pi;
        currentHeading = currentHeading % 360;
      });
    });

    // Magnetometer for absolute heading
    magnetSubscription = magnetometerEventStream().listen((MagnetometerEvent event) {
      // Calculate absolute heading
      double heading = atan2(event.y, event.x) * 180 / pi;

      // Smooth fusion with gyroscope
      setState(() {
        currentHeading = 0.95 * currentHeading + 0.05 * heading;
      });
    });
  }

  void _updateLinearAcceleration(AccelerometerEvent event) {
    // Simple gravity removal (more sophisticated in production)
    linearAccel = Vector3(
      event.x - gravity.x,
      event.y - gravity.y,
      event.z - gravity.z,
    );
  }

  void _detectStep() {
    if (accelBuffer.length < 20) return;

    List<double> buffer = accelBuffer.toList();
    double mean = buffer.reduce((a, b) => a + b) / buffer.length;
    double variance = buffer.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) / buffer.length;
    double stdDev = sqrt(variance);

    // Peak detection
    double current = buffer.last;
    double previous = buffer[buffer.length - 2];

    bool isPeak = current > mean + 1.5 * stdDev && previous < current;

    DateTime now = DateTime.now();
    if (isPeak && (lastStepTime == null || now.difference(lastStepTime!).inMilliseconds > 200)) {
      lastStepTime = now;
      _onStepDetected();
    }
  }

  void _onStepDetected() {
    setState(() {
      stepCount++;
    });

    // Update particles with step
    for (var particle in particles) {
      double noise = (Random().nextDouble() - 0.5) * 0.2;
      particle.x += (stepLength + noise) * cos(particle.heading * pi / 180);
      particle.y += (stepLength + noise) * sin(particle.heading * pi / 180);
      particle.heading += (Random().nextDouble() - 0.5) * 10; // heading uncertainty
    }

    _updatePositionFromParticles();
  }

  void _startPeriodicWiFiScan() {
    wifiScanTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _scanWiFi();
    });
  }

  Future<void> _scanWiFi() async {
    try {
      // Check if can scan
      final canScan = await WiFiScan.instance.canStartScan();

      // Start scan based on result
      if (canScan == CanStartScan.yes) {
        final result = await WiFiScan.instance.startScan();

        if (result) {
          // Wait a bit for scan to complete
          await Future.delayed(const Duration(milliseconds: 500));

          // Get scan results
          final accessPoints = await WiFiScan.instance.getScannedResults();

          setState(() {
            nearbyWiFi = accessPoints.map((ap) => WiFiAccessPoint(
              ssid: ap.ssid,
              bssid: ap.bssid,
              level: ap.level,
            )).toList();

            _updateParticleWeights();
            _resampleParticles();
            _estimateLocation();
          });
        }
      }
    } catch (e) {
      print('WiFi scan error: $e');
    }
  }

  void _updateParticleWeights() {
    if (nearbyWiFi.isEmpty || fingerprintDB.isEmpty) return;

    for (var particle in particles) {
      double bestDistance = double.infinity;

      // Find nearest fingerprint to this particle
      fingerprintDB.forEach((name, fingerprint) {
        double spatialDist = sqrt(
            pow(particle.x - fingerprint.x, 2) +
                pow(particle.y - fingerprint.y, 2)
        );

        if (spatialDist < 10) { // Within 10m
          double signalDist = _calculateFingerprintDistance(fingerprint);
          double combinedDist = spatialDist * 0.3 + signalDist * 0.7;

          if (combinedDist < bestDistance) {
            bestDistance = combinedDist;
          }
        }
      });

      // Weight based on distance (closer = higher weight)
      particle.weight = bestDistance < double.infinity
          ? exp(-bestDistance / 5)
          : 0.001;
    }

    // Normalize weights
    double totalWeight = particles.fold(0.0, (sum, p) => sum + p.weight);
    if (totalWeight > 0) {
      for (var particle in particles) {
        particle.weight /= totalWeight;
      }
    }
  }

  void _resampleParticles() {
    List<Particle> newParticles = [];

    // Systematic resampling
    double r = Random().nextDouble() / particleCount;
    double c = particles[0].weight;
    int i = 0;

    for (int m = 0; m < particleCount; m++) {
      double u = r + m / particleCount;
      while (u > c && i < particles.length - 1) {
        i++;
        c += particles[i].weight;
      }

      newParticles.add(Particle(
        x: particles[i].x + (Random().nextDouble() - 0.5) * 0.5,
        y: particles[i].y + (Random().nextDouble() - 0.5) * 0.5,
        heading: particles[i].heading + (Random().nextDouble() - 0.5) * 5,
        weight: 1.0 / particleCount,
      ));
    }

    particles = newParticles;
  }

  void _updatePositionFromParticles() {
    double sumX = 0, sumY = 0, sumHeading = 0;
    double totalWeight = 0;

    for (var particle in particles) {
      sumX += particle.x * particle.weight;
      sumY += particle.y * particle.weight;
      sumHeading += particle.heading * particle.weight;
      totalWeight += particle.weight;
    }

    setState(() {
      currentX = sumX / totalWeight;
      currentY = sumY / totalWeight;
      currentHeading = sumHeading / totalWeight;

      // Calculate confidence from particle spread
      double variance = 0;
      for (var particle in particles) {
        double dx = particle.x - currentX;
        double dy = particle.y - currentY;
        variance += (dx * dx + dy * dy) * particle.weight;
      }
      confidenceLevel = 1.0 / (1.0 + sqrt(variance));

      pathHistory.add(Position(currentX, currentY));
      if (pathHistory.length > 100) pathHistory.removeAt(0);
    });
  }

  void _estimateLocation() {
    if (nearbyWiFi.isEmpty || fingerprintDB.isEmpty) {
      setState(() {
        estimatedLocation = "No reference points yet";
      });
      return;
    }

    String bestMatch = "Unknown";
    double bestDistance = double.infinity;

    fingerprintDB.forEach((locationName, fingerprint) {
      double distance = _calculateFingerprintDistance(fingerprint);
      if (distance < bestDistance) {
        bestDistance = distance;
        bestMatch = locationName;
      }
    });

    setState(() {
      estimatedLocation = bestMatch;
    });
  }

  double _calculateFingerprintDistance(LocationFingerprint fingerprint) {
    double sum = 0;
    int count = 0;

    for (var ap in nearbyWiFi) {
      if (fingerprint.signals.containsKey(ap.bssid)) {
        double diff = ap.level - fingerprint.signals[ap.bssid]!.toDouble();
        sum += diff * diff;
        count++;
      }
    }

    return count > 0 ? sqrt(sum / count) : double.infinity;
  }

  void _saveCurrentFingerprint(String locationName) {
    Map<String, int> signals = {};
    for (var ap in nearbyWiFi.take(10)) { // Save top 10 strongest signals
      signals[ap.bssid] = ap.level;
    }

    setState(() {
      fingerprintDB[locationName] = LocationFingerprint(
        locationName: locationName,
        x: currentX,
        y: currentY,
        floor: currentFloor,
        signals: signals,
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved: $locationName at (${currentX.toStringAsFixed(1)}, ${currentY.toStringAsFixed(1)})'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _resetPosition(double x, double y) {
    setState(() {
      currentX = x;
      currentY = y;
      stepCount = 0;
      pathHistory.clear();
      _initializeParticles();
    });
  }

  @override
  void dispose() {
    accelSubscription?.cancel();
    gyroSubscription?.cancel();
    magnetSubscription?.cancel();
    wifiScanTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isMappingMode ? 'Mapping Mode' : 'Navigation Mode'),
        actions: [
          IconButton(
            icon: Icon(isMappingMode ? Icons.navigation : Icons.map),
            onPressed: () {
              setState(() {
                isMappingMode = !isMappingMode;
              });
            },
            tooltip: 'Toggle Mode',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Map Visualization
            Container(
              height: 300,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[400]!),
              ),
              child: CustomPaint(
                painter: MapPainter(
                  currentX: currentX,
                  currentY: currentY,
                  heading: currentHeading,
                  particles: particles,
                  fingerprints: fingerprintDB.values.toList(),
                  pathHistory: pathHistory,
                ),
              ),
            ),

            // Position Info
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Position', style: Theme.of(context).textTheme.titleLarge),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: confidenceLevel > 0.7 ? Colors.green :
                            confidenceLevel > 0.4 ? Colors.orange : Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${(confidenceLevel * 100).toStringAsFixed(0)}% confident',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoItem('X', '${currentX.toStringAsFixed(1)}m'),
                        ),
                        Expanded(
                          child: _buildInfoItem('Y', '${currentY.toStringAsFixed(1)}m'),
                        ),
                        Expanded(
                          child: _buildInfoItem('Floor', currentFloor.toStringAsFixed(0)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoItem('Heading', '${currentHeading.toStringAsFixed(0)}°'),
                        ),
                        Expanded(
                          child: _buildInfoItem('Steps', stepCount.toString()),
                        ),
                        Expanded(
                          child: _buildInfoItem('WiFi APs', nearbyWiFi.length.toString()),
                        ),
                      ],
                    ),
                    if (estimatedLocation != "Unknown")
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on, color: Colors.blue),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  estimatedLocation,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Saved Locations
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Saved Locations (${fingerprintDB.length})',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    if (fingerprintDB.isEmpty)
                      const Text('No locations saved yet. Switch to Mapping Mode to start.')
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: fingerprintDB.keys.map((name) {
                          return Stack(
                            children: [
                              ActionChip(
                                label: Padding(
                                  padding: const EdgeInsets.only(right: 20),
                                  child: Text(name),
                                ),
                                avatar: const Icon(Icons.place, size: 16),
                                onPressed: () {
                                  var fp = fingerprintDB[name]!;
                                  _resetPosition(fp.x, fp.y);
                                },
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      fingerprintDB.remove(name);
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),

            // Controls
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (isMappingMode) ...[
                    ElevatedButton.icon(
                      onPressed: () => _showSaveDialog(),
                      icon: const Icon(Icons.add_location),
                      label: const Text('Save Current Location'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  OutlinedButton.icon(
                    onPressed: () => _resetPosition(0, 0),
                    icon: const Icon(Icons.my_location),
                    label: const Text('Reset to Origin (0, 0)'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  void _showSaveDialog() {
    String locationName = '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Location'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g., Building A Entrance',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => locationName = value,
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              _saveCurrentFingerprint(value);
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (locationName.isNotEmpty) {
                _saveCurrentFingerprint(locationName);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// Data classes
class WiFiAccessPoint {
  final String ssid;
  final String bssid;
  final int level;

  WiFiAccessPoint({
    required this.ssid,
    required this.bssid,
    required this.level,
  });
}

class LocationFingerprint {
  final String locationName;
  final double x, y, floor;
  final Map<String, int> signals;

  LocationFingerprint({
    required this.locationName,
    required this.x,
    required this.y,
    required this.floor,
    required this.signals,
  });
}

class Particle {
  double x, y, heading, weight;

  Particle({
    required this.x,
    required this.y,
    required this.heading,
    required this.weight,
  });
}

class Position {
  final double x, y;
  Position(this.x, this.y);
}

class Vector3 {
  final double x, y, z;
  Vector3(this.x, this.y, this.z);
}

// Map painter
class MapPainter extends CustomPainter {
  final double currentX, currentY, heading;
  final List<Particle> particles;
  final List<LocationFingerprint> fingerprints;
  final List<Position> pathHistory;

  MapPainter({
    required this.currentX,
    required this.currentY,
    required this.heading,
    required this.particles,
    required this.fingerprints,
    required this.pathHistory,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final scale = 10.0; // pixels per meter

    // Draw grid
    final gridPaint = Paint()..color = Colors.grey[300]!..strokeWidth = 1;
    for (int i = -20; i <= 20; i++) {
      canvas.drawLine(
        Offset(center.dx + i * scale, 0),
        Offset(center.dx + i * scale, size.height),
        gridPaint,
      );
      canvas.drawLine(
        Offset(0, center.dy + i * scale),
        Offset(size.width, center.dy + i * scale),
        gridPaint,
      );
    }

    // Draw path history
    if (pathHistory.length > 1) {
      final pathPaint = Paint()
        ..color = Colors.blue.withOpacity(0.3)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      final path = Path();
      path.moveTo(
        center.dx + pathHistory.first.x * scale,
        center.dy - pathHistory.first.y * scale,
      );

      for (var pos in pathHistory) {
        path.lineTo(
          center.dx + pos.x * scale,
          center.dy - pos.y * scale,
        );
      }

      canvas.drawPath(path, pathPaint);
    }

    // Draw particles
    final particlePaint = Paint()..color = Colors.blue.withOpacity(0.3);
    for (var particle in particles) {
      canvas.drawCircle(
        Offset(
          center.dx + particle.x * scale,
          center.dy - particle.y * scale,
        ),
        2,
        particlePaint,
      );
    }

    // Draw saved fingerprints
    for (var fp in fingerprints) {
      final fpPaint = Paint()..color = Colors.green;
      canvas.drawCircle(
        Offset(
          center.dx + fp.x * scale,
          center.dy - fp.y * scale,
        ),
        5,
        fpPaint,
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: fp.locationName,
          style: const TextStyle(color: Colors.black, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          center.dx + fp.x * scale + 8,
          center.dy - fp.y * scale - 5,
        ),
      );
    }

    // Draw current position
    final posPaint = Paint()..color = Colors.red;
    canvas.drawCircle(
      Offset(
        center.dx + currentX * scale,
        center.dy - currentY * scale,
      ),
      8,
      posPaint,
    );

    // Draw heading arrow
    final arrowPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final arrowLength = 20.0;
    final arrowEnd = Offset(
      center.dx + currentX * scale + arrowLength * cos(heading * pi / 180),
      center.dy - currentY * scale - arrowLength * sin(heading * pi / 180),
    );

    canvas.drawLine(
      Offset(center.dx + currentX * scale, center.dy - currentY * scale),
      arrowEnd,
      arrowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}