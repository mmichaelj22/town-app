import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatelessWidget {
  final String userId;

  const MessagesScreen({super.key, required this.userId});

  Future<List<String>> _getFriends() async {
    DocumentSnapshot doc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return doc.exists && doc['friends'] != null
        ? List<String>.from(doc['friends'])
        : [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: Colors.white,
        elevation: 4,
        titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('conversations')
              .where('participants', arrayContains: userId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.data!.docs.isEmpty) {
              return const Center(
                  child: Text('No conversations yet. Join one from Home!'));
            }

            List<QueryDocumentSnapshot> docs = snapshot.data!.docs;
            docs.sort((a, b) => a['title'].compareTo(b['title']));

            return FutureBuilder<List<String>>(
              future: _getFriends(),
              builder: (context, friendsSnapshot) {
                if (!friendsSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                List<String> friends = friendsSnapshot.data!;

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var doc = docs[index];
                    String topic = doc['title'];
                    String type = doc['type'];
                    String title = type == 'Private'
                        ? doc['participants'].firstWhere((id) => id != userId,
                            orElse: () => 'Unknown')
                        : 'Group';
                    bool isFriend =
                        type == 'Private' && friends.contains(title);

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: type == 'Private'
                            ? Colors.blue[100]
                            : Colors.grey[200],
                        child: type == 'Private'
                            ? Text(title[0].toUpperCase(),
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
                            FirebaseFirestore.instance
                                .collection('users')
                                .doc(userId)
                                .set({
                              'friends': FieldValue.arrayUnion([title]),
                            }, SetOptions(merge: true));
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
