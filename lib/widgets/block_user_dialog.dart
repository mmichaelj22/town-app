import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Dialog to confirm blocking a user
class BlockUserDialog extends StatefulWidget {
  final String userId;
  final String otherUserId;
  final String otherUserName;
  final Function() onBlockComplete;

  const BlockUserDialog({
    Key? key,
    required this.userId,
    required this.otherUserId,
    required this.otherUserName,
    required this.onBlockComplete,
  }) : super(key: key);

  @override
  _BlockUserDialogState createState() => _BlockUserDialogState();
}

class _BlockUserDialogState extends State<BlockUserDialog> {
  bool _isBlocking = false;
  String? _selectedReason;
  String _customReason = '';
  bool _isReporting = false;

  final List<String> _blockReasons = [
    'Spam or unwanted messages',
    'Inappropriate content',
    'Harassment or bullying',
    'Pretending to be someone else',
    'I just don\'t want to see their messages',
    'Other reason (specify below)',
  ];

  Future<void> _blockUser() async {
    if (_isBlocking) return;

    setState(() {
      _isBlocking = true;
    });

    try {
      // Determine final reason text
      String reason = _selectedReason ?? 'No reason provided';
      if (_selectedReason == 'Other reason (specify below)' &&
          _customReason.isNotEmpty) {
        reason = _customReason;
      }

      // Add to blocked_users collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('blocked_users')
          .doc(widget.otherUserId)
          .set({
        'blockedAt': FieldValue.serverTimestamp(),
        'name': widget.otherUserName,
        'reason': reason,
      });

      // If user is reporting, create a report
      if (_isReporting) {
        await FirebaseFirestore.instance.collection('reports').add({
          'reporterId': widget.userId,
          'reportedUserId': widget.otherUserId,
          'reportedUserName': widget.otherUserName,
          'reason': reason,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'pending',
        });
      }

      // Close dialog and trigger onComplete callback
      if (mounted) {
        Navigator.of(context).pop(true);
        widget.onBlockComplete();
      }
    } catch (e) {
      print('Error blocking user: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error blocking user: ${e.toString()}')),
        );
        Navigator.of(context).pop(false);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBlocking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Block ${widget.otherUserName}?'),
      content: SingleChildScrollView(
        child: ListBody(
          children: [
            const Text(
              'When you block someone:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• You won\'t see their messages'),
            const Text('• They won\'t know you\'ve blocked them'),
            const Text('• You can unblock them later in Settings'),
            const SizedBox(height: 16),
            const Text('Why are you blocking this user?'),
            const SizedBox(height: 8),

            // Reason selection
            ...List.generate(_blockReasons.length, (index) {
              return RadioListTile<String>(
                title: Text(_blockReasons[index]),
                value: _blockReasons[index],
                groupValue: _selectedReason,
                onChanged: (value) {
                  setState(() {
                    _selectedReason = value;
                  });
                },
                dense: true,
                contentPadding: EdgeInsets.zero,
              );
            }),

            // Custom reason input
            if (_selectedReason == 'Other reason (specify below)')
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Please specify your reason',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                onChanged: (value) {
                  setState(() {
                    _customReason = value;
                  });
                },
              ),

            // Report checkbox
            CheckboxListTile(
              title: const Text('Also report this user to Town'),
              subtitle: const Text(
                  'This will send the user\'s information to our moderation team'),
              value: _isReporting,
              onChanged: (value) {
                setState(() {
                  _isReporting = value ?? false;
                });
              },
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: _isBlocking ? null : _blockUser,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: _isBlocking
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('BLOCK USER'),
        ),
      ],
    );
  }
}

// Function to show the block user dialog
Future<bool> showBlockUserDialog({
  required BuildContext context,
  required String userId,
  required String otherUserId,
  required String otherUserName,
  required Function() onBlockComplete,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => BlockUserDialog(
          userId: userId,
          otherUserId: otherUserId,
          otherUserName: otherUserName,
          onBlockComplete: onBlockComplete,
        ),
      ) ??
      false;
}

// Extension to add block option to chat screen
// This would be used within the chat_screen.dart file
/*
// Add this to your chat options or message long-press menu:

void _showMessageOptions(BuildContext context, String senderId, String senderName) {
  showModalBottomSheet(
    context: context,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (senderId != widget.userId) // Only show block option for other users
              ListTile(
                leading: const Icon(Icons.block, color: Colors.red),
                title: Text('Block $senderName'),
                onTap: () {
                  Navigator.pop(context); // Close bottom sheet
                  showBlockUserDialog(
                    context: context,
                    userId: widget.userId,
                    otherUserId: senderId,
                    otherUserName: senderName,
                    onBlockComplete: () {
                      // Navigate back to messages screen
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            // Other options...
          ],
        ),
      );
    },
  );
}
*/
