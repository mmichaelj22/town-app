import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

class MessageListTile extends StatelessWidget {
  final DocumentSnapshot conversation;
  final String currentUserId;
  final int unreadCount;
  final VoidCallback onTap;

  const MessageListTile({
    Key? key,
    required this.conversation,
    required this.currentUserId,
    required this.unreadCount,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final data = conversation.data() as Map<String, dynamic>?;
    if (data == null) return const SizedBox();

    final String title = data['title'] ?? 'Unnamed';
    final String type = data['type'] ?? 'Group';
    final List<dynamic> participants = data['participants'] ?? [];

    // Extract other participant for private chats
    String displayName = title;
    if (type == 'Private' && title.contains(' with ')) {
      displayName = title.split(' with ').last;
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: _getMessagePreview(conversation.id),
      builder: (context, snapshot) {
        final String previewText = snapshot.data?['text'] ?? 'Loading...';
        final String timestamp = snapshot.data?['time'] ?? '';
        final String senderId = snapshot.data?['senderId'] ?? '';
        final bool isFromCurrentUser = senderId == currentUserId;

        // Only show unread indicator if message is not from current user
        final showUnreadIndicator = unreadCount > 0 && !isFromCurrentUser;

        return InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.shade200,
                  width: 1.0,
                ),
              ),
            ),
            child: Row(
              children: [
                // Avatar/Group icon with unread indicator
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: type == 'Private Group'
                          ? AppTheme.green.withOpacity(0.2)
                          : type == 'Group'
                              ? AppTheme.blue.withOpacity(0.2)
                              : AppTheme.coral.withOpacity(0.2),
                      child: type == 'Private'
                          ? Text(
                              displayName.isNotEmpty
                                  ? displayName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.coral,
                              ),
                            )
                          : Icon(
                              type == 'Private Group'
                                  ? Icons.group
                                  : Icons.public,
                              color: type == 'Private Group'
                                  ? AppTheme.green
                                  : AppTheme.blue,
                              size: 24,
                            ),
                    ),
                    if (showUnreadIndicator)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            unreadCount > 9 ? '9+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),

                // Message content area
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name and time
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            type == 'Private' ? displayName : title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: showUnreadIndicator
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                timestamp,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.chevron_right,
                                size: 16,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Message preview
                      const SizedBox(height: 4),
                      Text(
                        previewText,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          fontWeight: showUnreadIndicator
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Get the most recent message for preview
  Future<Map<String, dynamic>> _getMessagePreview(String conversationId) async {
    try {
      final messagesQuery = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (messagesQuery.docs.isNotEmpty) {
        final doc = messagesQuery.docs.first;
        final timestamp = doc['timestamp'] as Timestamp?;

        return {
          'text': doc['text'] ?? 'No message',
          'senderId': doc['senderId'] ?? '',
          'time': _formatTimestamp(timestamp),
        };
      }
    } catch (e) {
      print("Error getting message preview: $e");
    }

    return {
      'text': 'No messages yet',
      'senderId': '',
      'time': '',
    };
  }

  // Format timestamp for display
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final now = DateTime.now();
    final messageTime = timestamp.toDate();
    final difference = now.difference(messageTime);

    if (difference.inMinutes < 1) {
      return 'Now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24 && now.day == messageTime.day) {
      final hour =
          messageTime.hour > 12 ? messageTime.hour - 12 : messageTime.hour;
      final amPm = messageTime.hour >= 12 ? 'PM' : 'AM';
      return '$hour:${messageTime.minute.toString().padLeft(2, '0')} $amPm';
    } else if (difference.inDays < 7) {
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[messageTime.weekday - 1];
    } else {
      return '${messageTime.month}/${messageTime.day}';
    }
  }
}
