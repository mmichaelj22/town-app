import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_screen.dart';

class NewPrivateChatDialog extends StatefulWidget {
  final String userId;
  final Function(String, String) onStartChat;
  final String? selectedFriend;

  const NewPrivateChatDialog({
    super.key,
    required this.userId,
    required this.onStartChat,
    this.selectedFriend,
  });

  @override
  _NewPrivateChatDialogState createState() => _NewPrivateChatDialogState();
}

class _NewPrivateChatDialogState extends State<NewPrivateChatDialog> {
  String? selectedRecipient;
  final TextEditingController _topicController = TextEditingController();

  @override
  void initState() {
    super.initState();
    selectedRecipient = widget.selectedFriend;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Private Chat'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                List<String> friends = [];
                if (snapshot.data != null) {
                  for (var doc in snapshot.data!.docs) {
                    if (doc.data() is Map<String, dynamic> &&
                        (doc.data() as Map<String, dynamic>)
                            .containsKey('name')) {
                      friends.add(doc['name'] as String);
                    }
                  }
                }
                if (friends.isEmpty) {
                  return const Text("No friends available");
                }
                return DropdownButton<String>(
                  hint: const Text('Select Recipient'),
                  value: selectedRecipient,
                  onChanged: (value) {
                    setState(() {
                      selectedRecipient = value;
                    });
                  },
                  items: friends.map((friend) {
                    return DropdownMenuItem<String>(
                      value: friend,
                      child: Text(friend),
                    );
                  }).toList(),
                );
              },
            ),
            TextField(
              controller: _topicController,
              decoration: const InputDecoration(hintText: 'Topic'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (selectedRecipient != null && _topicController.text.isNotEmpty) {
              widget.onStartChat(selectedRecipient!, _topicController.text);
              Navigator.pop(context);
            }
          },
          child: const Text('Start'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
