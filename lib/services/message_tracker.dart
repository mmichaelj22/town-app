// lib/services/message_tracker.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MessageTracker {
  static final MessageTracker _instance = MessageTracker._internal();

  factory MessageTracker() => _instance;

  MessageTracker._internal();

  final StreamController<int> _unreadCountController =
      StreamController<int>.broadcast();
  Stream<int> get unreadCountStream => _unreadCountController.stream;

  String? _currentUserId;
  StreamSubscription? _messagesSubscription;
  Map<String, Timestamp> _lastReadTimestamps = {};

  // Initialize with user ID
  Future<void> initialize(String userId) async {
    _currentUserId = userId;
    await _loadLastReadTimestamps();
    _startListening();
  }

  // Dispose resources
  void dispose() {
    _messagesSubscription?.cancel();
    _unreadCountController.close();
  }

  // Load last read timestamps from preferences
  Future<void> _loadLastReadTimestamps() async {
    if (_currentUserId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> timestamps = {};

    // Get all conversations from Firestore
    final conversations = await FirebaseFirestore.instance
        .collection('conversations')
        .where('participants', arrayContains: _currentUserId)
        .get();

    for (var conversation in conversations.docs) {
      final conversationId = conversation.id;
      final timestampStr =
          prefs.getString('last_read_${_currentUserId}_$conversationId');

      if (timestampStr != null) {
        final parts = timestampStr.split('_');
        if (parts.length == 2) {
          final seconds = int.parse(parts[0]);
          final nanoseconds = int.parse(parts[1]);
          _lastReadTimestamps[conversationId] = Timestamp(seconds, nanoseconds);
        }
      }
    }
  }

  // Save last read timestamp for a conversation
  Future<void> markConversationAsRead(String conversationId) async {
    if (_currentUserId == null) return;

    // Update in-memory cache
    _lastReadTimestamps[conversationId] = Timestamp.now();

    // Save to preferences
    final prefs = await SharedPreferences.getInstance();
    final timestamp = _lastReadTimestamps[conversationId]!;
    prefs.setString('last_read_${_currentUserId}_$conversationId',
        '${timestamp.seconds}_${timestamp.nanoseconds}');

    // Update unread count
    _countUnreadMessages();
  }

  // Start listening to new messages
  void _startListening() {
    if (_currentUserId == null) return;

    // Cancel existing subscription if any
    _messagesSubscription?.cancel();

    // Get all conversations user is part of
    _messagesSubscription = FirebaseFirestore.instance
        .collection('conversations')
        .where('participants', arrayContains: _currentUserId)
        .snapshots()
        .listen((snapshot) {
      _countUnreadMessages();
    });
  }

  // Count unread messages
  Future<void> _countUnreadMessages() async {
    if (_currentUserId == null) return;

    int totalUnread = 0;

    try {
      // Get all conversations user is part of
      final conversations = await FirebaseFirestore.instance
          .collection('conversations')
          .where('participants', arrayContains: _currentUserId)
          .get();

      for (var conversation in conversations.docs) {
        final conversationId = conversation.id;
        final lastReadTimestamp =
            _lastReadTimestamps[conversationId] ?? Timestamp(0, 0);

        // Get unread messages count
        final messagesQuery = await FirebaseFirestore.instance
            .collection('conversations')
            .doc(conversationId)
            .collection('messages')
            .where('timestamp', isGreaterThan: lastReadTimestamp)
            .where('senderId', isNotEqualTo: _currentUserId)
            .get();

        totalUnread += messagesQuery.docs.length;
      }

      // Emit new count
      _unreadCountController.add(totalUnread);
    } catch (e) {
      print('Error counting unread messages: $e');
    }
  }

  // Get current unread count
  Future<int> getUnreadCount() async {
    if (_currentUserId == null) return 0;

    await _countUnreadMessages();

    int totalUnread = 0;

    try {
      // Get all conversations user is part of
      final conversations = await FirebaseFirestore.instance
          .collection('conversations')
          .where('participants', arrayContains: _currentUserId)
          .get();

      for (var conversation in conversations.docs) {
        final conversationId = conversation.id;
        final lastReadTimestamp =
            _lastReadTimestamps[conversationId] ?? Timestamp(0, 0);

        // Get unread messages count
        final messagesQuery = await FirebaseFirestore.instance
            .collection('conversations')
            .doc(conversationId)
            .collection('messages')
            .where('timestamp', isGreaterThan: lastReadTimestamp)
            .where('senderId', isNotEqualTo: _currentUserId)
            .get();

        totalUnread += messagesQuery.docs.length;
      }
    } catch (e) {
      print('Error getting unread count: $e');
    }

    return totalUnread;
  }
}
