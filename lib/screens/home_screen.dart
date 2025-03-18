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
                      child: const Text('OK'), // Fixed typo
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
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ListView.builder(
                  itemCount: privateChats.length,
                  itemBuilder: (context, index) {
                    Color color = _getSquareColor(
                        index, privateChats, communalSquareColors);
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
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.5),
                                spreadRadius: 2,
                                blurRadius: 5,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              privateChats[index],
                              style: const TextStyle(
                                  fontSize: 16, color: Colors.black),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: ListView.builder(
                  itemCount: communalChats.length,
                  itemBuilder: (context, index) {
                    Color color = communalSquareColors[index];
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
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.5),
                                spreadRadius: 2,
                                blurRadius: 5,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              communalChats[index],
                              style: const TextStyle(
                                  fontSize: 16, color: Colors.black),
                              textAlign: TextAlign.center,
                            ),
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
