// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:flutter_barometer/flutter_barometer.dart';
//
// class BarometerScreen extends StatefulWidget {
//   const BarometerScreen({Key? key}) : super(key: key);
//
//   @override
//   State<BarometerScreen> createState() => _BarometerScreenState();
// }
//
// class _BarometerScreenState extends State<BarometerScreen> {
//   StreamSubscription<double>? _baroSub;
//
//   double _pressure = 0; // hPa
//   double? _basePressure;
//   double _deltaPressure = 0;
//   double _estimatedFloorChange = 0;
//
//   @override
//   void initState() {
//     super.initState();
//
//     _baroSub = FlutterBarometer.pressureStream.listen((pressure) {
//       _pressure = pressure;
//
//       _basePressure ??= _pressure;
//       _deltaPressure = _basePressure! - _pressure;
//
//       // Approx: ~0.12 hPa per floor (very rough)
//       _estimatedFloorChange = _deltaPressure / 0.12;
//
//       setState(() {});
//     });
//   }
//
//   @override
//   void dispose() {
//     _baroSub?.cancel();
//     super.dispose();
//   }
//
//   void _resetBase() {
//     setState(() {
//       _basePressure = _pressure;
//       _deltaPressure = 0;
//       _estimatedFloorChange = 0;
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Barometer / Floor Change')),
//       body: Padding(
//         padding: const EdgeInsets.all(12),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               'Pressure (hPa)',
//               style: TextStyle(fontWeight: FontWeight.bold),
//             ),
//             Text('Current: ${_pressure.toStringAsFixed(3)}'),
//             Text('Base: ${_basePressure?.toStringAsFixed(3) ?? '---'}'),
//             const SizedBox(height: 8),
//             Text('ΔPressure: ${_deltaPressure.toStringAsFixed(3)} hPa'),
//             Text(
//               'Estimated floor change: ${_estimatedFloorChange.toStringAsFixed(2)}',
//               style: const TextStyle(
//                 fontSize: 18,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             const SizedBox(height: 12),
//             ElevatedButton(
//               onPressed: _resetBase,
//               child: const Text('Set current as base floor'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
