import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

class ConversationSquare extends StatelessWidget {
  final DocumentSnapshot conversation;
  final String userId;
  final VoidCallback onTap;

  const ConversationSquare({
    Key? key,
    required this.conversation,
    required this.userId,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final data = conversation.data() as Map<String, dynamic>?;
    if (data == null) return const SizedBox();

    final String title = data['title'] as String? ?? 'Unnamed';
    final String type = data['type'] as String? ?? 'Group';
    final List<dynamic> participants = data['participants'] ?? [];
    final Timestamp? lastActivity = data['lastActivity'] as Timestamp?;

    // Determine if conversation has responses (more than 1 participant)
    final bool hasResponses = participants.length > 1;

    // Choose color based on conversation type
    Color squareColor;
    switch (type) {
      case 'Private':
        squareColor = AppTheme.coral; // Red theme for private chats
        break;
      case 'Private Group':
        squareColor = AppTheme.orange; // Orange theme for private groups
        break;
      default:
        squareColor = AppTheme.blue; // Blue theme for public groups
    }

    // Get first message for preview
    return FutureBuilder<Map<String, dynamic>>(
      future: _getFirstMessage(conversation.id),
      builder: (context, snapshot) {
        String messageText = snapshot.data?['text'] ?? 'Loading...';
        String formattedTime = snapshot.data?['formattedTime'] ?? '';

        // For private chats, extract recipient name
        String displayName = title;
        if (type == 'Private' && title.contains(' with ')) {
          displayName = title.split(' with ').last;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                color: squareColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: type == 'Private'
                  ? _buildPrivateChatSquare(
                      displayName, messageText, formattedTime)
                  : _buildGroupChatSquare(
                      type, messageText, formattedTime, participants.length),
            ),
          ),
        );
      },
    );
  }

  // Private chat layout
  Widget _buildPrivateChatSquare(
      String displayName, String messageText, String formattedTime) {
    return Stack(
      children: [
        // Large profile image in top left
        Positioned(
          top: 10,
          left: 10,
          child: CircleAvatar(
            radius: 50,
            backgroundColor: Colors.white,
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 50,
                fontWeight: FontWeight.bold,
                color: AppTheme.coral,
              ),
            ),
          ),
        ),

        // Name at bottom left
        Positioned(
          bottom: 10,
          left: 10,
          child: Text(
            displayName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Emoji message (larger)
        Positioned(
          bottom: 40,
          right: 20,
          child: Text(
            messageText,
            style: const TextStyle(
              fontSize: 40,
              color: Colors.white,
            ),
          ),
        ),

        // Timestamp at bottom right
        Positioned(
          bottom: 10,
          right: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              formattedTime,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Group chat layout (for both public and private groups)
  Widget _buildGroupChatSquare(
      String type, String messageText, String formattedTime, int memberCount) {
    return Stack(
      children: [
        // Message content (takes most of the space)
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 15, 15, 50),
          child: Text(
            messageText,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Bottom bar with member count and timestamp
        Positioned(
          bottom: 10,
          left: 10,
          right: 10,
          child: Row(
            children: [
              // Lock icon for private groups
              if (type == 'Private Group')
                const Padding(
                  padding: EdgeInsets.only(right: 5),
                  child: Icon(Icons.lock, color: Colors.white, size: 16),
                ),

              // Member count
              Text(
                '$memberCount members',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),

              const Spacer(),

              // Timestamp
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  formattedTime,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Get first message of conversation
  Future<Map<String, dynamic>> _getFirstMessage(String conversationId) async {
    try {
      final messagesQuery = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .orderBy('timestamp')
          .limit(1)
          .get();

      if (messagesQuery.docs.isNotEmpty) {
        final doc = messagesQuery.docs.first;
        final message = doc['text'] as String? ?? 'No message';
        final timestamp = doc['timestamp'] as Timestamp?;

        // Format timestamp
        String formattedTime = '';
        if (timestamp != null) {
          formattedTime = _formatTimestamp(timestamp.toDate());
        }

        return {
          'text': message,
          'formattedTime': formattedTime,
        };
      }
    } catch (e) {
      print("Error getting first message: $e");
    }

    return {
      'text': 'No messages yet',
      'formattedTime': '',
    };
  }

  // Format timestamp for display
  String _formatTimestamp(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${time.month}/${time.day}';
    }
  }
}
