import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart'; // Add this import
import 'firebase_options.dart';
import 'screens/register_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/main_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

List<CameraDescription> cameras = [];

// Add this function
Future<bool> requestCameraPermission() async {
  try {
    PermissionStatus status = await Permission.camera.status;
    if (status.isDenied) {
      status = await Permission.camera.request();
    }
    return status.isGranted;
  } catch (e) {
    print("Error requesting camera permission: $e");
    return false;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Request camera permission and initialize cameras
  bool hasPermission = await requestCameraPermission();
  if (hasPermission) {
    try {
      print("Camera permission granted, initializing cameras...");
      cameras = await availableCameras();
      print("Found ${cameras.length} cameras");
    } catch (e) {
      print("Error initializing cameras: $e");
      cameras = [];
    }
  } else {
    print("Camera permission denied");
    cameras = [];
  }

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    // Remove the sign out line
    // await FirebaseAuth.instance.signOut();
    print("Firebase initialized successfully");
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
        // Add debug info
        print(
            "Auth state: ${snapshot.connectionState}, hasData: ${snapshot.hasData}, user: ${snapshot.data?.uid}");

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
