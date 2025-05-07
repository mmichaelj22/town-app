// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// // Define notification types
// enum NotificationType {
//   message,
//   friendRequest,
// }

// class NotificationService {
//   static final NotificationService _instance = NotificationService._internal();
//   factory NotificationService() => _instance;

//   NotificationService._internal();

//   // Firebase Cloud Messaging
//   final FirebaseMessaging _fcm = FirebaseMessaging.instance;

//   // Flutter Local Notifications Plugin
//   final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
//       FlutterLocalNotificationsPlugin();

//   // Stream for notification tap events
//   final StreamController<Map<String, dynamic>> _selectNotificationController =
//       StreamController<Map<String, dynamic>>.broadcast();
//   Stream<Map<String, dynamic>> get selectNotificationStream =>
//       _selectNotificationController.stream;

//   // Current user ID
//   String? _currentUserId;

//   // Topic subscriptions
//   final Set<String> _subscribedTopics = {};

//   // Method to initialize notification services
//   Future<void> initialize() async {
//     // Get current user
//     final currentUser = FirebaseAuth.instance.currentUser;
//     if (currentUser != null) {
//       _currentUserId = currentUser.uid;
//     }

//     // Request notification permissions on iOS
//     if (Platform.isIOS) {
//       await _fcm.requestPermission(
//         alert: true,
//         badge: true,
//         sound: true,
//       );
//     }

//     // Configure FCM foreground handler
//     FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

//     // Configure FCM background handlers
//     FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
//     FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

//     // Initialize local notifications
//     await _initializeLocalNotifications();

//     // Set up topic subscriptions
//     if (_currentUserId != null) {
//       // Subscribe to user-specific topic
//       await _fcm.subscribeToTopic('user_${_currentUserId}');
//       _subscribedTopics.add('user_${_currentUserId}');

//       // Store FCM token in Firestore
//       await _saveFcmToken();
//     }
//   }

//   // Initialize local notifications plugin
//   Future<void> _initializeLocalNotifications() async {
//     const AndroidInitializationSettings androidSettings =
//         AndroidInitializationSettings('@mipmap/ic_launcher');

//     final DarwinInitializationSettings iOSSettings =
//         DarwinInitializationSettings(
//       requestSoundPermission: false,
//       requestBadgePermission: false,
//       requestAlertPermission: false,
//       onDidReceiveLocalNotification: _onDidReceiveLocalNotification,
//     );

//     final InitializationSettings initSettings = InitializationSettings(
//       android: androidSettings,
//       iOS: iOSSettings,
//     );

//     await _flutterLocalNotificationsPlugin.initialize(
//       initSettings,
//       onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
//     );
//   }

//   // Handle foreground messages
//   Future<void> _handleForegroundMessage(RemoteMessage message) async {
//     print('Foreground message received: ${message.messageId}');

//     // Extract notification data
//     final data = message.data;
//     final notification = message.notification;

//     // Update badge count
//     if (Platform.isIOS && data.containsKey('badge')) {
//       try {
//         final badgeCount = int.parse(data['badge'] ?? '0');
//         // Skip setting badge number as it's not supported in this version
//         print('Badge count would be set to: $badgeCount');
//       } catch (e) {
//         print('Error processing badge count: $e');
//       }
//     }

//     // Show local notification
//     if (notification != null) {
//       await _showLocalNotification(
//         title: notification.title ?? 'New Notification',
//         body: notification.body ?? '',
//         payload: jsonEncode(data),
//       );
//     }
//   }

//   // Show a local notification
//   Future<void> _showLocalNotification({
//     required String title,
//     required String body,
//     required String payload,
//   }) async {
//     const AndroidNotificationDetails androidDetails =
//         AndroidNotificationDetails(
//       'town_notifications',
//       'Town Notifications',
//       channelDescription: 'Notifications from Town app',
//       importance: Importance.high,
//       priority: Priority.high,
//       showWhen: true,
//     );

//     const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
//       presentAlert: true,
//       presentBadge: true,
//       presentSound: true,
//     );

//     const NotificationDetails notificationDetails = NotificationDetails(
//       android: androidDetails,
//       iOS: iOSDetails,
//     );

//     await _flutterLocalNotificationsPlugin.show(
//       DateTime.now().millisecondsSinceEpoch ~/ 1000,
//       title,
//       body,
//       notificationDetails,
//       payload: payload,
//     );
//   }

//   // For older iOS versions
//   void _onDidReceiveLocalNotification(
//     int id,
//     String? title,
//     String? body,
//     String? payload,
//   ) {
//     if (payload != null) {
//       try {
//         final Map<String, dynamic> data = jsonDecode(payload);
//         _selectNotificationController.add(data);
//       } catch (e) {
//         print('Error parsing notification payload: $e');
//       }
//     }
//   }

//   // Handle notification taps
//   void _onDidReceiveNotificationResponse(NotificationResponse response) {
//     if (response.payload != null) {
//       try {
//         final Map<String, dynamic> data = jsonDecode(response.payload!);
//         _selectNotificationController.add(data);
//       } catch (e) {
//         print('Error parsing notification payload: $e');
//       }
//     }
//   }

//   // Handle notification opened from terminated state
//   Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
//     print('App opened from notification: ${message.messageId}');

//     final data = message.data;
//     if (data.isNotEmpty) {
//       _selectNotificationController.add(data);
//     }
//   }

//   // Store FCM token in Firestore
//   Future<void> _saveFcmToken() async {
//     if (_currentUserId == null) return;

//     try {
//       final token = await _fcm.getToken();
//       if (token != null) {
//         await FirebaseFirestore.instance
//             .collection('users')
//             .doc(_currentUserId)
//             .update({
//           'fcmTokens': FieldValue.arrayUnion([token]),
//           'lastTokenUpdate': FieldValue.serverTimestamp(),
//         });

//         // Save token to shared preferences for comparison later
//         final prefs = await SharedPreferences.getInstance();
//         prefs.setString('fcm_token', token);
//       }
//     } catch (e) {
//       print('Error saving FCM token: $e');
//     }
//   }

//   // Refresh token if needed
//   Future<void> refreshToken() async {
//     if (_currentUserId == null) return;

//     try {
//       final token = await _fcm.getToken();
//       final prefs = await SharedPreferences.getInstance();
//       final savedToken = prefs.getString('fcm_token');

//       if (token != null && token != savedToken) {
//         await FirebaseFirestore.instance
//             .collection('users')
//             .doc(_currentUserId)
//             .update({
//           'fcmTokens': FieldValue.arrayUnion([token]),
//           'lastTokenUpdate': FieldValue.serverTimestamp(),
//         });

//         prefs.setString('fcm_token', token);
//       }
//     } catch (e) {
//       print('Error refreshing FCM token: $e');
//     }
//   }

//   // Update badge count on the app icon
//   Future<void> updateBadgeCount(int count) async {
//     if (Platform.isIOS) {
//       try {
//         // Skip setting badge number as it's not supported in this version
//         print('Badge count would be set to: $count');
//       } catch (e) {
//         print('Error updating badge count: $e');
//       }
//     }
//   }

//   // Clear all notifications
//   Future<void> clearNotifications() async {
//     await _flutterLocalNotificationsPlugin.cancelAll();
//     await updateBadgeCount(0);
//   }

//   // Send friend request notification
//   Future<void> sendFriendRequestNotification({
//     required String toUserId,
//     required String fromUserId,
//     required String fromUserName,
//   }) async {
//     try {
//       // Get recipient's FCM tokens
//       final userDoc = await FirebaseFirestore.instance
//           .collection('users')
//           .doc(toUserId)
//           .get();

//       if (!userDoc.exists) return;

//       final userData = userDoc.data();
//       if (userData == null) return;

//       // Add notification record to Firestore
//       await FirebaseFirestore.instance
//           .collection('users')
//           .doc(toUserId)
//           .collection('notifications')
//           .add({
//         'type': 'friendRequest',
//         'fromUserId': fromUserId,
//         'fromUserName': fromUserName,
//         'timestamp': FieldValue.serverTimestamp(),
//         'read': false,
//       });

//       // Cloud Functions will handle sending the actual notification
//       // based on the notification record we just created
//     } catch (e) {
//       print('Error sending friend request notification: $e');
//     }
//   }

//   // Send message notification
//   Future<void> sendMessageNotification({
//     required String toUserId,
//     required String fromUserId,
//     required String fromUserName,
//     required String conversationId,
//     required String message,
//   }) async {
//     try {
//       // Add notification record to Firestore
//       await FirebaseFirestore.instance
//           .collection('users')
//           .doc(toUserId)
//           .collection('notifications')
//           .add({
//         'type': 'message',
//         'fromUserId': fromUserId,
//         'fromUserName': fromUserName,
//         'conversationId': conversationId,
//         'message': message,
//         'timestamp': FieldValue.serverTimestamp(),
//         'read': false,
//       });

//       // Cloud Functions will handle sending the actual notification
//       // based on the notification record we just created
//     } catch (e) {
//       print('Error sending message notification: $e');
//     }
//   }

//   // Check and update user's notification count
//   Future<int> getUnreadNotificationsCount() async {
//     if (_currentUserId == null) return 0;

//     try {
//       final querySnapshot = await FirebaseFirestore.instance
//           .collection('users')
//           .doc(_currentUserId)
//           .collection('notifications')
//           .where('read', isEqualTo: false)
//           .get();

//       final count = querySnapshot.docs.length;
//       await updateBadgeCount(count);
//       return count;
//     } catch (e) {
//       print('Error getting unread notifications: $e');
//       return 0;
//     }
//   }

//   // Mark notification as read
//   Future<void> markNotificationAsRead(String notificationId) async {
//     if (_currentUserId == null) return;

//     try {
//       await FirebaseFirestore.instance
//           .collection('users')
//           .doc(_currentUserId)
//           .collection('notifications')
//           .doc(notificationId)
//           .update({
//         'read': true,
//       });

//       // Update badge count
//       await getUnreadNotificationsCount();
//     } catch (e) {
//       print('Error marking notification as read: $e');
//     }
//   }

//   // Clean up resources
//   void dispose() {
//     _selectNotificationController.close();
//   }
// }

// // Handle background messages (must be top-level function)
// @pragma('vm:entry-point')
// Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   // Ensure Firebase is initialized
//   // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

//   print('Background message received: ${message.messageId}');

//   // No need to show a notification here as FCM will handle displaying
//   // the notification when the app is in the background
// }
