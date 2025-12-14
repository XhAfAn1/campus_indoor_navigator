import 'package:campus_indoor_navigator/backend/firebase_options.dart';
import 'package:campus_indoor_navigator/wrapper.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'API KEY.dart';
import 'Location with sensor test/test claude.dart';
import 'MyHomePage.dart';
import 'Elevation test/altitude.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform
  );
  MapboxOptions.setAccessToken("${API_KEY.MAP_BOX_API}");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Campus Navigator',
      theme: ThemeData(
      ),
      home: Wrapper(),
    );
  }
}