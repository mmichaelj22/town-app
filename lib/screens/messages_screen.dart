import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import '../utils/conversation_manager.dart';
import '../widgets/custom_header.dart';
import '../services/message_tracker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MessagesScreen extends StatelessWidget {
  final String userId;
  final MessageTracker messageTracker;

  const MessagesScreen({
    super.key,
    required this.userId,
    required this.messageTracker,
  });

  Future<List<String>> _getFriends() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('friends')) {
          return List<String>.from(data['friends']);
        }
      }
      print("No friends data found for user $userId");
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
          .doc(userId)
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
        creatorId: userId,
        initialParticipants: [userId],
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
        'senderId': userId,
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
          prefs.getString('last_read_${userId}_$conversationId');
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
          .where('senderId', isNotEqualTo: userId)
          .get();

      return querySnapshot.docs.length;
    } catch (e) {
      print("Error getting unread count: $e");
      return 0;
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final now = DateTime.now();
    final messageTime = timestamp.toDate();
    final difference = now.difference(messageTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${messageTime.month}/${messageTime.day}';
    }
  }

  @override
  Widget build(BuildContext context) {
    print("Building MessagesScreen for user: $userId");

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Custom gradient header
          CustomHeader(
            title: 'Messages',
            subtitle: 'Your conversations',
            primaryColor: AppTheme.green,
            actions: [
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
                onPressed: () => _createDummyConversation(context),
              ),
            ],
          ),

          // Messages list
          SliverToBoxAdapter(
            child: Container(
              color: Colors.grey[100],
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('conversations')
                    .where('participants', arrayContains: userId)
                    .snapshots(),
                builder: (context, snapshot) {
                  // Add debug information
                  print("Stream state: ${snapshot.connectionState}");
                  if (snapshot.hasError) {
                    print("Stream error: ${snapshot.error}");
                    return Center(
                        child: Text(
                            'Error loading conversations: ${snapshot.error}'));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    print("No conversations found for user $userId");
                    return SizedBox(
                      height: MediaQuery.of(context).size.height -
                          120, // Adjust for header height
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.message_outlined,
                                size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text(
                              'No conversations yet',
                              style:
                                  TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Start a new conversation from the home screen',
                              style:
                                  TextStyle(fontSize: 14, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () =>
                                  _createDummyConversation(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.green,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                              ),
                              child: const Text('Create Test Conversation'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  print("Found ${snapshot.data!.docs.length} conversations");

                  // Filter conversations based on the visibility rule for Messages screen
                  final List<QueryDocumentSnapshot> visibleConversations =
                      snapshot.data!.docs.where((doc) {
                    return ConversationManager.shouldShowOnMessagesScreen(
                      userId: userId,
                      conversation: doc,
                    );
                  }).toList();

// Sort by most recent activity (with null safety)
                  visibleConversations.sort((a, b) {
                    // Safely extract timestamps with null checks
                    Timestamp? aLastActivity;
                    Timestamp? bLastActivity;

                    try {
                      if (a.data() is Map<String, dynamic>) {
                        final aData = a.data() as Map<String, dynamic>;
                        if (aData.containsKey('lastActivity')) {
                          aLastActivity = aData['lastActivity'] as Timestamp?;
                        }
                      }
                    } catch (e) {
                      print("Error accessing lastActivity for doc a: $e");
                    }

                    try {
                      if (b.data() is Map<String, dynamic>) {
                        final bData = b.data() as Map<String, dynamic>;
                        if (bData.containsKey('lastActivity')) {
                          bLastActivity = bData['lastActivity'] as Timestamp?;
                        }
                      }
                    } catch (e) {
                      print("Error accessing lastActivity for doc b: $e");
                    }

                    // Handle null cases
                    if (aLastActivity == null && bLastActivity == null) {
                      return 0;
                    } else if (aLastActivity == null) {
                      return 1; // Sort nulls to the end
                    } else if (bLastActivity == null) {
                      return -1; // Sort nulls to the end
                    }

                    // If both have timestamps, compare them
                    return bLastActivity.compareTo(aLastActivity);
                  });

                  // If no visible conversations after filtering
                  if (visibleConversations.isEmpty) {
                    return SizedBox(
                      height: MediaQuery.of(context).size.height - 120,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.message_outlined,
                                size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text(
                              'No active conversations',
                              style:
                                  TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Your conversations will appear here once you participate',
                              style:
                                  TextStyle(fontSize: 14, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return FutureBuilder<List<String>>(
                    future: _getFriends(),
                    builder: (context, friendsSnapshot) {
                      if (friendsSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      List<String> friends = friendsSnapshot.data ?? [];
                      print("Found ${friends.length} friends for user $userId");

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(8),
                        itemCount: visibleConversations.length,
                        itemBuilder: (context, index) {
                          var doc = visibleConversations[index];
                          String topic = doc['title'] ?? 'Unnamed';
                          String type = doc['type'] ?? 'Group';
                          List<dynamic> participants =
                              doc['participants'] ?? [];

                          print("Processing conversation: $topic, type: $type");

                          // Get the other participant for private chats
                          String title = type == 'Private'
                              ? participants
                                  .firstWhere((id) => id != userId,
                                      orElse: () => 'Unknown')
                                  .toString()
                              : topic;

                          bool isFriend =
                              type == 'Private' && friends.contains(title);

                          // Get color based on index (cycling through the color palette)
                          Color tileColor = AppTheme.squareColors[
                              index % AppTheme.squareColors.length];

                          return FutureBuilder<int>(
                            future: _getUnreadCount(topic),
                            builder: (context, unreadCountSnapshot) {
                              int unreadCount = unreadCountSnapshot.data ?? 0;

                              return Dismissible(
                                key: Key(topic),
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
                                      .doc(topic)
                                      .delete()
                                      .then((_) {
                                    // Also delete any messages in the conversation subcollection
                                    FirebaseFirestore.instance
                                        .collection('conversations')
                                        .doc(topic)
                                        .collection('messages')
                                        .get()
                                        .then((snapshot) {
                                      for (DocumentSnapshot doc
                                          in snapshot.docs) {
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
                                    print(
                                        "Error deleting conversation: $error");
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              'Error deleting conversation: $error')),
                                    );
                                  });
                                },
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: Card(
                                    elevation: 2,
                                    margin: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: unreadCount > 0
                                            ? tileColor
                                            : tileColor.withOpacity(0.7),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: unreadCount > 0
                                              ? tileColor
                                              : tileColor.withOpacity(0.7),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: FutureBuilder<String>(
                                          future: _getLastMessage(topic),
                                          builder:
                                              (context, lastMessageSnapshot) {
                                            String lastMessage =
                                                lastMessageSnapshot.data ??
                                                    'Loading...';

                                            return ListTile(
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 8),
                                              leading: Stack(
                                                children: [
                                                  CircleAvatar(
                                                    backgroundColor: tileColor
                                                                .computeLuminance() >
                                                            0.5
                                                        ? Colors.black
                                                            .withOpacity(0.1)
                                                        : Colors.white
                                                            .withOpacity(0.8),
                                                    child: type == 'Private'
                                                        ? Text(
                                                            title.isNotEmpty
                                                                ? title[0]
                                                                    .toUpperCase()
                                                                : '?',
                                                            style: TextStyle(
                                                              color: tileColor
                                                                          .computeLuminance() >
                                                                      0.5
                                                                  ? Colors.black
                                                                  : tileColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          )
                                                        : Icon(
                                                            Icons.group,
                                                            color: tileColor
                                                                        .computeLuminance() >
                                                                    0.5
                                                                ? Colors.black
                                                                : tileColor,
                                                          ),
                                                  ),
                                                  if (unreadCount > 0)
                                                    Positioned(
                                                      right: -2,
                                                      top: -2,
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(4),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.red,
                                                          shape:
                                                              BoxShape.circle,
                                                          border: Border.all(
                                                            color: Colors.white,
                                                            width: 1,
                                                          ),
                                                        ),
                                                        constraints:
                                                            const BoxConstraints(
                                                          minWidth: 14,
                                                          minHeight: 14,
                                                        ),
                                                        child: Text(
                                                          unreadCount > 9
                                                              ? '9+'
                                                              : unreadCount
                                                                  .toString(),
                                                          style:
                                                              const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                          textAlign:
                                                              TextAlign.center,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              title: Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      title,
                                                      style: TextStyle(
                                                        fontWeight:
                                                            unreadCount > 0
                                                                ? FontWeight
                                                                    .bold
                                                                : FontWeight
                                                                    .normal,
                                                        fontSize: 16,
                                                        color: tileColor
                                                                    .computeLuminance() >
                                                                0.5
                                                            ? Colors.black
                                                            : Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                  if (unreadCount > 0)
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 6,
                                                          vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.red,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(10),
                                                      ),
                                                      child: Text(
                                                        unreadCount > 9
                                                            ? '9+'
                                                            : unreadCount
                                                                .toString(),
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              subtitle: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    lastMessage,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontWeight: unreadCount >
                                                              0
                                                          ? FontWeight.bold
                                                          : FontWeight.normal,
                                                      color: tileColor
                                                                  .computeLuminance() >
                                                              0.5
                                                          ? Colors.black
                                                              .withOpacity(0.7)
                                                          : Colors.white
                                                              .withOpacity(0.9),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      if (type ==
                                                          'Private Group')
                                                        const Text('🔒 ',
                                                            style: TextStyle(
                                                                fontSize: 12)),
                                                      Text(
                                                        type == 'Private'
                                                            ? 'Private'
                                                            : '${participants.length} members',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: tileColor
                                                                      .computeLuminance() >
                                                                  0.5
                                                              ? Colors.black
                                                                  .withOpacity(
                                                                      0.6)
                                                              : Colors.white
                                                                  .withOpacity(
                                                                      0.8),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              trailing:
                                                  FutureBuilder<QuerySnapshot>(
                                                future: FirebaseFirestore
                                                    .instance
                                                    .collection('conversations')
                                                    .doc(topic)
                                                    .collection('messages')
                                                    .orderBy('timestamp',
                                                        descending: true)
                                                    .limit(1)
                                                    .get(),
                                                builder:
                                                    (context, messageSnapshot) {
                                                  if (!messageSnapshot
                                                      .hasData) {
                                                    return const SizedBox
                                                        .shrink();
                                                  }

                                                  if (messageSnapshot
                                                      .data!.docs.isEmpty) {
                                                    return const SizedBox
                                                        .shrink();
                                                  }

                                                  var message = messageSnapshot
                                                      .data!.docs.first;
                                                  Timestamp? timestamp =
                                                      message['timestamp'];

                                                  return Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: tileColor
                                                                  .computeLuminance() >
                                                              0.5
                                                          ? Colors.black
                                                              .withOpacity(0.1)
                                                          : Colors.white
                                                              .withOpacity(0.2),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                    child: Text(
                                                      _formatTimestamp(
                                                          timestamp),
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: tileColor
                                                                    .computeLuminance() >
                                                                0.5
                                                            ? Colors.black
                                                            : Colors.white,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                              onTap: () {
                                                // Mark conversation as read
                                                messageTracker
                                                    .markConversationAsRead(
                                                        topic);

                                                // Navigate to chat screen
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        ChatScreen(
                                                      userId: userId,
                                                      chatTitle: topic,
                                                      chatType: type,
                                                      messageTracker:
                                                          messageTracker,
                                                    ),
                                                  ),
                                                );
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
