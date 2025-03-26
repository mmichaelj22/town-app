import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import 'conversation_starter.dart';

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

  final List<String> privateChats = const [
    'Coffee with Alice',
    'Plans with Bob',
    'Hey from Charlie',
  ];
  final List<String> communalChats = const [
    'Park Meetup',
    'Local Events',
    'Neighborhood Watch',
  ];

  final List<Color> squareColors = AppTheme.squareColors;

  Color _getSquareColor(
      int index, List<String> chats, List<Color>? otherColumnColors) {
    Color baseColor = squareColors[index % squareColors.length];
    Color? prevVertical =
        index > 0 ? squareColors[(index - 1) % squareColors.length] : null;
    Color? horizontal =
        otherColumnColors != null && index < otherColumnColors.length
            ? otherColumnColors[index]
            : null;

    if (baseColor == prevVertical || baseColor == horizontal) {
      for (Color color in squareColors) {
        if (color != prevVertical && color != horizontal) return color;
      }
    }
    return baseColor;
  }

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
      // Format as MM/DD for older messages
      return '${time.month}/${time.day}';
    }
  }

  Future<String> _getLastMessageTime(String chatTitle) async {
    try {
      final messages = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(chatTitle)
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

    // Return a placeholder if we couldn't get the real timestamp
    return '...';
  }

  void _handleCreateConversation(BuildContext context, String topic,
      String type, List<String> recipients) async {
    try {
      // Create a title based on the type
      String title = topic;
      if (type == 'Private' && recipients.isNotEmpty) {
        title = '$topic with ${recipients[0]}';
      }

      // Create conversation in Firestore
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(title)
          .set({
        'title': title,
        'type': type,
        'participants': [userId, ...recipients],
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Add initial message
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(title)
          .collection('messages')
          .add({
        'text': type == 'Private' ? topic : 'Group created: $topic',
        'senderId': userId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Navigate to new conversation
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

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double squareSize = (screenWidth - 32 - 16) / 2;

    List<Color> communalSquareColors = [];
    for (int i = 0; i < communalChats.length; i++) {
      communalSquareColors.add(_getSquareColor(
          i, communalChats, i == 0 ? null : communalSquareColors));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.appBarColor,
        elevation: 4,
        // Remove leading action button
        automaticallyImplyLeading: false,
        title: Image.asset(
          'assets/images/logo.png',
          height: 50,
        ),
        centerTitle: true,
        // Remove trailing action button
        actions: [],
      ),
      body: Column(
        children: [
          // Scrollable list of squares
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0.0),
              child: Row(
                children: [
                  // Private Chats Column
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ListView.builder(
                        itemCount: privateChats.length,
                        itemBuilder: (context, index) {
                          Color color = _getSquareColor(
                              index, privateChats, communalSquareColors);
                          String chatTitle = privateChats[index];
                          String senderName = chatTitle.contains(" with ")
                              ? chatTitle.split(" with ")[1]
                              : chatTitle;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: GestureDetector(
                              onTap: () {
                                onJoinConversation(
                                    privateChats[index], 'Private');
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatScreen(
                                      userId: userId,
                                      chatTitle: privateChats[index],
                                      chatType: 'Private',
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                height: squareSize,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(
                                      12), // Rounded corners
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.5),
                                      spreadRadius: 2,
                                      blurRadius: 5,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                // Replace the private chat tile section in home_screen.dart
// Look for the ListView.builder for privateChats and replace the Container's child Stack with this:

                                child: Stack(
                                  children: [
                                    // Profile image in top left - LARGER SIZE
                                    Positioned(
                                      top: 12,
                                      left: 12,
                                      child: CircleAvatar(
                                        radius: 32, // Increased from 24
                                        backgroundColor: Colors.white70,
                                        child: Text(
                                          senderName.isNotEmpty
                                              ? senderName[0].toUpperCase()
                                              : '?',
                                          style: TextStyle(
                                            fontSize: 26, // Increased from 22
                                            fontWeight: FontWeight.bold,
                                            color:
                                                color.computeLuminance() > 0.5
                                                    ? Colors.black87
                                                    : Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Sender name on the right
                                    Positioned(
                                      top: 18,
                                      left: 84, // Adjusted for larger avatar
                                      child: Text(
                                        senderName,
                                        style: TextStyle(
                                          fontSize: 18, // Increased from 16
                                          fontWeight: FontWeight.bold,
                                          color: color.computeLuminance() > 0.5
                                              ? Colors.black87
                                              : Colors.white,
                                        ),
                                      ),
                                    ),
                                    // Timestamp moved below name
                                    Positioned(
                                      top: 42, // Below the name
                                      left: 84, // Aligned with name
                                      child: FutureBuilder<String>(
                                          future:
                                              _getLastMessageTime(chatTitle),
                                          builder: (context, snapshot) {
                                            return Text(
                                              snapshot.data ?? '...',
                                              style: TextStyle(
                                                fontSize:
                                                    13, // Slightly increased from 12
                                                color:
                                                    color.computeLuminance() >
                                                            0.5
                                                        ? Colors.black54
                                                        : Colors.white70,
                                              ),
                                            );
                                          }),
                                    ),
                                    // Message preview at the bottom - unchanged
                                    Positioned(
                                      bottom: 12,
                                      left: 12,
                                      right: 12,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.7),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          chatTitle.contains(" with ")
                                              ? chatTitle.split(" with ")[0]
                                              : "Tap to view",
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black87,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  // Group Chats Column
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: ListView.builder(
                        itemCount: communalChats.length,
                        itemBuilder: (context, index) {
                          Color color = communalSquareColors[index];
                          String groupName = communalChats[index];
                          int participantCount =
                              3 + index; // Sample count for demo

                          // Determine if this is a private or public group
                          // For demo, let's make the first one private and others public
                          String type = index == 0 ? 'Private Group' : 'Group';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: GestureDetector(
                              onTap: () {
                                onJoinConversation(communalChats[index], type);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatScreen(
                                      userId: userId,
                                      chatTitle: communalChats[index],
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
                                    // Group topic at the top (moved from bottom)
                                    Positioned(
                                      top: 12,
                                      left: 12,
                                      right: 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.85),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          groupName,
                                          style: const TextStyle(
                                            fontSize: 14, // Increased size
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                          maxLines: 3, // Allow up to 3 lines
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),

                                    // Timestamp in top right - now outside the box
                                    Positioned(
                                      top: 15,
                                      right: 22,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: color.computeLuminance() > 0.5
                                              ? Colors.black.withOpacity(0.1)
                                              : Colors.white.withOpacity(0.3),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: FutureBuilder<String>(
                                            future:
                                                _getLastMessageTime(groupName),
                                            builder: (context, snapshot) {
                                              return Text(
                                                snapshot.data ?? '...',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color:
                                                      color.computeLuminance() >
                                                              0.5
                                                          ? Colors.black54
                                                          : Colors.white,
                                                ),
                                              );
                                            }),
                                      ),
                                    ),

                                    // Member count at the bottom with lock for private groups
                                    Positioned(
                                      bottom: 15,
                                      left: 15,
                                      child: Row(
                                        children: [
                                          // Lock emoji for private group
                                          if (type == 'Private Group')
                                            const Text(
                                              "🔒 ",
                                              style: TextStyle(fontSize: 16),
                                            ),

                                          Text(
                                            '$participantCount members',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color:
                                                  color.computeLuminance() > 0.5
                                                      ? Colors.black87
                                                      : Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
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
    );
  }
}
