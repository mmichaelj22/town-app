import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:camera/camera.dart';
import 'firebase_options.dart';
import 'screens/register_screen.dart';
import 'screens/sign_in_screen.dart'; // Update import
import 'screens/main_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

List<CameraDescription> cameras = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    await FirebaseAuth.instance.signOut();
    print("Firebase initialized successfully");
    cameras = await availableCameras();
  } catch (e) {
    print("Error initializing Firebase: $e");
  }
  runApp(const TownApp());
}

class TownApp extends StatelessWidget {
  const TownApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Town',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData) {
          return RegisterScreen(cameras: cameras);
        }
        return const MainScreen();
      },
    );
  }
}
