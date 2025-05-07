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
import 'chat_screen.dart';
import 'profile_screen.dart';
import '../theme/app_theme.dart';
import '../services/message_tracker.dart';
import '../widgets/notification_badge.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 2;
  String? userId;
  double detectionRadius = 100.0;
  final MessageTracker _messageTracker = MessageTracker();
  int _unreadMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadRadius();
  }

  @override
  void dispose() {
    _messageTracker.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        userId = user.uid;
      });

      // Initialize message tracker
      await _messageTracker.initialize(user.uid);

      // Listen for unread message count updates
      _messageTracker.unreadCountStream.listen((count) {
        setState(() {
          _unreadMessageCount = count;
        });
      });

      // Get initial unread count
      final initialCount = await _messageTracker.getUnreadCount();
      setState(() {
        _unreadMessageCount = initialCount;
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

  // Method to mark messages as read when visiting Messages tab
  void _markMessagesAsReadIfNeeded(int index) {
    // If navigating to Messages tab (index 1)
    if (index == 1) {
      // We'll mark individual conversations as read in the Messages screen
      // This is just a placeholder in case we want to add any logic here
    }
  }

  @override
  Widget build(BuildContext context) {
    if (userId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final String uid = userId!;

// Fix for the main_screen.dart file

// In the build method of _MainScreenState class, update the screens list
// where the MessagesScreen is created (should be around line 170):

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
      MessagesScreen(
        userId: uid, // Make sure this line exists
        messageTracker: _messageTracker,
      ),
      HomeScreen(
        userId: uid,
        onJoinConversation: _joinConversation,
        detectionRadius: detectionRadius,
      ),
      const ProfileScreen(),
      SettingsScreen(
        detectionRadius: detectionRadius,
        onRadiusChanged: (value) async {
          setState(() {
            detectionRadius = value;
          });
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setDouble('detectionRadius', value);
        },
        userId: uid,
      ),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppTheme.navBarColor, // Keep the bar white
        selectedItemColor:
            _getSelectedIconColor(), // This will change based on the selected tab
        unselectedItemColor: Colors.grey,
        items: [
          const BottomNavigationBarItem(
              icon: Icon(Icons.people), label: 'Friends'),

          // Messages tab with notification badge
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.message),
                if (_unreadMessageCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: NotificationBadge(
                      count: _unreadMessageCount,
                      backgroundColor: AppTheme.coral,
                    ),
                  ),
              ],
            ),
            label: 'Messages',
          ),

          const BottomNavigationBarItem(
              icon: Icon(Icons.square), label: 'Home'),
          const BottomNavigationBarItem(
              icon: Icon(Icons.person), label: 'Profile'),
          const BottomNavigationBarItem(
              icon: Icon(Icons.settings), label: 'Settings'),
        ],
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          _markMessagesAsReadIfNeeded(index);
        },
      ),
    );
  }

  Color _getSelectedIconColor() {
    switch (_currentIndex) {
      case 0: // Friends
        return AppTheme.blue;
      case 1: // Messages
        return AppTheme.green;
      case 2: // Home
        return Colors.purple;
      case 3: // Profile
        return AppTheme.coral;
      case 4: // Settings
        return AppTheme.orange;
      default:
        return AppTheme.blue;
    }
  }
}
