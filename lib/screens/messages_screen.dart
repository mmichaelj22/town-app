import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import '../utils/conversation_manager.dart';
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
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // Custom gradient header
          CustomHeader(
            title: 'Messages',
            subtitle: 'Your conversations',
            primaryColor: AppTheme.green,
            // Removed the add button
          ),

          // Messages list
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
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
                          ],
                        ),
                      ),
                    );
                  }

                  print("Found ${snapshot.data!.docs.length} conversations");

                  // Filter conversations based on the visibility rule for Messages screen
                  final List<QueryDocumentSnapshot> visibleConversations =
                      snapshot.data!.docs.where((doc) {
                    try {
                      return ConversationManager.shouldShowOnMessagesScreen(
                        userId: userId,
                        conversation: doc,
                      );
                    } catch (e) {
                      print("Error checking visibility for ${doc.id}: $e");
                      return false;
                    }
                  }).toList();

                  // Sort by most recent activity
                  visibleConversations.sort((a, b) {
                    Timestamp? aLastActivity;
                    Timestamp? bLastActivity;

                    // Safely access lastActivity field
                    try {
                      final aData = a.data() as Map<String, dynamic>?;
                      if (aData != null && aData.containsKey('lastActivity')) {
                        aLastActivity = aData['lastActivity'] as Timestamp?;
                      }
                    } catch (e) {
                      print(
                          "Error accessing lastActivity for document ${a.id}: $e");
                    }

                    try {
                      final bData = b.data() as Map<String, dynamic>?;
                      if (bData != null && bData.containsKey('lastActivity')) {
                        bLastActivity = bData['lastActivity'] as Timestamp?;
                      }
                    } catch (e) {
                      print(
                          "Error accessing lastActivity for document ${b.id}: $e");
                    }

                    if (aLastActivity == null && bLastActivity == null) {
                      return 0;
                    } else if (aLastActivity == null) {
                      return 1;
                    } else if (bLastActivity == null) {
                      return -1;
                    }

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
                        padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 8), // Increased padding between items
                        itemCount: visibleConversations.length,
                        itemBuilder: (context, index) {
                          var doc = visibleConversations[index];
                          String conversationId = doc.id;
                          String type = doc['type'] ?? 'Group';
                          List<dynamic> participants =
                              doc['participants'] ?? [];

                          // Get the display name for user chat partner
                          String displayName = type == 'Private'
                              ? participants
                                  .firstWhere((id) => id != userId,
                                      orElse: () => 'Unknown')
                                  .toString()
                              : conversationId;

                          // Get color based on index
                          Color tileColor = AppTheme.squareColors[
                              index % AppTheme.squareColors.length];

                          return Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 4), // Increased vertical padding
                              child: Dismissible(
                                key: Key(conversationId),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.delete,
                                    color: Colors.white,
                                  ),
                                ),
                                confirmDismiss: (direction) async {
                                  return await showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: const Text("Confirm"),
                                        content: const Text(
                                            "Are you sure you want to delete this conversation?"),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context)
                                                    .pop(false),
                                            child: const Text("CANCEL"),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(true),
                                            child: const Text("DELETE",
                                                style: TextStyle(
                                                    color: Colors.red)),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                                onDismissed: (direction) {
                                  // Remove the user from the conversation participants
                                  FirebaseFirestore.instance
                                      .collection('conversations')
                                      .doc(conversationId)
                                      .update({
                                    'participants':
                                        FieldValue.arrayRemove([userId]),
                                  });

                                  // Show a snackbar
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('Removed from conversation'),
                                      action: SnackBarAction(
                                        label: 'UNDO',
                                        onPressed: () {
                                          // Add the user back to participants
                                          FirebaseFirestore.instance
                                              .collection('conversations')
                                              .doc(conversationId)
                                              .update({
                                            'participants':
                                                FieldValue.arrayUnion([userId]),
                                          });
                                        },
                                      ),
                                    ),
                                  );
                                },
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
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 6),
                                      leading: CircleAvatar(
                                        radius: 30,
                                        backgroundColor:
                                            tileColor.computeLuminance() > 0.5
                                                ? Colors.black.withOpacity(0.1)
                                                : Colors.white.withOpacity(0.8),
                                        child: type == 'Private'
                                            ? Text(
                                                displayName.isNotEmpty
                                                    ? displayName[0]
                                                        .toUpperCase()
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

                                      // Directly use the message as the title instead of having a separate title
                                      title: FutureBuilder<String>(
                                          future:
                                              _getLastMessage(conversationId),
                                          builder:
                                              (context, lastMessageSnapshot) {
                                            String messageText =
                                                lastMessageSnapshot.data ??
                                                    'Loading...';

                                            // Strip "Group created:" prefix if present
                                            if (messageText.startsWith(
                                                "Group created: ")) {
                                              messageText =
                                                  messageText.substring(
                                                      "Group created: ".length);
                                            }

                                            return Text(
                                              messageText,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontWeight: FontWeight
                                                    .normal, // not bold
                                                fontSize: 15,
                                                color: tileColor
                                                            .computeLuminance() >
                                                        0.5
                                                    ? Colors.black
                                                    : Colors.white,
                                              ),
                                            );
                                          }),

                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Show the contact name for private chats, or member count for group chats
                                          if (type == 'Private')
                                            Text(
                                              displayName,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: tileColor
                                                            .computeLuminance() >
                                                        0.5
                                                    ? Colors.black
                                                        .withOpacity(0.8)
                                                    : Colors.white
                                                        .withOpacity(0.9),
                                              ),
                                            )
                                          else
                                            Row(
                                              children: [
                                                if (type == 'Private Group')
                                                  const Text('🔒 ',
                                                      style: TextStyle(
                                                          fontSize: 12)),
                                                Text(
                                                  participants.length == 1
                                                      ? '1 member'
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
                                            .doc(conversationId)
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

                                          var message =
                                              messageSnapshot.data!.docs.first;
                                          Timestamp? timestamp =
                                              message['timestamp'];

                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color:
                                                  tileColor.computeLuminance() >
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
                                              chatTitle: conversationId,
                                              chatType: type,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ));
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
