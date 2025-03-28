import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

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
  bool _isLoading = true;
  List<String> _availableFriends = [];

  @override
  void initState() {
    super.initState();
    // Set default topic text
    _topicController.text = 'Chat with ${widget.selectedFriend ?? ""}';
    selectedRecipient = widget.selectedFriend;
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('users').get();

      List<String> friends = [];
      for (var doc in snapshot.docs) {
        if (doc.id != widget.userId) {
          if (doc.data().containsKey('name')) {
            friends.add(doc['name'] as String);
          }
        }
      }

      // Add debugging
      print('Available friends: $friends');
      print('Selected recipient: $selectedRecipient');

      setState(() {
        _availableFriends = friends;

        // If a friend was pre-selected but isn't in the list, add them
        if (selectedRecipient != null &&
            !_availableFriends.contains(selectedRecipient)) {
          _availableFriends.add(selectedRecipient!);
        }

        _isLoading = false;
      });
    } catch (e) {
      print("Error loading friends: $e");
      setState(() {
        _isLoading = false;
      });

      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading friends: $e')),
      );
    }
  }

  void _handleStartChat() {
    print("Start chat button pressed");
    try {
      if (selectedRecipient != null) {
        final topic = _topicController.text.isEmpty
            ? 'Chat with $selectedRecipient'
            : _topicController.text;

        print("Starting chat with: $selectedRecipient, Topic: $topic");

        // Call the callback function
        widget.onStartChat(selectedRecipient!, topic);

        // Close the dialog
        Navigator.pop(context);
      } else {
        print("Cannot start chat - recipient is null");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a recipient')),
        );
      }
    } catch (e) {
      print("Error in _handleStartChat: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting chat: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if conditions are met for enabling the button
    bool canStartChat = selectedRecipient != null && !_isLoading;

    // Add debugging
    print('Can start chat: $canStartChat');
    print('Selected recipient: $selectedRecipient');
    print('Topic text: ${_topicController.text}');

    return AlertDialog(
      title: const Text('New Private Chat'),
      content: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Recipient:'),
                  const SizedBox(height: 8),

                  // Friend selection
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _availableFriends.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text("No friends available"),
                          )
                        : DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              hint: const Text('Select Friend'),
                              value: selectedRecipient,
                              onChanged: (String? newValue) {
                                setState(() {
                                  selectedRecipient = newValue;

                                  // Update topic text when recipient changes
                                  if (newValue != null &&
                                      (_topicController.text.isEmpty ||
                                          _topicController.text
                                              .startsWith('Chat with '))) {
                                    _topicController.text =
                                        'Chat with $newValue';
                                  }
                                });
                              },
                              items: _availableFriends
                                  .map<DropdownMenuItem<String>>(
                                      (String friend) {
                                return DropdownMenuItem<String>(
                                  value: friend,
                                  child: Text(friend),
                                );
                              }).toList(),
                            ),
                          ),
                  ),

                  const SizedBox(height: 16),

                  // Chat topic
                  TextField(
                    controller: _topicController,
                    decoration: const InputDecoration(
                      labelText: 'Chat Topic',
                      hintText: 'What do you want to chat about?',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  if (_availableFriends.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Text(
                        "You need to add friends before you can start a private chat.",
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: canStartChat ? _handleStartChat : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.blue,
            foregroundColor: Colors.white,
          ),
          child: const Text('Start'),
        ),
      ],
    );
  }
}
