import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import 'new_private_chat_dialog.dart';
import 'conversation_starter.dart';
import '../utils/conversation_manager.dart';

class HomeScreen extends StatelessWidget {
  final String userId;
  final Function(String, String) onJoinConversation;
  final double detectionRadius;

  const HomeScreen({
    super.key,
    required this.userId,
    required this.onJoinConversation,
    required this.detectionRadius,
  });

  final List<Color> squareColors = AppTheme.squareColors;

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double squareSize = (screenWidth - 32 - 16) / 2;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.appBarColor,
        elevation: 4,
        // Remove leading action button
        automaticallyImplyLeading: false,
        title: Image.asset(
          'assets/images/logo.png',
          height: 30,
        ),
        centerTitle: true,
        // Remove trailing action button
        actions: [],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0.0),
        child: Column(
          children: [
            // Scrollable list of squares
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('conversations')
                    .orderBy('lastActivity', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No conversations nearby',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start a new conversation to connect with people around you',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .get(),
                    builder: (context, userSnapshot) {
                      if (userSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                        return const Center(child: Text('User data not found'));
                      }

                      final userData =
                          userSnapshot.data!.data() as Map<String, dynamic>;
                      final userLat = userData['latitude'] as double? ?? 0.0;
                      final userLon = userData['longitude'] as double? ?? 0.0;

                      // Process conversations asynchronously
                      return FutureBuilder<List<DocumentSnapshot>>(
                        future: _processConversations(
                          snapshot.data!.docs,
                          userId,
                          detectionRadius,
                          userLat,
                          userLon,
                        ),
                        builder: (context, processedSnapshot) {
                          if (processedSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          if (!processedSnapshot.hasData ||
                              processedSnapshot.data!.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No conversations nearby',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Start a new conversation to connect with people around you',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[500],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            );
                          }

                          // Split conversations into private and group
                          final List<DocumentSnapshot> privateConversations =
                              [];
                          final List<DocumentSnapshot> groupConversations = [];

                          for (var doc in processedSnapshot.data!) {
                            final data = doc.data() as Map<String, dynamic>?;
                            if (data == null) continue;

                            final type = data['type'] as String? ?? 'Group';
                            if (type == 'Private') {
                              privateConversations.add(doc);
                            } else {
                              groupConversations.add(doc);
                            }
                          }

                          return Row(
                            children: [
                              // Private Chats Column
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: privateConversations.isEmpty
                                      ? Center(
                                          child: Text(
                                            'No private chats',
                                            style: TextStyle(
                                                color: Colors.grey[600]),
                                          ),
                                        )
                                      : ListView.builder(
                                          itemCount:
                                              privateConversations.length,
                                          itemBuilder: (context, index) {
                                            return _buildPrivateChatTile(
                                              context,
                                              privateConversations[index],
                                              index,
                                              squareColors,
                                            );
                                          },
                                        ),
                                ),
                              ),

                              // Group Chats Column
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: groupConversations.isEmpty
                                      ? Center(
                                          child: Text(
                                            'No group chats',
                                            style: TextStyle(
                                                color: Colors.grey[600]),
                                          ),
                                        )
                                      : ListView.builder(
                                          itemCount: groupConversations.length,
                                          itemBuilder: (context, index) {
                                            return _buildGroupChatTile(
                                              context,
                                              groupConversations[index],
                                              index,
                                              squareColors,
                                            );
                                          },
                                        ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),

            // Conversation starter component
            ConversationStarter(
              userId: userId,
              detectionRadius: detectionRadius,
              onCreateConversation: (topic, type, recipients) =>
                  _handleCreateConversation(context, topic, type, recipients),
            ),
          ],
        ),
      ),
    );
  }

  // Process conversations based on visibility rules
  Future<List<DocumentSnapshot>> _processConversations(
    List<DocumentSnapshot> conversations,
    String userId,
    double detectionRadius,
    double userLat,
    double userLon,
  ) async {
    final List<DocumentSnapshot> visibleConversations = [];

    for (var conversation in conversations) {
      final isVisible = await ConversationManager.shouldShowOnHomeScreen(
        userId: userId,
        conversation: conversation,
        detectionRadius: detectionRadius,
        userLat: userLat,
        userLon: userLon,
      );

      if (isVisible) {
        visibleConversations.add(conversation);
      }
    }

    return visibleConversations;
  }

  // Build a tile for private chat
  Widget _buildPrivateChatTile(
    BuildContext context,
    DocumentSnapshot conversation,
    int index,
    List<Color> squareColors,
  ) {
    final data = conversation.data() as Map<String, dynamic>;
    final String title = data['title'] as String? ?? 'Unnamed';
    final List<dynamic> participants = data['participants'] ?? [];
    final String type = data['type'] as String? ?? 'Private';

    // Find the other participant (not the current user)
    String otherParticipant = participants
        .where((id) => id != userId)
        .firstWhere((id) => true, orElse: () => 'Unknown')
        .toString();

    // For display purposes
    String displayName = otherParticipant;
    if (title.contains(" with ")) {
      displayName = title.split(" with ").last;
    }

    // Extract topic from title if available
    String topic = title;
    if (title.contains(" with ")) {
      topic = title.split(" with ").first;
    }

    // Get color based on index
    Color color = squareColors[index % squareColors.length];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: GestureDetector(
        onTap: () {
          onJoinConversation(title, type);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                userId: userId,
                chatTitle: title,
                chatType: type,
              ),
            ),
          );
        },
        child: Container(
          height: squareSize,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.5),
                spreadRadius: 2,
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Profile image in top left
              Positioned(
                top: 12,
                left: 12,
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white70,
                  child: Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color.computeLuminance() > 0.5
                          ? Colors.black87
                          : Colors.white,
                    ),
                  ),
                ),
              ),
              // Sender name on the right
              Positioned(
                top: 20,
                left: 68,
                child: Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color.computeLuminance() > 0.5
                        ? Colors.black87
                        : Colors.white,
                  ),
                ),
              ),
              // Timestamp
              Positioned(
                top: 42,
                left: 68,
                child: FutureBuilder<String>(
                    future: _getLastMessageTime(title),
                    builder: (context, snapshot) {
                      return Text(
                        snapshot.data ?? '...',
                        style: TextStyle(
                          fontSize: 13,
                          color: color.computeLuminance() > 0.5
                              ? Colors.black54
                              : Colors.white70,
                        ),
                      );
                    }),
              ),
              // Message preview at the bottom
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: FutureBuilder<String>(
                      future: _getLastMessage(title),
                      builder: (context, snapshot) {
                        return Text(
                          snapshot.data ?? topic,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        );
                      }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build a tile for group chat
  Widget _buildGroupChatTile(
    BuildContext context,
    DocumentSnapshot conversation,
    int index,
    List<Color> squareColors,
  ) {
    final data = conversation.data() as Map<String, dynamic>;
    final String title = data['title'] as String? ?? 'Unnamed';
    final List<dynamic> participants = data['participants'] ?? [];
    final String type = data['type'] as String? ?? 'Group';
    final bool isPrivateGroup = type == 'Private Group';

    // Get color based on index
    Color color = squareColors[index % squareColors.length];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: GestureDetector(
        onTap: () {
          onJoinConversation(title, type);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                userId: userId,
                chatTitle: title,
                chatType: type,
              ),
            ),
          );
        },
        child: Container(
          height: squareSize,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.5),
                spreadRadius: 2,
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Stacked profile images in top left
              Positioned(
                top: 12,
                left: 12,
                child: SizedBox(
                  width: 58,
                  height: 48,
                  child: Stack(
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.white70,
                          child: Text(
                            'A',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: color.computeLuminance() > 0.5
                                  ? Colors.black87
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        left: 16,
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.white70,
                          child: Text(
                            'B',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: color.computeLuminance() > 0.5
                                  ? Colors.black87
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Group info
              Positioned(
                top: 20,
                left: 76,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Group title
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color.computeLuminance() > 0.5
                            ? Colors.black87
                            : Colors.white,
                      ),
                    ),
                    // Timestamp
                    FutureBuilder<String>(
                        future: _getLastMessageTime(title),
                        builder: (context, snapshot) {
                          return Text(
                            snapshot.data ?? '...',
                            style: TextStyle(
                              fontSize: 12,
                              color: color.computeLuminance() > 0.5
                                  ? Colors.black54
                                  : Colors.white70,
                            ),
                          );
                        }),
                  ],
                ),
              ),
              // Member count at bottom left
              Positioned(
                bottom: 12,
                left: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      if (isPrivateGroup)
                        const Text('🔒 ', style: TextStyle(fontSize: 14)),
                      Text(
                        '${participants.length} members',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Topic at the bottom
              Positioned(
                bottom: 12,
                left: participants.isEmpty ? 12 : 100,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: FutureBuilder<String>(
                      future: _getLastMessage(title),
                      builder: (context, snapshot) {
                        return Text(
                          snapshot.data ?? "No messages yet",
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        );
                      }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to get last message time
  Future<String> _getLastMessageTime(String conversationId) async {
    try {
      final messages = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (messages.docs.isNotEmpty &&
          messages.docs.first['timestamp'] != null) {
        final timestamp = messages.docs.first['timestamp'] as Timestamp;
        return _formatTimestamp(timestamp.toDate());
      }
    } catch (e) {
      print("Error getting last message time: $e");
    }

    return '...';
  }

  // Helper method to get last message content
  Future<String> _getLastMessage(String conversationId) async {
    try {
      final messages = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (messages.docs.isNotEmpty) {
        return messages.docs.first['text'] as String? ?? 'No message';
      }
    } catch (e) {
      print("Error getting last message: $e");
    }

    return 'No messages yet';
  }

  // Format timestamp for display
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

  // Handle creating a new conversation
  Future<void> _handleCreateConversation(BuildContext context, String topic,
      String type, List<String> recipients) async {
    try {
      // Get current user location
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

      // Create title based on the type and topic
      String title = topic;
      if (type == 'Private' && recipients.isNotEmpty) {
        title = '$topic with ${recipients[0]}';
      }

      // Create conversation with proper location information
      await ConversationManager.createConversation(
        title: title,
        type: type,
        creatorId: userId,
        initialParticipants: recipients,
        latitude: userLat,
        longitude: userLon,
      );

      // Add initial message if there is content
      if (type == 'Private' && recipients.isNotEmpty) {
        // For private messages, the topic becomes the first message
        await FirebaseFirestore.instance
            .collection('conversations')
            .doc(title)
            .collection('messages')
            .add({
          'text': topic,
          'senderId': userId,
          'timestamp': FieldValue.serverTimestamp(),
          'likes': [],
        });
      } else {
        // For group chats, add a system message about creation
        await FirebaseFirestore.instance
            .collection('conversations')
            .doc(title)
            .collection('messages')
            .add({
          'text': 'Group created: $topic',
          'senderId': 'system',
          'timestamp': FieldValue.serverTimestamp(),
          'likes': [],
        });
      }

      // Navigate to the conversation
      onJoinConversation(title, type);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            userId: userId,
            chatTitle: title,
            chatType: type,
          ),
        ),
      );
    } catch (e) {
      print("Error creating conversation: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating conversation: $e')),
      );
    }
  }
}
