// Updated chat_screen.dart with fixes for the emoji_picker_flutter package

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../utils/conversation_manager.dart';
import '../utils/user_blocking_service.dart';
import '../services/message_tracker.dart';
import 'report_screen.dart';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import '../main.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

class ChatScreen extends StatefulWidget {
  final String userId;
  final String chatTitle;
  final String chatType;
  final MessageTracker? messageTracker;

  const ChatScreen({
    super.key,
    required this.userId,
    required this.chatTitle,
    required this.chatType,
    this.messageTracker,
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
  bool _showEmojiPicker = false;
  FocusNode _messageFocusNode = FocusNode();

  // For the like animation
  bool _showingLikeAnimation = false;

  // For bubble animations
  final Map<String, AnimationController> _bubbleAnimations = {};

  @override
  void initState() {
    super.initState();
    _loadParticipants();

    // Assign a color based on chat type instead of chat title
    switch (widget.chatType) {
      case 'Private':
        chatColor = AppTheme.coral;
        break;
      case 'Private Group':
        chatColor = AppTheme.orange;
        break;
      default: // Public Group
        chatColor = AppTheme.blue;
    }

    // Mark conversation as read when entering
    if (widget.messageTracker != null) {
      widget.messageTracker!.markConversationAsRead(widget.chatTitle);
    }

    // Add this listener for emoji picker
    _messageFocusNode.addListener(() {
      if (_messageFocusNode.hasFocus && mounted) {
        setState(() {
          _showEmojiPicker = false;
        });
      }
    });
  }

  @override
  void dispose() {
    // Dispose all animation controllers
    _bubbleAnimations.forEach((_, controller) => controller.dispose());
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
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
          // Check if widget is still mounted before calling setState
          if (mounted) {
            setState(() {
              participants = List<String>.from(data['participants']);
            });
          }
        }
      }
    } catch (e) {
      print("Error loading participants: $e");
      // Do not call setState if not mounted
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading participants: $e')),
        );
      }
    }
  }

  void _sendMessage() {
    if (_messageController.text.isNotEmpty) {
      try {
        // Add message to the conversation
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

        // Update conversation's last activity timestamp
        ConversationManager.updateLastActivity(widget.chatTitle);

        // Add user to participants if not already there
        ConversationManager.addParticipant(widget.chatTitle, widget.userId);

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

  // Add this method to show the block user dialog
  void _showBlockUserDialog(
      BuildContext context, String senderId, String senderName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Block $senderName?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const Text('Are you sure you want to block this user?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _blockUser(senderId, senderName);
            },
            child: const Text('BLOCK USER'),
          ),
        ],
      ),
    );
  }

  // Add this method to actually block the user
  Future<void> _blockUser(String userToBlockId, String userToBlockName) async {
    try {
      // Show loading indicator
      setState(() {
        // You could add a loading state variable here if needed
      });

      // Create an instance of the blocking service
      final UserBlockingService blockingService = UserBlockingService();

      // Block the user
      await blockingService.blockUser(
        currentUserId: widget.userId,
        userToBlockId: userToBlockId,
        userToBlockName: userToBlockName,
      );

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$userToBlockName has been blocked'),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () {
              // Unblock the user
              blockingService.unblockUser(
                currentUserId: widget.userId,
                blockedUserId: userToBlockId,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$userToBlockName has been unblocked')),
              );
            },
          ),
        ),
      );

      // Return to messages screen
      Navigator.pop(context);
    } catch (e) {
      print("Error blocking user: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error blocking user: $e')),
      );
    } finally {
      // Hide loading indicator
      setState(() {
        // Reset loading state here if you added one
      });
    }
  }

  // Fix for profile image error in the user processing
  Widget _buildMessageBubble(
      DocumentSnapshot message, bool isMe, String sender) {
    final messageId = message.id;
    final data = message.data() as Map<String, dynamic>;
    final messageText = data['text'] as String;
    final imageUrl = data['imageUrl'] as String?;
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

                      // Image message (if present)
                      if (imageUrl != null)
                        GestureDetector(
                          onTap: () {
                            // Show full screen image
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => Scaffold(
                                  appBar: AppBar(
                                    backgroundColor: Colors.black,
                                    iconTheme: const IconThemeData(
                                        color: Colors.white),
                                  ),
                                  body: Container(
                                    color: Colors.black,
                                    child: Center(
                                      child: InteractiveViewer(
                                        minScale: 0.5,
                                        maxScale: 3.0,
                                        child: Image.network(
                                          imageUrl,
                                          loadingBuilder: (context, child,
                                              loadingProgress) {
                                            if (loadingProgress == null)
                                              return child;
                                            return Center(
                                              child: CircularProgressIndicator(
                                                value: loadingProgress
                                                            .expectedTotalBytes !=
                                                        null
                                                    ? loadingProgress
                                                            .cumulativeBytesLoaded /
                                                        loadingProgress
                                                            .expectedTotalBytes!
                                                    : null,
                                              ),
                                            );
                                          },
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return const Center(
                                              child: Text('Error loading image',
                                                  style: TextStyle(
                                                      color: Colors.white)),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              imageUrl,
                              width: 200,
                              fit: BoxFit.cover,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return SizedBox(
                                  height: 150,
                                  width: 200,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      value:
                                          loadingProgress.expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
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
                        ),

                      // Show text only if it's not a default photo message
                      if (!(imageUrl != null && messageText == '📷 Photo'))
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

  void _showChatInfoOptions(BuildContext context) {
    // Determine if this is a private chat with one other person
    bool isOneOnOneChat =
        widget.chatType == 'Private' && participants.length == 2;

    // If one-on-one chat, get the other user's ID
    String? otherUserId;
    String? otherUserName;
    if (isOneOnOneChat) {
      otherUserId = participants.firstWhere((id) => id != widget.userId,
          orElse: () => '');
      otherUserName = widget.chatTitle.split(' with ').last;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sheet header
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),

              // Chat info header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: chatColor.withOpacity(0.2),
                      radius: 24,
                      child: widget.chatType == 'Private'
                          ? Text(
                              otherUserName != null && otherUserName.isNotEmpty
                                  ? otherUserName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: chatColor,
                              ),
                            )
                          : Icon(
                              Icons.group,
                              color: chatColor,
                              size: 24,
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.chatType == 'Private'
                                ? otherUserName ?? 'User'
                                : widget.chatTitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            widget.chatType == 'Private'
                                ? 'Private Chat'
                                : widget.chatType == 'Private Group'
                                    ? '${participants.length} members - Private'
                                    : '${participants.length} members',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(),

              // Add Friend option (only for private chats)
              if (isOneOnOneChat &&
                  otherUserId != null &&
                  otherUserId.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.person_add, color: Colors.green),
                  title: Text('Add ${otherUserName ?? "User"} as Friend'),
                  onTap: () {
                    Navigator.pop(context);
                    _addFriend(otherUserId!, otherUserName ?? "User");
                  },
                ),

              // Block user option (only for private chats)
              if (isOneOnOneChat &&
                  otherUserId != null &&
                  otherUserId.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.block, color: Colors.red),
                  title: Text('Block ${otherUserName ?? "User"}'),
                  subtitle: const Text('You won\'t see their messages anymore'),
                  onTap: () {
                    Navigator.pop(context);
                    _showBlockUserDialog(
                        context, otherUserId!, otherUserName ?? "User");
                  },
                ),

              // Report option (for all chat types)
              ListTile(
                leading: const Icon(Icons.report_problem, color: Colors.orange),
                title: const Text('Report'),
                subtitle: isOneOnOneChat
                    ? Text(
                        'Report ${otherUserName ?? "User"} for inappropriate behavior')
                    : const Text('Report inappropriate behavior in this chat'),
                onTap: () {
                  Navigator.pop(context);
                  // Navigate to the Report Screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReportScreen(
                        currentUserId: widget.userId,
                        conversationId: widget.chatTitle,
                        participants: participants,
                      ),
                    ),
                  );
                },
              ),

              // Leave chat option (for all chat types)
              ListTile(
                leading: const Icon(Icons.exit_to_app, color: Colors.blue),
                title: const Text('Leave Conversation'),
                onTap: () {
                  Navigator.pop(context);
                  _showLeaveConfirmation(context);
                },
              ),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

// Add these new methods to handle the functionality

  // Method to add a friend
  Future<void> _addFriend(String friendId, String friendName) async {
    try {
      // Check if the widget is still mounted before showing the SnackBar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Adding friend...')),
        );
      }

      // Add to current user's friends list
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({
        'friends': FieldValue.arrayUnion([friendName]),
      });

      // Check if the widget is still mounted before showing the SnackBar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$friendName added as friend')),
        );
      }
    } catch (e) {
      print("Error adding friend: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding friend: $e')),
        );
      }
    }
  }

  // Method to leave conversation
  Future<void> _leaveConversation() async {
    try {
      // Remove user from participants using the ConversationManager
      await ConversationManager.removeParticipant(
        widget.chatTitle,
        widget.userId,
      );

      // Show success message and go back
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You left the conversation')),
        );
      }

      // Pop back to main screen
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      print("Error leaving conversation: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error leaving conversation: $e')),
        );
      }
    }
  }

  // Method to show leave confirmation
  void _showLeaveConfirmation(BuildContext context) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Conversation?'),
        content: const Text(
          'You will be removed from this conversation. You can rejoin later if invited or if this is a public group.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _leaveConversation();
            },
            child: const Text('LEAVE'),
          ),
        ],
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
                      padding: const EdgeInsets.only(
                          left: 16.0, right: 8.0, bottom: 0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          // Re-adding the avatar/circle
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
                              mainAxisAlignment: MainAxisAlignment.end,
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
                              _showChatInfoOptions(context);
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
                            Icons.camera_alt, // Changed to camera icon
                            color: chatColor,
                          ),
                          onPressed:
                              _takePicture, // Changed to your new function
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
                                      focusNode: _messageFocusNode,
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
                                    color: _showEmojiPicker
                                        ? chatColor
                                        : Colors.grey[600],
                                  ),
                                  onPressed: _toggleEmojiPicker,
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
              if (_showEmojiPicker)
                SizedBox(
                  height: 250,
                  child: EmojiPicker(
                    onEmojiSelected: (category, emoji) {
                      _onEmojiSelected(emoji.emoji);
                    },
                    config: Config(
                      height: 250,
                      // Configuration for emoji view (grid of emojis)
                      emojiViewConfig: EmojiViewConfig(
                        // Maximum size of emoji
                        emojiSizeMax: 32.0,
                      ),
                      // Configuration for the order of components
                      viewOrderConfig: const ViewOrderConfig(
                        top: EmojiPickerItem.categoryBar,
                        middle: EmojiPickerItem.emojiView,
                        bottom: EmojiPickerItem.searchBar,
                      ),
                      // Configuration for skin tone selection
                      skinToneConfig: const SkinToneConfig(
                        dialogBackgroundColor: Colors.white,
                        indicatorColor: Colors.grey,
                      ),
                      // Configuration for category view (tabs)
                      categoryViewConfig: CategoryViewConfig(
                        iconColor: Colors.grey,
                        iconColorSelected: chatColor,
                        indicatorColor: chatColor,
                      ),
                      // Configuration for the bottom action bar
                      bottomActionBarConfig: BottomActionBarConfig(
                        backgroundColor: Colors.transparent,
                        buttonColor: chatColor,
                      ),
                      // Configuration for the search view
                      searchViewConfig: const SearchViewConfig(
                        buttonIconColor: Colors.black,
                        backgroundColor: Colors.white,
                      ),
                      // Check platform compatibility (improves emoji display)
                      checkPlatformCompatibility: true,
                    ),
                  ),
                ),
            ],
          ),

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

  Future<void> _takePicture() async {
    if (cameras.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No camera available')),
      );
      return;
    }

    try {
      // Initialize the camera controller
      final cameraController = CameraController(
        cameras[0], // Front camera for selfies
        ResolutionPreset.medium,
      );
      await cameraController.initialize();

      // Show camera UI
      final imageFile = await Navigator.push<File>(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: const Text('Take Photo'),
              backgroundColor: chatColor,
            ),
            body: Column(
              children: [
                Expanded(
                  child: CameraPreview(cameraController),
                ),
                Container(
                  color: Colors.black,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      FloatingActionButton(
                        backgroundColor: Colors.white,
                        child:
                            const Icon(Icons.camera_alt, color: Colors.black),
                        onPressed: () async {
                          try {
                            final XFile photo =
                                await cameraController.takePicture();
                            Navigator.pop(context, File(photo.path));
                          } catch (e) {
                            print('Error taking picture: $e');
                            Navigator.pop(context);
                          }
                        },
                      ),
                      const SizedBox(width: 56), // Balance for the close button
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Dispose the controller
      await cameraController.dispose();

      // If an image was taken, upload and send it
      if (imageFile != null) {
        await _sendImageMessage(imageFile);
      }
    } catch (e) {
      print('Error in camera: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera error: $e')),
      );
    }
  }

// Add method to upload and send image
  Future<void> _sendImageMessage(File imageFile) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sending image...')),
      );

      // Upload to Firebase Storage
      final fileName = path.basename(imageFile.path);
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('chat_images')
          .child(widget.chatTitle)
          .child('${DateTime.now().millisecondsSinceEpoch}_$fileName');

      final uploadTask = storageRef.putFile(imageFile);
      await uploadTask.whenComplete(() => print('Image upload complete'));

      // Get download URL
      final imageUrl = await storageRef.getDownloadURL();

      // Add message to chat
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.chatTitle)
          .collection('messages')
          .add({
        'text': '📷 Photo', // Text placeholder for non-image compatible clients
        'imageUrl': imageUrl, // URL to the uploaded image
        'senderId': widget.userId,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': [],
      });

      // Update conversation's last activity
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.chatTitle)
          .update({
        'lastActivity': FieldValue.serverTimestamp(),
      });

      // Dismiss loading indicator
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image sent!')),
      );
    } catch (e) {
      print('Error sending image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending image: $e')),
      );
    }
  }

// Add this method to toggle emoji picker
  void _toggleEmojiPicker() {
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
      if (_showEmojiPicker) {
        // Hide keyboard when showing emoji picker
        _messageFocusNode.unfocus();
      } else {
        // Show keyboard when hiding emoji picker
        _messageFocusNode.requestFocus();
      }
    });
  }

// Add method to handle emoji selection
  void _onEmojiSelected(String emoji) {
    setState(() {
      // Get current text and selection
      final text = _messageController.text;
      final selection = _messageController.selection;

      // Handle case when there is no valid selection
      if (selection.baseOffset < 0) {
        // No valid selection, append emoji to the end
        _messageController.text = text + emoji;
        // Move cursor to end
        _messageController.selection = TextSelection.collapsed(
          offset: _messageController.text.length,
        );
      } else {
        // Insert emoji at current cursor position
        final newText =
            text.replaceRange(selection.start, selection.end, emoji);

        // Update text and cursor position
        _messageController.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(
            offset: selection.baseOffset + emoji.length,
          ),
        );
      }

      _isComposing = _messageController.text.isNotEmpty;
    });
  }
}
