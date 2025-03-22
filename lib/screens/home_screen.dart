import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_screen.dart';
import 'new_private_chat_dialog.dart';

class HomeScreen extends StatelessWidget {
  final String userId;
  final Function(String, String) onJoinConversation;

  const HomeScreen(
      {super.key, required this.userId, required this.onJoinConversation});

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
  final List<Color> squareColors = const [
    Color(0xFFE072A4),
    Color(0xFF6883BA),
    Color(0xFFF9DC5C),
    Color(0xFFB0E298),
  ];

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
        backgroundColor: Colors.white,
        elevation: 4,
        leading: IconButton(
          icon: const Icon(Icons.add, color: Colors.black),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => NewPrivateChatDialog(
                userId: userId,
                onStartChat: (recipient, topic) {
                  onJoinConversation(topic, 'Private');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        userId: userId,
                        chatTitle: topic,
                        chatType: 'Private',
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
        title: const Text('Town', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.black),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('New Communal Chat'),
                  content: const Text('Start a group chat (coming soon!)'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
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
                          onJoinConversation(privateChats[index], 'Private');
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
                            borderRadius:
                                BorderRadius.circular(12), // Rounded corners
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
                                    senderName.isNotEmpty
                                        ? senderName[0].toUpperCase()
                                        : '?',
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
                                  senderName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: color.computeLuminance() > 0.5
                                        ? Colors.black87
                                        : Colors.white,
                                  ),
                                ),
                              ),
                              // Timestamp in top right
                              Positioned(
                                top: 20,
                                right: 12,
                                child: FutureBuilder<String>(
                                    future: _getLastMessageTime(chatTitle),
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
                    int participantCount = 3 + index; // Sample count for demo

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: GestureDetector(
                        onTap: () {
                          onJoinConversation(communalChats[index], 'Group');
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                userId: userId,
                                chatTitle: communalChats[index],
                                chatType: 'Group',
                              ),
                            ),
                          );
                        },
                        child: Container(
                          height: squareSize,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius:
                                BorderRadius.circular(12), // Rounded corners
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
                                              color:
                                                  color.computeLuminance() > 0.5
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
                                              color:
                                                  color.computeLuminance() > 0.5
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
                              // Participant count on the right
                              Positioned(
                                top: 20,
                                left: 76,
                                child: Row(
                                  children: [
                                    Text(
                                      '$participantCount participants',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: color.computeLuminance() > 0.5
                                            ? Colors.black87
                                            : Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Timestamp in top right
                              Positioned(
                                top: 20,
                                right: 12,
                                child: FutureBuilder<String>(
                                    future: _getLastMessageTime(groupName),
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
                              ),
                              // Group topic at the bottom
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
                                  child: Text(
                                    groupName,
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
          ],
        ),
      ),
    );
  }
}
