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
  bool _isDisposed = false;

  // Initialize with user ID
  Future<void> initialize(String userId) async {
    _currentUserId = userId;
    _isDisposed = false; // Reset the disposed flag on initialization
    await _loadLastReadTimestamps();
    await ensureConversationsHaveLastActivity();
    _startListening();
  }

  // Dispose resources
  void dispose() {
    _isDisposed = true;
    _messagesSubscription?.cancel();
    if (!_unreadCountController.isClosed) {
      _unreadCountController.close();
    }
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

  // Add this method to ensure lastActivity field exists
  Future<void> ensureConversationsHaveLastActivity() async {
    if (_currentUserId == null) return;

    try {
      // Get all conversations user is part of
      final conversations = await FirebaseFirestore.instance
          .collection('conversations')
          .where('participants', arrayContains: _currentUserId)
          .get();

      for (var conversation in conversations.docs) {
        final conversationData = conversation.data();

        // Check if lastActivity is missing
        if (!conversationData.containsKey('lastActivity')) {
          print(
              "Adding missing lastActivity to conversation: ${conversation.id}");

          // Get the most recent message to set as lastActivity
          final messagesQuery = await FirebaseFirestore.instance
              .collection('conversations')
              .doc(conversation.id)
              .collection('messages')
              .orderBy('timestamp', descending: true)
              .limit(1)
              .get();

          if (messagesQuery.docs.isNotEmpty) {
            final lastMessage = messagesQuery.docs.first;
            final lastTimestamp = lastMessage['timestamp'] as Timestamp?;

            if (lastTimestamp != null) {
              // Update with the timestamp of the last message
              await FirebaseFirestore.instance
                  .collection('conversations')
                  .doc(conversation.id)
                  .update({
                'lastActivity': lastTimestamp,
              });
            } else {
              // No message timestamp, use current time
              await FirebaseFirestore.instance
                  .collection('conversations')
                  .doc(conversation.id)
                  .update({
                'lastActivity': FieldValue.serverTimestamp(),
              });
            }
          } else {
            // No messages, use createdAt or current time
            if (conversationData.containsKey('createdAt')) {
              await FirebaseFirestore.instance
                  .collection('conversations')
                  .doc(conversation.id)
                  .update({
                'lastActivity': conversationData['createdAt'],
              });
            } else {
              await FirebaseFirestore.instance
                  .collection('conversations')
                  .doc(conversation.id)
                  .update({
                'lastActivity': FieldValue.serverTimestamp(),
              });
            }
          }
        }
      }
    } catch (e) {
      print("Error ensuring lastActivity exists: $e");
    }
  }

  // Count unread messages
  Future<void> _countUnreadMessages() async {
    if (_currentUserId == null || _isDisposed) return;

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
        int unreadCount = 0;
        try {
          // Try with compound query first (requires index)
          final messagesQuery = await FirebaseFirestore.instance
              .collection('conversations')
              .doc(conversationId)
              .collection('messages')
              .where('timestamp', isGreaterThan: lastReadTimestamp)
              .where('senderId', isNotEqualTo: _currentUserId)
              .get();

          unreadCount = messagesQuery.docs.length;
        } catch (e) {
          // Fallback to manual filtering if index not ready
          print(
              "Using fallback count method for conversation $conversationId: $e");

          final allMessages = await FirebaseFirestore.instance
              .collection('conversations')
              .doc(conversationId)
              .collection('messages')
              .get();

          unreadCount = allMessages.docs.where((doc) {
            final timestamp = doc['timestamp'] as Timestamp?;
            final senderId = doc['senderId'] as String?;

            return timestamp != null &&
                timestamp.compareTo(lastReadTimestamp) > 0 &&
                senderId != null &&
                senderId != _currentUserId;
          }).length;
        }

        totalUnread += unreadCount;
      }

      // Emit new count if controller is still open
      if (!_isDisposed && !_unreadCountController.isClosed) {
        _unreadCountController.add(totalUnread);
      }
    } catch (e) {
      print("Error counting unread messages: $e");
    }
  }

  // Get current unread count
  Future<int> getUnreadCount() async {
    if (_currentUserId == null) return 0;

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
        int unreadCount = 0;
        try {
          // Try with compound query first (requires index)
          final messagesQuery = await FirebaseFirestore.instance
              .collection('conversations')
              .doc(conversationId)
              .collection('messages')
              .where('timestamp', isGreaterThan: lastReadTimestamp)
              .where('senderId', isNotEqualTo: _currentUserId)
              .get();

          unreadCount = messagesQuery.docs.length;
        } catch (e) {
          // Fallback to manual filtering if index not ready
          print(
              "Using fallback count method for conversation $conversationId: $e");

          final allMessages = await FirebaseFirestore.instance
              .collection('conversations')
              .doc(conversationId)
              .collection('messages')
              .get();

          unreadCount = allMessages.docs.where((doc) {
            final timestamp = doc['timestamp'] as Timestamp?;
            final senderId = doc['senderId'] as String?;

            return timestamp != null &&
                timestamp.compareTo(lastReadTimestamp) > 0 &&
                senderId != null &&
                senderId != _currentUserId;
          }).length;
        }

        totalUnread += unreadCount;
      }
    } catch (e) {
      print("Error getting unread count: $e");
    }

    return totalUnread;
  }
}
