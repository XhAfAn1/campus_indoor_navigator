import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:permission_handler/permission_handler.dart';

class WifiScanScreen extends StatefulWidget {
  const WifiScanScreen({Key? key}) : super(key: key);

  @override
  State<WifiScanScreen> createState() => _WifiScanScreenState();
}

class _WifiScanScreenState extends State<WifiScanScreen> {
  List<WiFiAccessPoint> _results = [];
  Timer? _timer;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _initScan();
  }

  Future<void> _initScan() async {
    final status = await Permission.locationWhenInUse.request();
    if (!status.isGranted) {
      return;
    }

    final can = await WiFiScan.instance.canStartScan(askPermissions: false);
    if (can != CanStartScan.yes) return;

    _startPeriodicScan();
  }

  void _startPeriodicScan() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _doScan());
  }

  Future<void> _doScan() async {
    setState(() => _scanning = true);
    await WiFiScan.instance.startScan();
    final results = await WiFiScan.instance.getScannedResults();
    results.sort((a, b) => b.level.compareTo(a.level));
    setState(() {
      _results = results;
      _scanning = false;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wi-Fi Scan / Fingerprint')),
      body: Column(
        children: [
          if (_scanning)
            const LinearProgressIndicator(
              minHeight: 2,
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final ap = _results[index];
                return ListTile(
                  title: Text(ap.ssid.isNotEmpty ? ap.ssid : '<hidden>'),
                  subtitle: Text('BSSID: ${ap.bssid}'),
                  trailing: Text('${ap.level} dBm'),
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              'Test: Stand still with two phones and compare RSSI list & values. Expect ±5 dBm difference typically.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
