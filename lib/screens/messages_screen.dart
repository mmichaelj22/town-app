import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import '../widgets/custom_header.dart';

class MessagesScreen extends StatelessWidget {
  final String userId;

  const MessagesScreen({super.key, required this.userId});

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
      final String topic = "Test Conversation";
      final String type = "Private";

      // Create a test conversation in Firestore
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(topic)
          .set({
        'title': topic,
        'type': type,
        'participants': [userId],
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Add a test message
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(topic)
          .collection('messages')
          .add({
        'text': 'This is a test message',
        'senderId': userId,
        'timestamp': FieldValue.serverTimestamp(),
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

          // Message list
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
                  List<QueryDocumentSnapshot> docs = snapshot.data!.docs;

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
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          var doc = docs[index];
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

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Card(
                              elevation: 2,
                              margin: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: tileColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: FutureBuilder<String>(
                                    future: _getLastMessage(topic),
                                    builder: (context, lastMessageSnapshot) {
                                      String lastMessage =
                                          lastMessageSnapshot.data ??
                                              'Loading...';

                                      return ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 8),
                                        leading: CircleAvatar(
                                          backgroundColor: tileColor
                                                      .computeLuminance() >
                                                  0.5
                                              ? Colors.black.withOpacity(0.1)
                                              : Colors.white.withOpacity(0.8),
                                          child: type == 'Private'
                                              ? Text(
                                                  title.isNotEmpty
                                                      ? title[0].toUpperCase()
                                                      : '?',
                                                  style: TextStyle(
                                                    color: tileColor
                                                                .computeLuminance() >
                                                            0.5
                                                        ? Colors.black
                                                        : tileColor,
                                                    fontWeight: FontWeight.bold,
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
                                        title: Text(
                                          title,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color:
                                                tileColor.computeLuminance() >
                                                        0.5
                                                    ? Colors.black
                                                    : Colors.white,
                                          ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              lastMessage,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
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
                                                if (type == 'Private Group')
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
                                                            .withOpacity(0.6)
                                                        : Colors.white
                                                            .withOpacity(0.8),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        trailing: FutureBuilder<QuerySnapshot>(
                                          future: FirebaseFirestore.instance
                                              .collection('conversations')
                                              .doc(topic)
                                              .collection('messages')
                                              .orderBy('timestamp',
                                                  descending: true)
                                              .limit(1)
                                              .get(),
                                          builder: (context, messageSnapshot) {
                                            if (!messageSnapshot.hasData) {
                                              return const SizedBox.shrink();
                                            }

                                            if (messageSnapshot
                                                .data!.docs.isEmpty) {
                                              return const SizedBox.shrink();
                                            }

                                            var message = messageSnapshot
                                                .data!.docs.first;
                                            Timestamp? timestamp =
                                                message['timestamp'];

                                            return Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
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
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                _formatTimestamp(timestamp),
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
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => ChatScreen(
                                                userId: userId,
                                                chatTitle: topic,
                                                chatType: type,
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    }),
                              ),
                            ),
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
