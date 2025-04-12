import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import 'conversation_starter.dart';
import '../utils/conversation_manager.dart';
import '../utils/blocking_utils.dart';
import '../widgets/conversation_square.dart';

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
  StreamSubscription? _conversationsSubscription;
  List<DocumentSnapshot> _visibleConversations = [];
  bool _isLoading = true;
  String? _errorMessage;
  // Add caching variables to prevent rebuild loops
  Future<List<DocumentSnapshot>>? _cachedFuture;
  String? _previousKey;

  @override
  void initState() {
    super.initState();
    _setupFirestoreListener();
  }

  void _setupFirestoreListener() {
    // Cancel any existing subscription
    _conversationsSubscription?.cancel();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Set up the listener with proper error handling
    _conversationsSubscription = FirebaseFirestore.instance
        .collection('conversations')
        .orderBy('lastActivity', descending: true)
        .snapshots()
        .handleError((error) {
      print("Firestore error: $error");
      setState(() {
        _isLoading = false;
        _errorMessage = "Couldn't load conversations: $error";
      });
    }).listen((snapshot) {
      _processConversationsSnapshot(snapshot);
    });
  }

  Future<void> _processConversationsSnapshot(QuerySnapshot snapshot) async {
    if (!mounted) return;

    try {
      // Get user data for filtering
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (!userDoc.exists) {
        setState(() {
          _isLoading = false;
          _errorMessage = "User data not found";
        });
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final userLat = userData['latitude'] as double? ?? 0.0;
      final userLon = userData['longitude'] as double? ?? 0.0;

      // Process conversations in a separate microtask to avoid blocking UI
      List<DocumentSnapshot> filteredConversations = [];

      // Use a background isolate or microtask for heavy processing
      await Future.microtask(() async {
        for (var conversation in snapshot.docs) {
          try {
            final isVisible = await ConversationManager.shouldShowOnHomeScreen(
              userId: widget.userId,
              conversation: conversation,
              detectionRadius: widget.detectionRadius,
              userLat: userLat,
              userLon: userLon,
            );

            if (isVisible) {
              filteredConversations.add(conversation);
            }
          } catch (e) {
            print("Error processing conversation ${conversation.id}: $e");
          }
        }

        // Filter blocked users
        filteredConversations =
            await BlockingUtils.filterConversationsWithBlockedUsers(
          currentUserId: widget.userId,
          conversations: filteredConversations,
        );
      });

      if (mounted) {
        setState(() {
          _visibleConversations = filteredConversations;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error processing conversations: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Error loading conversations: $e";
        });
      }
    }
  }

  @override
  void dispose() {
    // Clean up subscription to prevent memory leaks
    _conversationsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0.0),
        child: Column(
          children: [
            // Error message if needed
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 8),
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

            // Main conversation grid
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _visibleConversations.isEmpty
                      ? _buildEmptyState()
                      : _buildConversationsGrid(),
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

  Widget _buildEmptyState() {
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

  Widget _buildConversationsGrid() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16.0,
        mainAxisSpacing: 0.0,
        childAspectRatio: 1.0,
      ),
      itemCount: _visibleConversations.length,
      itemBuilder: (context, index) {
        final conversation = _visibleConversations[index];

        return ConversationSquare(
          conversation: conversation,
          userId: widget.userId,
          onTap: () {
            final data = conversation.data() as Map<String, dynamic>?;
            if (data == null) return;

            final String title = data['title'] as String? ?? 'Unnamed';
            final String type = data['type'] as String? ?? 'Group';

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
        );
      },
    );
  }

  // Build a tile for private chat
  Widget _buildPrivateChatTile(
    BuildContext context,
    DocumentSnapshot conversation,
    Color color,
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
    // Color color = squareColors[index % squareColors.length];

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
    Color color,
  ) {
    final data = conversation.data() as Map<String, dynamic>;
    final String title = data['title'] as String? ?? 'Unnamed';
    final List<dynamic> participants = data['participants'] ?? [];
    final String type = data['type'] as String? ?? 'Group';
    final bool isPrivateGroup = type == 'Private Group';

    // Get color based on index
    // Color color = squareColors[index % squareColors.length];

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
      final userName = userData['name'] as String? ?? 'User';

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
        // For group chats, add a first message from the creator (not system)
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
