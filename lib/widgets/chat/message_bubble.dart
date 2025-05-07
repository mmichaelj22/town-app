import 'package:flutter/material.dart';
import '../../../models/chat_message.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final String sender;
  final Color chatColor;
  final VoidCallback onDoubleTap;
  final VoidCallback onLongPress;
  final bool showProfileInfo;
  final String userId = 'currentUserId'; // Replace with actual user ID

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isMe,
    required this.sender,
    required this.chatColor,
    required this.onDoubleTap,
    required this.onLongPress,
    this.showProfileInfo = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar for non-current user
          if (!isMe)
            CircleAvatar(
              radius: 16,
              backgroundColor: chatColor.withOpacity(0.2),
              child: Text(
                sender.isNotEmpty ? sender[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: chatColor,
                ),
              ),
            ),

          if (!isMe) const SizedBox(width: 8),

          // Message bubble with reaction
          Flexible(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  onDoubleTap: onDoubleTap,
                  onLongPress: onLongPress,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color:
                          isMe ? chatColor.withOpacity(0.9) : Colors.grey[200],
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: isMe
                            ? const Radius.circular(18)
                            : const Radius.circular(4),
                        bottomRight: isMe
                            ? const Radius.circular(4)
                            : const Radius.circular(18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: isMe
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        // Sender name for group chats
                        if (!isMe && showProfileInfo)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: Text(
                              sender,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: chatColor,
                              ),
                            ),
                          ),

                        // Message content
                        if (message.imageUrl != null)
                          _buildImageContent(context)
                        else
                          Text(
                            message.text,
                            style: TextStyle(
                              fontSize: 16,
                              color: isMe ? Colors.white : Colors.black87,
                            ),
                          ),

                        // Timestamp
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            _formatTimestamp(message.timestamp),
                            style: TextStyle(
                              fontSize: 10,
                              color: isMe
                                  ? Colors.white.withOpacity(0.7)
                                  : Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (isMe) const SizedBox(width: 8),

          if (message.likes.isNotEmpty)
            Positioned(
              bottom: -10,
              right: isMe ? null : 10,
              left: isMe ? 10 : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.yellow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.thumb_up,
                      size: 12,
                      color: message.isLikedByCurrentUser(userId)
                          ? Colors.blue
                          : Colors.grey[600],
                    ),
                    if (message.likes.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: Text(
                          message.likes.length.toString(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          // Avatar for current user
          if (isMe)
            CircleAvatar(
              radius: 16,
              backgroundColor: chatColor,
              child: const Text(
                'Me',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageContent(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => _buildFullScreenImage(),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          message.imageUrl!,
          width: 200,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return SizedBox(
              height: 150,
              width: 200,
              child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 150,
              width: 200,
              color: Colors.grey.shade300,
              child: const Center(
                child: Icon(Icons.error, color: Colors.red),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFullScreenImage() {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        color: Colors.black,
        child: Center(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 3.0,
            child: Image.network(
              message.imageUrl!,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Text('Error loading image',
                      style: TextStyle(color: Colors.white)),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${time.month}/${time.day}';
    }
  }
}
