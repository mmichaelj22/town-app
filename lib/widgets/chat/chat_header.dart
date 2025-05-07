import 'package:flutter/material.dart';

class ChatHeader extends StatelessWidget {
  final String chatTitle;
  final String chatType;
  final Color chatColor;
  final List<String> participants;
  final VoidCallback onInfoTap;
  final VoidCallback onBackTap;

  const ChatHeader({
    Key? key,
    required this.chatTitle,
    required this.chatType,
    required this.chatColor,
    required this.participants,
    required this.onInfoTap,
    required this.onBackTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Extract display name for private chats
    String displayName = chatTitle;
    if (chatType == 'Private' && chatTitle.contains(' with ')) {
      displayName = chatTitle.split(' with ').last;
    }

    return PreferredSize(
      preferredSize: const Size.fromHeight(60),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              chatColor,
              chatColor.withOpacity(0.7),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 8.0, bottom: 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: onBackTap,
                ),

                // Avatar/icon based on chat type
                _buildChatTypeAvatar(displayName),

                const SizedBox(width: 12),

                // Title and participant info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        chatType == 'Private' ? displayName : chatTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _buildSubtitle(),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // Info button
                IconButton(
                  icon: const Icon(Icons.info_outline, color: Colors.white),
                  onPressed: onInfoTap,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatTypeAvatar(String displayName) {
    return CircleAvatar(
      backgroundColor: Colors.white.withOpacity(0.3),
      child: chatType == 'Private'
          ? Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white),
            )
          : Icon(
              chatType == 'Private Group' ? Icons.lock : Icons.group,
              color: Colors.white,
              size: 16,
            ),
    );
  }

  String _buildSubtitle() {
    if (chatType == 'Private') {
      return 'Private Chat';
    } else if (chatType == 'Private Group') {
      return '${participants.length} members - Private';
    } else {
      return '${participants.length} members';
    }
  }
}
