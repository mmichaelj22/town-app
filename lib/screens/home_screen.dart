import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import 'conversation_starter.dart';
import '../utils/conversation_manager.dart';
import '../utils/blocking_utils.dart';

class HomeScreen extends StatefulWidget {
  final String userId;
  final Function(String, String) onJoinConversation;
  final double detectionRadius;

  const HomeScreen({
    super.key,
    required this.userId,
    required this.onJoinConversation,
    required this.detectionRadius,
  });

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Color> squareColors = AppTheme.squareColors;

  // Add caching variables to prevent rebuild loops
  Future<List<DocumentSnapshot>>? _cachedFuture;
  String? _previousKey;

  @override
  Widget build(BuildContext context) {
    // double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Image.asset(
          'assets/images/logo.png',
          height: 60,
        ),
        centerTitle: true,
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
                        .doc(widget.userId)
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

                      // Create a unique key based on inputs
                      final currentKey =
                          "${snapshot.data!.docs.length}-${widget.userId}-${widget.detectionRadius}-$userLat-$userLon";

                      // Only create a new Future if our inputs have changed
                      if (_previousKey != currentKey) {
                        print(
                            "Creating new future with key: $currentKey (previous: $_previousKey)");
                        _previousKey = currentKey;
                        _cachedFuture = _processConversations(
                          snapshot.data!.docs,
                          widget.userId,
                          widget.detectionRadius,
                          userLat,
                          userLon,
                        );
                      } else {
                        print("Reusing cached future with key: $currentKey");
                      }

                      return FutureBuilder<List<DocumentSnapshot>>(
                        future: _cachedFuture,
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

                          // All conversations together (no splitting by type)
                          final allConversations = processedSnapshot.data!;

                          return GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16.0,
                              mainAxisSpacing: 0.0,
                              childAspectRatio:
                                  1.0, // Make squares equal width and height
                            ),
                            itemCount: allConversations.length,
                            itemBuilder: (context, index) {
                              final conversation = allConversations[index];
                              final data =
                                  conversation.data() as Map<String, dynamic>?;
                              if (data == null) return SizedBox();

                              final type = data['type'] as String? ?? 'Group';

                              if (type == 'Private') {
                                return _buildPrivateChatTile(
                                  context,
                                  conversation,
                                  index,
                                  squareColors,
                                );
                              } else {
                                return _buildGroupChatTile(
                                  context,
                                  conversation,
                                  index,
                                  squareColors,
                                );
                              }
                            },
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
              userId: widget.userId,
              detectionRadius: widget.detectionRadius,
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
    List<DocumentSnapshot> visibleConversations = [];

    print("Processing ${conversations.length} conversations");

    for (var conversation in conversations) {
      try {
        print("Checking visibility for conversation: ${conversation.id}");
        final isVisible = await ConversationManager.shouldShowOnHomeScreen(
          userId: userId,
          conversation: conversation,
          detectionRadius: detectionRadius,
          userLat: userLat,
          userLon: userLon,
        );

        print("Conversation ${conversation.id} visibility: $isVisible");

        if (isVisible) {
          visibleConversations.add(conversation);
        }
      } catch (e) {
        print("Error processing conversation ${conversation.id}: $e");
        // Skip this conversation if there was an error
      }
    }

    // Filter out conversations with blocked users
    visibleConversations =
        await BlockingUtils.filterConversationsWithBlockedUsers(
      currentUserId: userId,
      conversations: visibleConversations,
    );

    print(
        "Found ${visibleConversations.length} visible conversations after filtering blocked users");
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
        .where((id) => id != widget.userId)
        .firstWhere((id) => true, orElse: () => 'Unknown')
        .toString();

    // For display purposes
    String displayName = otherParticipant;
    if (title.contains(" with ")) {
      displayName = title.split(" with ").last;
    }

    // Extract topic from title if available
    // String topic = title;
    // if (title.contains(" with ")) {
    //   topic = title.split(" with ").first;
    // }

    // Get color based on index
    Color color = squareColors[index % squareColors.length];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: GestureDetector(
        onTap: () {
          widget.onJoinConversation(title, type);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                userId: widget.userId,
                chatTitle: title,
                chatType: type,
              ),
            ),
          );
        },
        child: Container(
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
              // User avatar in top left
              Positioned(
                top: 12,
                left: 12,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white,
                  child: Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ),

              // User name to the right of avatar
              Positioned(
                bottom: 10,
                left: 12,
                right: 12,
                child: Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Message content below avatar
              Positioned(
                top: 80,
                left: 115,
                right: 12,
                child: FutureBuilder<String>(
                    future: _getLastMessage(title),
                    builder: (context, snapshot) {
                      return Text(
                        snapshot.data ?? "No messages yet",
                        style: const TextStyle(
                          fontSize: 40,
                          color: Colors.white,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      );
                    }),
              ),

              // Timestamp at bottom
              Positioned(
                bottom: 12,
                right: 12,
                child: FutureBuilder<String>(
                    future: _getLastMessageTime(title),
                    builder: (context, snapshot) {
                      return Text(
                        snapshot.data ?? '...',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black,
                        ),
                      );
                    }),
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
          widget.onJoinConversation(title, type);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                userId: widget.userId,
                chatTitle: title,
                chatType: type,
              ),
            ),
          );
        },
        child: Container(
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
              // Message content at the top
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Last message only (no title)
                      FutureBuilder<String>(
                          future: _getLastMessage(title),
                          builder: (context, snapshot) {
                            String message = snapshot.data ?? "No messages yet";

                            // Strip "Group created: " prefix if present
                            if (message.startsWith("Group created: ")) {
                              message =
                                  message.substring("Group created: ".length);
                            }

                            return Text(
                              message,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.black87,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            );
                          }),
                    ],
                  ),
                ),
              ),

              // Member count with no background
              Positioned(
                bottom: 10,
                left: 12,
                child: Row(
                  children: [
                    if (isPrivateGroup)
                      const Text('🔒 ',
                          style: TextStyle(fontSize: 14, color: Colors.white)),
                    Text(
                      participants.length == 1
                          ? '1 member'
                          : '${participants.length} members',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // Timestamp below member count
              Positioned(
                bottom: 12,
                right: 12,
                child: FutureBuilder<String>(
                    future: _getLastMessageTime(title),
                    builder: (context, snapshot) {
                      return Text(
                        snapshot.data ?? '...',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black,
                        ),
                      );
                    }),
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
          .doc(widget.userId)
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
        creatorId: widget.userId,
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
          'senderId': widget.userId,
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
      widget.onJoinConversation(title, type);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            userId: widget.userId,
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
