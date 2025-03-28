import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';
import 'messages_screen.dart';
import 'friends_screen.dart';
import 'settings_screen.dart';
import 'new_private_chat_dialog.dart';
import 'chat_screen.dart'; // Added import
import 'profile_screen.dart';
import '../theme/app_theme.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 2;
  String? userId;
  double detectionRadius = 100.0;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadRadius();
  }

  Future<void> _loadUser() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        userId = user.uid;
      });
      await _updateUserLocation(user.uid);
    }
  }

  Future<void> _loadRadius() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      detectionRadius = prefs.getDouble('detectionRadius') ?? 100.0;
    });
  }

  Future<void> _updateUserLocation(String uid) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.whileInUse &&
            permission != LocationPermission.always) return;
      }

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print("Error updating location: $e");
    }
  }

  void _joinConversation(String title, String type) {
    if (userId == null) return;
    try {
      FirebaseFirestore.instance.collection('conversations').doc(title).set({
        'title': title,
        'type': type,
        'participants': FieldValue.arrayUnion([userId!]),
      }, SetOptions(merge: true));
    } catch (e) {
      print("Error joining conversation: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (userId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final String uid = userId!;

    // Find this section in your main_screen.dart file
    final List<Widget> screens = [
      FriendsScreen(
        userId: uid,
        detectionRadius: detectionRadius,
        onSelectFriend: (friend) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NewPrivateChatDialog(
                userId: uid,
                onStartChat: (recipient, topic) {
                  _joinConversation(topic, 'Private');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        userId: uid,
                        chatTitle: topic,
                        chatType: 'Private',
                      ),
                    ),
                  );
                },
                selectedFriend: friend,
              ),
            ),
          );
        },
      ),
      MessagesScreen(userId: uid),
      HomeScreen(
        userId: uid,
        onJoinConversation: _joinConversation,
        detectionRadius: detectionRadius, // Add this parameter
      ),
      const ProfileScreen(),
      SettingsScreen(
        userId: uid, // Add this line to pass the userId
        detectionRadius: detectionRadius,
        onRadiusChanged: (value) async {
          setState(() {
            detectionRadius = value;
          });
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setDouble('detectionRadius', value);
        },
      ),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppTheme.navBarColor,
        selectedItemColor: AppTheme.navBarItemColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Friends'),
          BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Messages'),
          BottomNavigationBarItem(icon: Icon(Icons.square), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings), label: 'Settings'),
        ],
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
