import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'MyHomePage.dart';
import 'authentication/login.dart';

class Wrapper extends StatefulWidget {
  const Wrapper({super.key});

  @override
  State<Wrapper> createState() => _WrapperState();
}

class _WrapperState extends State<Wrapper> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold();
        }

        if (userSnapshot.hasData && userSnapshot.data != null) {
          final userId = userSnapshot.data!.uid;

          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection("Users").doc(userId).get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return  Scaffold(
                  backgroundColor: Colors.white,
                  body: Center(
                    child: Container(
                      height: 80,
                      width: 80,
                      decoration: BoxDecoration(
                        // image: DecorationImage(
                        //   image: AssetImage('assets/rlogo.png'),
                        //   fit: BoxFit.cover,
                        // ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                // return const Scaffold(
                //   backgroundColor: Colors.white,
                //   body: Center(child: Text("User not found.")),
                // );
                return login();
              }

              final data = snapshot.data!.data() as Map<String, dynamic>;
              final isAdmin = data['admin'] ?? false;

              if (isAdmin) {
                return const MyHomePage();
              }
              else

                return MyHomePage();
            },
          );
        } else {
          return const login();
        }
      },
    );
  }
}
