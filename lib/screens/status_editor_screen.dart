// lib/screens/status_editor_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

class StatusEditorScreen extends StatefulWidget {
  final String currentStatus;
  final String currentEmoji;

  const StatusEditorScreen({
    Key? key,
    required this.currentStatus,
    required this.currentEmoji,
  }) : super(key: key);

  @override
  _StatusEditorScreenState createState() => _StatusEditorScreenState();
}

class _StatusEditorScreenState extends State<StatusEditorScreen> {
  final TextEditingController _statusController = TextEditingController();
  String _selectedEmoji = '';
  bool _isSubmitting = false;

  // Predefined emoji options
  final List<String> _emojiOptions = [
    '😊',
    '😎',
    '🎉',
    '🎮',
    '📚',
    '👨‍💻',
    '🏋️',
    '🧘',
    '☕',
    '🍕',
    '🎵',
    '📱',
    '🏖️',
    '🚴',
    '🎬',
    '🛒',
    '💤',
    '🤔'
  ];

  @override
  void initState() {
    super.initState();
    _statusController.text = widget.currentStatus;
    _selectedEmoji = widget.currentEmoji;
  }

  @override
  void dispose() {
    _statusController.dispose();
    super.dispose();
  }

  Future<void> _saveStatus() async {
    if (_statusController.text.isEmpty && _selectedEmoji.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a status or select an emoji')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'statusMessage': _statusController.text.trim(),
        'statusEmoji': _selectedEmoji,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status updated successfully')),
      );

      Navigator.pop(context, true); // Return true to indicate success
    } catch (e) {
      print("Error updating status: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating status: $e')),
      );
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Status'),
        backgroundColor: Colors.white,
        titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20),
        elevation: 4,
      ),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status input
                  TextField(
                    controller: _statusController,
                    decoration: InputDecoration(
                      labelText: 'What are you up to?',
                      hintText: 'Exploring downtown today...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: _selectedEmoji.isNotEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Text(
                                _selectedEmoji,
                                style: const TextStyle(fontSize: 20),
                              ),
                            )
                          : null,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _statusController.text.isEmpty
                            ? null
                            : () {
                                _statusController.clear();
                                setState(() {});
                              },
                      ),
                      counter: Text('${_statusController.text.length}/100'),
                      counterStyle: TextStyle(
                        color: _statusController.text.length > 100
                            ? Colors.red
                            : Colors.grey,
                      ),
                      errorText: _statusController.text.length > 100
                          ? 'Status must be 100 characters or less'
                          : null,
                    ),
                    maxLength: 100,
                    buildCounter: (context,
                            {required currentLength,
                            required maxLength,
                            required isFocused}) =>
                        null,
                    maxLines: 2,
                    onChanged: (_) {
                      setState(() {});
                    },
                  ),

                  const SizedBox(height: 24),

                  // Emoji selection section
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Set your mood:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          // Clear emoji option
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedEmoji = '';
                              });
                            },
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: _selectedEmoji.isEmpty
                                    ? AppTheme.yellow.withOpacity(0.2)
                                    : Colors.grey[200],
                                borderRadius: BorderRadius.circular(25),
                                border: _selectedEmoji.isEmpty
                                    ? Border.all(color: AppTheme.yellow)
                                    : null,
                              ),
                              child: const Center(
                                child: Icon(Icons.clear, size: 24),
                              ),
                            ),
                          ),

                          // Emoji options
                          ..._emojiOptions
                              .map((emoji) => GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedEmoji = emoji;
                                      });
                                    },
                                    child: Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: _selectedEmoji == emoji
                                            ? AppTheme.yellow.withOpacity(0.2)
                                            : Colors.grey[200],
                                        borderRadius: BorderRadius.circular(25),
                                        border: _selectedEmoji == emoji
                                            ? Border.all(color: AppTheme.yellow)
                                            : null,
                                      ),
                                      child: Center(
                                        child: Text(
                                          emoji,
                                          style: const TextStyle(fontSize: 24),
                                        ),
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Status suggestions
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Suggestions:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildSuggestionChip('Exploring downtown today'),
                          _buildSuggestionChip('Working from home'),
                          _buildSuggestionChip(
                              'Looking for lunch recommendations'),
                          _buildSuggestionChip('Coffee break'),
                          _buildSuggestionChip('Open to hanging out'),
                          _buildSuggestionChip('Studying at the library'),
                          _buildSuggestionChip('Just moved to the area'),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _statusController.text.length > 100
                          ? null
                          : _saveStatus,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: AppTheme.yellow,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Update Status',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSuggestionChip(String suggestion) {
    return ActionChip(
      backgroundColor: Colors.grey[200],
      label: Text(suggestion),
      onPressed: () {
        setState(() {
          _statusController.text = suggestion;
        });
      },
    );
  }
}
