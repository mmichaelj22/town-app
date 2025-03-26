import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  final String userId;
  final String chatTitle;
  final String chatType;

  const ChatScreen({
    super.key,
    required this.userId,
    required this.chatTitle,
    required this.chatType,
  });

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isComposing = false;
  List<String> participants = [];
  Color chatColor = AppTheme.blue; // Default color

  // For the like animation
  bool _showingLikeAnimation = false;

  // For bubble animations
  final Map<String, AnimationController> _bubbleAnimations = {};

  @override
  void initState() {
    super.initState();
    _loadParticipants();
    // Assign a color based on chat title
    final colorIndex = widget.chatTitle.hashCode % AppTheme.squareColors.length;
    chatColor = AppTheme.squareColors[colorIndex];
  }

  @override
  void dispose() {
    // Dispose all animation controllers
    _bubbleAnimations.forEach((_, controller) => controller.dispose());
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadParticipants() async {
    try {
      DocumentSnapshot chatDoc = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.chatTitle)
          .get();

      if (chatDoc.exists) {
        final data = chatDoc.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('participants')) {
          setState(() {
            participants = List<String>.from(data['participants']);
          });
        }
      }
    } catch (e) {
      print("Error loading participants: $e");
    }
  }

  void _sendMessage() {
    if (_messageController.text.isNotEmpty) {
      try {
        FirebaseFirestore.instance
            .collection('conversations')
            .doc(widget.chatTitle)
            .collection('messages')
            .add({
          'text': _messageController.text,
          'senderId': widget.userId,
          'timestamp': FieldValue.serverTimestamp(),
          'likes': [], // Initialize empty likes array
        });
        _messageController.clear();
        setState(() {
          _isComposing = false;
        });

        // Scroll to bottom after sending
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      } catch (e) {
        print("Error sending message: $e");
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to send message: $e')));
      }
    }
  }

  Future<void> _toggleLike(String messageId, List<dynamic> currentLikes) async {
    try {
      // Check if user already liked this message
      final bool alreadyLiked = currentLikes.contains(widget.userId);

      // Update the likes array
      if (alreadyLiked) {
        // Remove like
        await FirebaseFirestore.instance
            .collection('conversations')
            .doc(widget.chatTitle)
            .collection('messages')
            .doc(messageId)
            .update({
          'likes': FieldValue.arrayRemove([widget.userId])
        });
      } else {
        // Add like
        await FirebaseFirestore.instance
            .collection('conversations')
            .doc(widget.chatTitle)
            .collection('messages')
            .doc(messageId)
            .update({
          'likes': FieldValue.arrayUnion([widget.userId])
        });

        // Show animation when adding a like
        _animateLikeAdded(messageId);

        // Also show the center animation
        if (!alreadyLiked) {
          setState(() {
            _showingLikeAnimation = true;
          });

          // Hide center animation after delay
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (mounted) {
              setState(() {
                _showingLikeAnimation = false;
              });
            }
          });
        }
      }
    } catch (e) {
      print("Error toggling like: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error updating reaction: $e')));
    }
  }

  void _animateLikeAdded(String messageId) {
    // Create animation controller if it doesn't exist
    if (!_bubbleAnimations.containsKey(messageId)) {
      _bubbleAnimations[messageId] = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      );
    }

    // Play the animation
    _bubbleAnimations[messageId]!.forward(from: 0.0);
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    DateTime dateTime = timestamp.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    // For today's messages, show time only
    if (messageDate.isAtSameMomentAs(today)) {
      return '${dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12}:${dateTime.minute.toString().padLeft(2, '0')} ${dateTime.hour >= 12 ? 'PM' : 'AM'}';
    }
    // For this week, show day name and time
    else if (now.difference(messageDate).inDays < 7) {
      final weekdays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ];
      final weekday = weekdays[dateTime.weekday - 1];
      return '$weekday, ${dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12}:${dateTime.minute.toString().padLeft(2, '0')} ${dateTime.hour >= 12 ? 'PM' : 'AM'}';
    }
    // Otherwise show date and time
    else {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}, ${dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12}:${dateTime.minute.toString().padLeft(2, '0')} ${dateTime.hour >= 12 ? 'PM' : 'AM'}';
    }
  }

  Widget _buildMessageBubble(
      DocumentSnapshot message, bool isMe, String sender) {
    final messageId = message.id;
    final data = message.data() as Map<String, dynamic>;
    final messageText = data['text'] as String;
    final timestamp = data['timestamp'] as Timestamp?;
    final likes = data['likes'] ?? [];
    final bool userLiked = likes.contains(widget.userId);
    final int likeCount = likes.length;

    // Create animation controller if it doesn't exist for this message
    if (!_bubbleAnimations.containsKey(messageId)) {
      _bubbleAnimations[messageId] = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      );
    }

    final Animation<double> scaleAnimation = CurvedAnimation(
      parent: _bubbleAnimations[messageId]!,
      curve: Curves.elasticOut,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Show sender avatar for messages not from the current user
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
                // Message bubble
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? chatColor.withOpacity(0.9) : Colors.grey[200],
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
                      // Add sender name above message for group chats
                      if (!isMe && widget.chatType != 'Private')
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

                      // Message text
                      Text(
                        messageText,
                        style: TextStyle(
                          fontSize: 16,
                          color: isMe ? Colors.white : Colors.black87,
                        ),
                      ),

                      // Timestamp
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          _formatTimestamp(timestamp),
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

                // Likes indicator - only show if there are likes
                if (likeCount > 0)
                  Positioned(
                    bottom: -10,
                    right: isMe ? null : 10,
                    left: isMe ? 10 : null,
                    child: AnimatedBuilder(
                      animation: scaleAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: userLiked
                              ? 0.8 + (scaleAnimation.value * 0.4)
                              : 1.0,
                          child: child,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 2,
                              spreadRadius: 1,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.thumb_up,
                              size: 12,
                              color: userLiked ? Colors.blue : Colors.grey[600],
                            ),
                            if (likeCount > 1)
                              Padding(
                                padding: const EdgeInsets.only(left: 4.0),
                                child: Text(
                                  likeCount.toString(),
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
                  ),

                // Double-tap area for reactions
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onDoubleTap: () => _toggleLike(messageId, likes),
                      onLongPress: () {
                        // Show reaction options
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Message Actions'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: Icon(
                                    userLiked
                                        ? Icons.thumb_down
                                        : Icons.thumb_up,
                                    color: chatColor,
                                  ),
                                  title: Text(userLiked ? 'Unlike' : 'Like'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _toggleLike(messageId, likes);
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.copy,
                                      color: Colors.blue),
                                  title: const Text('Copy Text'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    // Copy message text to clipboard
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Message copied to clipboard')),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (isMe) const SizedBox(width: 8),

          // Show sender avatar for the current user's messages
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

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final dateOnly = DateTime(date.year, date.month, date.day);

    String dateText;
    if (dateOnly.isAtSameMomentAs(today)) {
      dateText = 'Today';
    } else if (dateOnly.isAtSameMomentAs(yesterday)) {
      dateText = 'Yesterday';
    } else if (now.difference(dateOnly).inDays < 7) {
      final weekdays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ];
      dateText = weekdays[date.weekday - 1];
    } else {
      dateText = '${date.month}/${date.day}/${date.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            dateText,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[800],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              // Custom app bar
              PreferredSize(
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
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          widget.chatType == 'Private' ||
                                  widget.chatType == 'Private Group'
                              ? CircleAvatar(
                                  backgroundColor:
                                      Colors.white.withOpacity(0.3),
                                  child: widget.chatType == 'Private'
                                      ? Text(
                                          widget.chatTitle
                                              .split(' with ')
                                              .last[0]
                                              .toUpperCase(),
                                          style: const TextStyle(
                                              color: Colors.white),
                                        )
                                      : const Icon(Icons.lock,
                                          color: Colors.white, size: 16),
                                )
                              : CircleAvatar(
                                  backgroundColor:
                                      Colors.white.withOpacity(0.3),
                                  child: const Icon(Icons.group,
                                      color: Colors.white, size: 16),
                                ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  widget.chatType == 'Private'
                                      ? widget.chatTitle.split(' with ').last
                                      : widget.chatTitle,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  widget.chatType == 'Private'
                                      ? 'Private Chat'
                                      : widget.chatType == 'Private Group'
                                          ? '${participants.length} members - Private'
                                          : '${participants.length} members',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.info_outline,
                                color: Colors.white),
                            onPressed: () {
                              // Show chat info (members, etc.)
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Chat info coming soon!')),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Chat messages
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                  ),
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('conversations')
                        .doc(widget.chatTitle)
                        .collection('messages')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final messages = snapshot.data!.docs;
                      if (messages.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No messages yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Be the first to say something!',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      // Build list of messages with date separators
                      List<Widget> messageWidgets = [];
                      DateTime? currentDate;

                      for (int i = 0; i < messages.length; i++) {
                        final message = messages[i];
                        final data = message.data() as Map<String, dynamic>;
                        final timestamp = data['timestamp'] as Timestamp?;
                        if (timestamp == null) continue;

                        final messageDate = timestamp.toDate();
                        final messageDay = DateTime(messageDate.year,
                            messageDate.month, messageDate.day);

                        // Add date separator if this is a new day
                        if (currentDate == null ||
                            !currentDate.isAtSameMomentAs(messageDay)) {
                          currentDate = messageDay;
                          messageWidgets.add(_buildDateSeparator(messageDate));
                        }

                        // Determine if message is from current user
                        final String senderId = data['senderId'] ?? '';
                        final bool isMe = senderId == widget.userId;

                        // Get sender name
                        String sender = isMe ? 'You' : senderId;
                        if (widget.chatType == 'Private') {
                          sender = isMe ? 'You' : 'Friend';
                        }

                        // Add message bubble
                        messageWidgets
                            .add(_buildMessageBubble(message, isMe, sender));
                      }

                      return ListView(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.all(8.0),
                        children: messageWidgets,
                      );
                    },
                  ),
                ),
              ),

              // Message input
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 8.0),
                    child: Row(
                      children: [
                        // Add attachment button
                        IconButton(
                          icon: Icon(
                            Icons.add_circle_outline,
                            color: chatColor,
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Attachments coming soon!')),
                            );
                          },
                        ),
                        // Text input field
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                  color: _isComposing
                                      ? chatColor
                                      : Colors.grey[300]!),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0),
                                    child: TextField(
                                      controller: _messageController,
                                      decoration: const InputDecoration(
                                        hintText: 'Type a message',
                                        border: InputBorder.none,
                                        contentPadding:
                                            EdgeInsets.symmetric(vertical: 10),
                                      ),
                                      onChanged: (text) {
                                        setState(() {
                                          _isComposing = text.isNotEmpty;
                                        });
                                      },
                                      onSubmitted: (_) =>
                                          _isComposing ? _sendMessage() : null,
                                    ),
                                  ),
                                ),
                                // Emoji button
                                IconButton(
                                  icon: Icon(
                                    Icons.emoji_emotions_outlined,
                                    color: Colors.grey[600],
                                  ),
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Emoji picker coming soon!')),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Send button
                        IconButton(
                          icon: Icon(
                            Icons.send,
                            color: _isComposing ? chatColor : Colors.grey[400],
                          ),
                          onPressed: _isComposing ? _sendMessage : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

// Replace the center like animation section with this corrected version:

// Center like animation overlay
          if (_showingLikeAnimation)
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: Center(
                  child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) {
                        // Calculate opacity but clamp it to valid range (0.0-1.0)
                        final opacity = value > 0.8
                            ? (2.0 - value * 2).clamp(0.0, 1.0)
                            : value.clamp(0.0, 1.0);

                        return Opacity(
                          opacity: opacity,
                          child: Transform.scale(
                            scale: value * 2.0,
                            child: Icon(
                              Icons.thumb_up,
                              size: 120,
                              color: chatColor.withOpacity(0.6),
                            ),
                          ),
                        );
                      }),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
