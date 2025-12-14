// import 'dart:async';
// import 'dart:math';
// import 'package:flutter/material.dart';
//
// class FloorHeightPage extends StatefulWidget {
//   @override
//   _FloorHeightPageState createState() => _FloorHeightPageState();
// }
//
// class _FloorHeightPageState extends State<FloorHeightPage> {
//   double? basePressure;
//   double currentPressure = 0;
//   double altitude = 0;
//   int floor = 0;
//   StreamSubscription? sub;
//
//   static const metersPerFloor = 3.2;
//
//   @override
//   void initState() {
//     super.initState();
//
//     sub = AltitudeSensors.pressureStream.listen((pressure) {
//       setState(() {
//         currentPressure = pressure;
//
//         basePressure ??= currentPressure;
//
//         altitude = calculateAltitude(basePressure!, currentPressure);
//         floor = (altitude / metersPerFloor).round();
//       });
//     });
//   }
//
//   double calculateAltitude(double p0, double p) {
//     return (44330 * (1 - pow(p / p0, 1 / 5.255))).toDouble();
//   }
//
//   @override
//   void dispose() {
//     sub?.cancel();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text("Floor + Height Detector")),
//       body: Padding(
//         padding: const EdgeInsets.all(20),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text("Current Pressure: ${currentPressure.toStringAsFixed(2)} hPa",
//                 style: TextStyle(fontSize: 20)),
//             SizedBox(height: 20),
//             Text("Height Above Ground: ${altitude.toStringAsFixed(2)} m",
//                 style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
//             SizedBox(height: 20),
//             Text("Estimated Floor: $floor",
//                 style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
//             SizedBox(height: 30),
//             Text("Tip: Stand on ground floor to calibrate.",
//                 style: TextStyle(fontSize: 16, color: Colors.grey)),
//           ],
//         ),
//       ),
//     );
//   }
// }
