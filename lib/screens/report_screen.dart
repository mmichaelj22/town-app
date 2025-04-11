// lib/screens/report_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../utils/user_blocking_service.dart';

class ReportScreen extends StatefulWidget {
  final String currentUserId;
  final String conversationId;
  final List<String> participants;

  const ReportScreen({
    Key? key,
    required this.currentUserId,
    required this.conversationId,
    required this.participants,
  }) : super(key: key);

  @override
  _ReportScreenState createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  String? _selectedUserId;
  String? _selectedUserName;
  final List<String> _selectedReasons = [];
  final TextEditingController _additionalCommentsController =
      TextEditingController();
  bool _isSubmitting = false;
  bool _blockUser = true;

  // List of report reasons
  final List<String> _reportReasons = [
    'Inappropriate or offensive content',
    'Harassment or bullying',
    'Spam or unwanted messages',
    'Safety concerns',
    'Hate speech or discrimination',
    'Impersonation or fake profile',
    'Privacy violation',
    'Promoting illegal activities',
  ];

  // Map to store user data
  final Map<String, Map<String, dynamic>> _userData = {};

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _additionalCommentsController.dispose();
    super.dispose();
  }

  // Load user data for all participants
  Future<void> _loadUsers() async {
    try {
      // Filter out the current user
      final otherParticipants = widget.participants
          .where((id) => id != widget.currentUserId)
          .toList();

      if (otherParticipants.isEmpty) {
        return;
      }

      for (String userId in otherParticipants) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>?;
          if (data != null && data.containsKey('name')) {
            setState(() {
              _userData[userId] = {
                'name': data['name'] ?? 'Unknown User',
                'profileImageUrl': data['profileImageUrl'] ?? '',
              };
            });
          }
        }
      }

      // If there's only one other participant, select them by default
      if (_userData.length == 1) {
        final userEntry = _userData.entries.first;
        setState(() {
          _selectedUserId = userEntry.key;
          _selectedUserName = userEntry.value['name'];
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading user data: $e')),
      );
    }
  }

  // Submit the report
  Future<void> _submitReport() async {
    if (_selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a user to report')),
      );
      return;
    }

    if (_selectedReasons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one reason')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Format reasons as a string
      final String reasonText = _selectedReasons.join('; ');
      final String additionalComments =
          _additionalCommentsController.text.trim();
      final String finalReason = additionalComments.isNotEmpty
          ? '$reasonText\n\nAdditional comments: $additionalComments'
          : reasonText;

      // Create a report in Firestore
      await FirebaseFirestore.instance.collection('reports').add({
        'reporterId': widget.currentUserId,
        'reportedUserId': _selectedUserId,
        'reportedUserName': _selectedUserName,
        'conversationId': widget.conversationId,
        'reasons': _selectedReasons,
        'additionalComments': additionalComments,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      // If user chose to block, block the reported user
      if (_blockUser) {
        final UserBlockingService blockingService = UserBlockingService();
        await blockingService.blockUser(
          currentUserId: widget.currentUserId,
          userToBlockId: _selectedUserId!,
          userToBlockName: _selectedUserName ?? 'Unknown User',
        );
      }

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted successfully')),
      );

      // Go back to previous screen
      Navigator.pop(context);
    } catch (e) {
      print('Error submitting report: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting report: $e')),
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
        title: const Text('Report'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Intro card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.report_problem,
                                    color: Colors.red),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Report Inappropriate Behavior',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Please help us maintain a safe and respectful community by reporting behavior that violates our community guidelines.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // User selection
                  const Text(
                    'Who would you like to report?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_userData.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('Loading users...'),
                      ),
                    )
                  else
                    Column(
                      children: _userData.entries.map((entry) {
                        final userId = entry.key;
                        final userData = entry.value;
                        final String userName = userData['name'];
                        final String profileImageUrl =
                            userData['profileImageUrl'] ?? '';

                        final bool isSelected = _selectedUserId == userId;

                        return Card(
                          elevation: isSelected ? 4 : 1,
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: isSelected
                                ? const BorderSide(color: Colors.red, width: 2)
                                : BorderSide.none,
                          ),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedUserId = userId;
                                _selectedUserName = userName;
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  // Profile image or initial
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: Colors.grey[200],
                                    backgroundImage: profileImageUrl.isNotEmpty
                                        ? NetworkImage(profileImageUrl)
                                        : null,
                                    child: profileImageUrl.isEmpty
                                        ? Text(
                                            userName.isNotEmpty
                                                ? userName[0].toUpperCase()
                                                : '?',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.coral,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 16),

                                  // User name
                                  Expanded(
                                    child: Text(
                                      userName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),

                                  // Selection indicator
                                  Icon(
                                    isSelected
                                        ? Icons.check_circle
                                        : Icons.circle_outlined,
                                    color:
                                        isSelected ? Colors.red : Colors.grey,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 24),

                  // Report reasons
                  const Text(
                    'Reason for reporting (select all that apply)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Reason checkboxes
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: _reportReasons.map((reason) {
                          final bool isSelected =
                              _selectedReasons.contains(reason);

                          return CheckboxListTile(
                            title: Text(reason),
                            value: isSelected,
                            activeColor: Colors.red,
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  _selectedReasons.add(reason);
                                } else {
                                  _selectedReasons.remove(reason);
                                }
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Additional comments
                  const Text(
                    'Additional comments (optional)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _additionalCommentsController,
                    decoration: InputDecoration(
                      hintText: 'Provide any additional details...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    maxLines: 4,
                  ),

                  const SizedBox(height: 24),

                  // Block user option
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: SwitchListTile(
                        title: const Text('Block this user'),
                        subtitle: const Text(
                          'When you block someone, you won\'t see their messages anymore',
                        ),
                        value: _blockUser,
                        onChanged: (bool value) {
                          setState(() {
                            _blockUser = value;
                          });
                        },
                        activeColor: Colors.red,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitReport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Submit Report',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
