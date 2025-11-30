import 'package:campus_indoor_navigator/backend/Authentication.dart';
import 'package:flutter/material.dart';

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Center(
            child: Text("HI"),
          ),
          ElevatedButton(onPressed: (){Authentication().signout(context);}, child: Text("Sign out"))
        ],
      ),
    );
  }
}
