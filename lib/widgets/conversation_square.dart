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

    // Choose color based on conversation type and response status
    Color squareColor;
    if (!hasResponses) {
      squareColor = Colors.grey[700]!; // Dark gray for no responses
    } else {
      switch (type) {
        case 'Private':
          squareColor = AppTheme.coral; // Red theme for private chats
          break;
        case 'Private Group':
          squareColor = AppTheme.green; // Green theme for private groups
          break;
        default:
          squareColor = AppTheme.blue; // Blue theme for public groups
      }
    }

    // Calculate activity level for glow effect
    double glowIntensity = 0.0;
    if (hasResponses && lastActivity != null) {
      // Factor in number of participants
      final participantFactor =
          (participants.length - 1) * 0.1; // 10% per participant

      // Factor in recency (more recent = more intense)
      final now = DateTime.now();
      final activityTime = lastActivity.toDate();
      final minutesAgo = now.difference(activityTime).inMinutes;

      if (minutesAgo < 15) {
        // Conversations less than 15 minutes old have some glow
        final recencyFactor = 1.0 - (minutesAgo / 15.0);

        // Combine factors (max intensity 0.7)
        glowIntensity = (participantFactor + recencyFactor).clamp(0.0, 0.7);
      }
    }

    // Get first message for preview
    return FutureBuilder<String>(
      future: _getFirstMessage(conversation.id),
      builder: (context, snapshot) {
        String previewText = snapshot.data ?? 'Loading...';

        // For private chats, get recipient name
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
                  // Regular shadow
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                  // Activity glow
                  if (glowIntensity > 0)
                    BoxShadow(
                      color: squareColor.withOpacity(glowIntensity),
                      spreadRadius: 2 + (glowIntensity * 6),
                      blurRadius: 10 + (glowIntensity * 10),
                      offset: const Offset(0, 0),
                    ),
                ],
              ),
              child: Stack(
                children: [
                  // User avatar in top left
                  Positioned(
                    top: 12,
                    left: 12,
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white,
                      child: type == 'Private'
                          ? Text(
                              displayName.isNotEmpty
                                  ? displayName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: squareColor,
                              ),
                            )
                          : Icon(
                              type == 'Private Group'
                                  ? Icons.group
                                  : Icons.public,
                              color: squareColor,
                              size: 24,
                            ),
                    ),
                  ),

                  // Title/name
                  Positioned(
                    bottom: 10,
                    left: 12,
                    right: 12,
                    child: Text(
                      type == 'Private' ? displayName : title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // First message content
                  Positioned(
                    top: 12,
                    left: 60,
                    right: 12,
                    child: Text(
                      previewText,
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Activity indicator/status
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        hasResponses ? '${participants.length} active' : 'New',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Get first message of conversation
  Future<String> _getFirstMessage(String conversationId) async {
    try {
      final messagesQuery = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .orderBy('timestamp')
          .limit(1)
          .get();

      if (messagesQuery.docs.isNotEmpty) {
        return messagesQuery.docs.first['text'] ?? 'No message';
      }
    } catch (e) {
      print("Error getting first message: $e");
    }

    return 'No messages yet';
  }
}
