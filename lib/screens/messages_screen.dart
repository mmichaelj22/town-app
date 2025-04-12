import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import '../utils/conversation_manager.dart';
import '../widgets/custom_header.dart';
import '../services/message_tracker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class MessagesScreen extends StatefulWidget {
  final String userId;
  final MessageTracker messageTracker;

  const MessagesScreen({
    super.key,
    required this.userId,
    required this.messageTracker,
  });

  @override
  _MessagesScreenState createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  // Add these properties here:
  StreamSubscription? _conversationsSubscription;
  List<QueryDocumentSnapshot> _conversations = [];
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, int> _unreadCounts = {};

  // Then add the methods:
  @override
  void initState() {
    super.initState();
    _setupFirestoreListener();
  }

  void _setupFirestoreListener() {
    // Cancel existing subscription
    _conversationsSubscription?.cancel();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Set up listener with error handling
    _conversationsSubscription = FirebaseFirestore.instance
        .collection('conversations')
        .where('participants', arrayContains: widget.userId)
        .snapshots()
        .handleError((error) {
      print("Firestore error: $error");
      setState(() {
        _isLoading = false;
        _errorMessage = "Couldn't load messages: $error";
      });
    }).listen((snapshot) {
      _processConversationsSnapshot(snapshot);
    });
  }

  Future<void> _processConversationsSnapshot(QuerySnapshot snapshot) async {
    if (!mounted) return;

    try {
      // Filter conversations based on visibility rule
      final visibleConversations = snapshot.docs.where((doc) {
        return ConversationManager.shouldShowOnMessagesScreen(
          userId: widget.userId,
          conversation: doc,
        );
      }).toList();

      // Process unread counts efficiently
      await _updateUnreadCounts(visibleConversations);

      // Sort by most recent activity (with null safety)
      visibleConversations.sort((a, b) {
        // Extract timestamps safely
        final aTimestamp = _getLastActivityTimestamp(a);
        final bTimestamp = _getLastActivityTimestamp(b);

        if (aTimestamp == null && bTimestamp == null) return 0;
        if (aTimestamp == null) return 1; // Null timestamps at end
        if (bTimestamp == null) return -1;

        return bTimestamp.compareTo(aTimestamp);
      });

      if (mounted) {
        setState(() {
          _conversations = visibleConversations;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error processing conversations: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Error loading messages: $e";
        });
      }
    }
  }

  // Helper method to get timestamp safely
  Timestamp? _getLastActivityTimestamp(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>?;
      return data?['lastActivity'] as Timestamp?;
    } catch (e) {
      return null;
    }
  }

  // Efficiently batch process unread counts
  Future<void> _updateUnreadCounts(
      List<QueryDocumentSnapshot> conversations) async {
    final Map<String, int> counts = {};

    // Process in small batches to avoid UI jank
    for (int i = 0; i < conversations.length; i += 5) {
      final batch = conversations.skip(i).take(5);

      await Future.wait(batch.map((conversation) async {
        final conversationId = conversation.id;
        try {
          counts[conversationId] = await _getUnreadCount(conversationId);
        } catch (e) {
          print("Error counting unread for $conversationId: $e");
          counts[conversationId] = 0;
        }
      }));

      // Update state periodically to show progress
      if (mounted && i + 5 < conversations.length) {
        setState(() {
          _unreadCounts = Map.from(_unreadCounts)..addAll(counts);
        });
      }
    }

    if (mounted) {
      setState(() {
        _unreadCounts = counts;
      });
    }
  }

  @override
  void dispose() {
    _conversationsSubscription?.cancel();
    super.dispose();
  }

  Future<List<String>> _getFriends() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('friends')) {
          return List<String>.from(data['friends']);
        }
      }
      print("No friends data found for user $widget.userId");
      return [];
    } catch (e) {
      print("Error getting friends: $e");
      return [];
    }
  }

  void _createDummyConversation(BuildContext context) async {
    try {
      // Get user location for origin
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (!userDoc.exists) {
        throw Exception('User data not found');
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final userLat = userData['latitude'] as double? ?? 0.0;
      final userLon = userData['longitude'] as double? ?? 0.0;

      final String topic = "Test Conversation";
      final String type = "Private";

      // Create a test conversation with proper location information
      await ConversationManager.createConversation(
        title: topic,
        type: type,
        creatorId: widget.userId,
        initialParticipants: [widget.userId],
        latitude: userLat,
        longitude: userLon,
      );

      // Add a test message
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(topic)
          .collection('messages')
          .add({
        'text': 'This is a test message',
        'senderId': widget.userId,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': [],
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test conversation created')),
      );
    } catch (e) {
      print("Error creating test conversation: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<String> _getLastMessage(String conversationId) async {
    try {
      final messagesSnapshot = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (messagesSnapshot.docs.isNotEmpty) {
        return messagesSnapshot.docs.first['text'] ?? 'No message';
      }
    } catch (e) {
      print("Error getting last message: $e");
    }
    return 'No messages yet';
  }

  // Get unread message count for a conversation
  Future<int> _getUnreadCount(String conversationId) async {
    try {
      // Get the last read timestamp for this conversation
      final prefs = await SharedPreferences.getInstance();
      final timestampStr =
          prefs.getString('last_read_${widget.userId}_$conversationId');
      Timestamp lastReadTimestamp = Timestamp(0, 0);

      if (timestampStr != null) {
        final parts = timestampStr.split('_');
        if (parts.length == 2) {
          final seconds = int.parse(parts[0]);
          final nanoseconds = int.parse(parts[1]);
          lastReadTimestamp = Timestamp(seconds, nanoseconds);
        }
      }

      // Count messages newer than the last read timestamp and not from current user
      final querySnapshot = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .where('timestamp', isGreaterThan: lastReadTimestamp)
          .where('senderId', isNotEqualTo: widget.userId)
          .get();

      return querySnapshot.docs.length;
    } catch (e) {
      print("Error getting unread count: $e");
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Custom gradient header (keep this part)
          CustomHeader(
            title: 'Messages',
            subtitle: 'Your conversations',
            primaryColor: AppTheme.green,
            actions: [
              // Keep your existing actions
            ],
          ),

          // Error message if needed
          if (_errorMessage != null)
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.all(16),
                color: Colors.red.shade100,
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _setupFirestoreListener,
                      tooltip: 'Try again',
                    ),
                  ],
                ),
              ),
            ),

          // Loading, empty state, or message list
          _isLoading
              ? const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              : _conversations.isEmpty
                  ? SliverFillRemaining(
                      child: _buildEmptyState(),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return _buildConversationTile(_conversations[index]);
                        },
                        childCount: _conversations.length,
                      ),
                    ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.message_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No conversations yet',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start a new conversation from the home screen',
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

// Optimized conversation tile
  Widget _buildConversationTile(DocumentSnapshot conversation) {
    final String conversationId = conversation.id;
    final data = conversation.data() as Map<String, dynamic>?;
    if (data == null) return const SizedBox();

    // Extract data once
    final String title = data['title'] ?? 'Unnamed';
    final String type = data['type'] ?? 'Group';
    final List<dynamic> participants = data['participants'] ?? [];

    // Calculate color only once
    final int colorIndex = title.hashCode % AppTheme.squareColors.length;
    final Color tileColor = AppTheme.squareColors[colorIndex];

    // Get unread count from cached values
    final int unreadCount = _unreadCounts[conversationId] ?? 0;

    // Extract other participant for private chats
    String displayName = title;
    if (type == 'Private' && title.contains(' with ')) {
      displayName = title.split(' with ').last;
    }

    // Cache the check for private chat
    final bool isPrivateChat = type == 'Private';

    return Dismissible(
      key: Key(conversationId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        color: Colors.red,
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      onDismissed: (direction) {
        // Delete the conversation from Firestore
        FirebaseFirestore.instance
            .collection('conversations')
            .doc(conversationId)
            .delete()
            .then((_) {
          // Also delete any messages in the conversation subcollection
          FirebaseFirestore.instance
              .collection('conversations')
              .doc(conversationId)
              .collection('messages')
              .get()
              .then((snapshot) {
            for (DocumentSnapshot doc in snapshot.docs) {
              doc.reference.delete();
            }
          });

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Conversation deleted'),
              duration: Duration(seconds: 1),
            ),
          );
        }).catchError((error) {
          print("Error deleting conversation: $error");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting conversation: $error')),
          );
        });
      },
      child: FutureBuilder<String>(
        // Reuse existing method or create a cached version
        future: _getLastMessage(conversationId),
        builder: (context, lastMessageSnapshot) {
          final String lastMessage = lastMessageSnapshot.data ?? 'Loading...';

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color:
                      unreadCount > 0 ? tileColor : tileColor.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading:
                      _buildLeadingAvatar(displayName, tileColor, unreadCount),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          isPrivateChat ? displayName : title,
                          style: TextStyle(
                            fontWeight: unreadCount > 0
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 16,
                            color: tileColor.computeLuminance() > 0.5
                                ? Colors.black
                                : Colors.white,
                          ),
                        ),
                      ),
                      if (unreadCount > 0)
                        _buildUnreadBadge(unreadCount, tileColor),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: unreadCount > 0
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: tileColor.computeLuminance() > 0.5
                              ? Colors.black.withOpacity(0.7)
                              : Colors.white.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (type == 'Private Group')
                            const Text('🔒 ', style: TextStyle(fontSize: 12)),
                          Text(
                            isPrivateChat
                                ? 'Private'
                                : '${participants.length} members',
                            style: TextStyle(
                              fontSize: 12,
                              color: tileColor.computeLuminance() > 0.5
                                  ? Colors.black.withOpacity(0.6)
                                  : Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: FutureBuilder<String>(
                    future: _getLastMessageTime(conversationId),
                    builder: (context, timeSnapshot) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: tileColor.computeLuminance() > 0.5
                              ? Colors.black.withOpacity(0.1)
                              : Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          timeSnapshot.data ?? '...',
                          style: TextStyle(
                            fontSize: 12,
                            color: tileColor.computeLuminance() > 0.5
                                ? Colors.black
                                : Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                  onTap: () {
                    // Mark conversation as read
                    widget.messageTracker
                        .markConversationAsRead(conversationId);

                    // Navigate to chat screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          userId: widget.userId,
                          chatTitle: conversationId,
                          chatType: type,
                          messageTracker: widget.messageTracker,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

// Helper methods for UI components
  Widget _buildLeadingAvatar(
      String displayName, Color tileColor, int unreadCount) {
    return Stack(
      children: [
        CircleAvatar(
          backgroundColor: tileColor.computeLuminance() > 0.5
              ? Colors.black.withOpacity(0.1)
              : Colors.white.withOpacity(0.8),
          child: Text(
            displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
            style: TextStyle(
              color:
                  tileColor.computeLuminance() > 0.5 ? Colors.black : tileColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (unreadCount > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1),
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                unreadCount > 9 ? '9+' : unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildUnreadBadge(int count, Color tileColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 9 ? '9+' : count.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<String> _getLastMessageTime(String conversationId) async {
    try {
      final messages = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (messages.docs.isNotEmpty) {
        final timestamp = messages.docs.first['timestamp'] as Timestamp?;
        if (timestamp != null) {
          return _formatTimestamp(timestamp.toDate());
        }
      }
    } catch (e) {
      print("Error getting last message time: $e");
    }

    return '...';
  }

// Make sure this helper method handles null correctly
  String _formatTimestamp(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${time.month}/${time.day}';
    }
  }
}
