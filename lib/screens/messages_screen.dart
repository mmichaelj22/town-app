import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    print("Building MessagesScreen for user: $userId");

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: Colors.white,
        elevation: 4,
        titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20),
        actions: [
          // Add a button to create a test conversation for debugging
          IconButton(
            icon: const Icon(Icons.add, color: Colors.black),
            onPressed: () => _createDummyConversation(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
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
                  child:
                      Text('Error loading conversations: ${snapshot.error}'));
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              print("No conversations found for user $userId");
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('No conversations yet.'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _createDummyConversation(context),
                      child: const Text('Create Test Conversation'),
                    ),
                  ],
                ),
              );
            }

            print("Found ${snapshot.data!.docs.length} conversations");
            List<QueryDocumentSnapshot> docs = snapshot.data!.docs;
            docs.sort((a, b) {
              // Sort by most recent message if possible, otherwise by title
              return (a['title'] ?? '').compareTo(b['title'] ?? '');
            });

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
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var doc = docs[index];
                    String topic = doc['title'] ?? 'Unnamed';
                    String type = doc['type'] ?? 'Group';

                    print("Processing conversation: $topic, type: $type");

                    // Get the other participant for private chats
                    String title = type == 'Private'
                        ? (doc['participants'] as List?)
                                ?.firstWhere((id) => id != userId,
                                    orElse: () => 'Unknown')
                                ?.toString() ??
                            'Unknown'
                        : topic;

                    bool isFriend =
                        type == 'Private' && friends.contains(title);

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: type == 'Private'
                            ? Colors.blue[100]
                            : Colors.grey[200],
                        child: type == 'Private'
                            ? Text(
                                title.isNotEmpty ? title[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.black))
                            : const Icon(Icons.group, color: Colors.black),
                      ),
                      title: Text(title),
                      subtitle: Text(topic),
                      trailing: IconButton(
                        icon: Icon(
                          isFriend ? Icons.person : Icons.person_add,
                          color: Colors.black,
                        ),
                        onPressed: () {
                          if (isFriend) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('View Profile coming soon!')),
                            );
                          } else if (type == 'Private') {
                            // Add as friend
                            try {
                              FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(userId)
                                  .set({
                                'friends': FieldValue.arrayUnion([title]),
                              }, SetOptions(merge: true));

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Added $title as friend')),
                              );
                            } catch (e) {
                              print("Error adding friend: $e");
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
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
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
