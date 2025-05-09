import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'screens/register_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/main_screen.dart';
import 'screens/intro_animation.dart';
import 'screens/profile_viewer_screen.dart';
import 'screens/report_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'theme/app_theme.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:google_maps_flutter/google_maps_flutter.dart';

const bool kResetIntroOnRestart = false; // Set to false for production

List<CameraDescription> cameras = [];

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

  // Initialize Google Maps Flutter
  // if (defaultTargetPlatform == TargetPlatform.iOS) {
  //   await GoogleMapsPlatform.instance.ensureInitialized();
  // }

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
      theme: AppTheme.theme,
      initialRoute: '/',
      routes: {
        '/': (context) => AnimationGate(),
        '/signin': (context) => SignInScreen(cameras: cameras),
        '/register': (context) => RegisterScreen(cameras: cameras),
        '/main': (context) => MainScreen(),
        // Add new routes here
        '/report': (context) {
          // Get arguments passed to this route
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>?;
          if (args == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Error')),
              body: const Center(child: Text('Missing required parameters')),
            );
          }

          // The route uses the original parameter names from the ReportScreen class
          return ReportScreen(
            currentUserId: args['currentUserId'] as String,
            conversationId: args['conversationId'] as String? ?? '',
            participants: args['participants'] as List<String>? ?? [],
          );
        },
        '/profile': (context) {
          // Get arguments passed to this route
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>?;
          if (args == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Error')),
              body: const Center(child: Text('Missing required parameters')),
            );
          }

          return ProfileViewerScreen(
            currentUserId: args['currentUserId'] as String,
            userId: args['userId'] as String,
            userName: args['userName'] as String,
          );
        },
      },
      debugShowCheckedModeBanner: false,
      // You can also add onGenerateRoute for dynamic route handling
      onGenerateRoute: (settings) {
        // Handle any routes that aren't explicitly defined
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: Center(child: Text('Route ${settings.name} not found')),
          ),
        );
      },
    );
  }
}

class AnimationGate extends StatefulWidget {
  @override
  _AnimationGateState createState() => _AnimationGateState();
}

class _AnimationGateState extends State<AnimationGate> {
  bool _loading = true;
  bool _showIntro = true;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    // print("Checking animation status...");

    User? currentUser = FirebaseAuth.instance.currentUser;
    // print("Current user: ${currentUser?.uid ?? 'null'}");

    final prefs = await SharedPreferences.getInstance();
    final hasSeenIntro = prefs.getBool('intro_seen') ?? false;
    // print("Has seen intro: $hasSeenIntro");

    setState(() {
      // Show intro if user is not signed in and hasn't seen it before
      _showIntro = !hasSeenIntro && currentUser == null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // If intro should be shown
    if (_showIntro) {
      return IntroAnimation(
        nextScreen: AuthGate(),
      );
    }

    // Otherwise go straight to auth gate
    return AuthGate();
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

        // If no user is signed in, go to sign-in screen instead of register
        if (!snapshot.hasData) {
          return SignInScreen(cameras: cameras);
        }

        return const MainScreen();
      },
    );
  }
}
