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
import '../widgets/block_user_dialog.dart';
import '../models/chat_message.dart'; // New model class
import '../widgets/chat/message_bubble.dart'; // Extracted component
import '../widgets/chat/chat_input.dart'; // Extracted component
import '../widgets/chat/chat_header.dart'; // Extracted component
import '../services/chat_service.dart'; // New service to handle chat logic

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

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  late final ChatService _chatService;
  List<String> participants = [];
  Color chatColor = AppTheme.blue; // Default color

  // Keep these variables until fully migrated
  bool _showingLikeAnimation = false;
  final Map<String, AnimationController> _bubbleAnimations = {};

  // For supporting older functionality during migration
  // These can be removed after full migration
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _chatService = ChatService(
      chatId: widget.chatTitle,
      userId: widget.userId,
      chatType: widget.chatType,
    );

    _loadParticipants();

    // Assign a color based on chat type
    switch (widget.chatType) {
      case 'Private':
        chatColor = AppTheme.coral;
        break;
      case 'Private Group':
        chatColor = AppTheme.orange;
        break;
      default:
        chatColor = AppTheme.blue;
    }

    // Mark conversation as read when entering
    if (widget.messageTracker != null) {
      widget.messageTracker!.markConversationAsRead(widget.chatTitle);
    }

    // // Keep focus node listener for now
    // _messageFocusNode.addListener(() {
    //   if (_messageFocusNode.hasFocus && mounted) {
    //     setState(() {
    //       _showEmojiPicker = false;
    //     });
    //   }
    // });
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
      participants = await _chatService.loadParticipants();
      if (mounted) setState(() {});
    } catch (e) {
      print("Error loading participants: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading participants: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              // Custom header
              ChatHeader(
                chatTitle: widget.chatTitle,
                chatType: widget.chatType,
                chatColor: chatColor,
                participants: participants,
                onInfoTap: () => _showChatInfoOptions(context),
                onBackTap: () => Navigator.pop(context),
              ),

              // Messages list
              Expanded(
                child: _buildMessagesList(),
              ),

              // Chat input
              ChatInput(
                chatColor: chatColor,
                onSendMessage: _chatService.sendTextMessage,
                onSendImage: (File imageFile) async {
                  try {
                    await _chatService.sendImageMessage(imageFile);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error sending image: $e')),
                      );
                    }
                  }
                },
                onEmojiSelected: (emoji) {
                  // This will be handled internally by ChatInput
                },
              ),
            ],
          ),

          // Center like animation overlay - keep until fully migrated
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

  Widget _buildMessagesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _chatService.messagesStream,
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

        // Process messages and build the list
        List<Widget> messageWidgets = [];
        DateTime? currentDate;

        for (int i = 0; i < messages.length; i++) {
          final message = messages[i];
          final data = message.data() as Map<String, dynamic>;
          final timestamp = data['timestamp'] as Timestamp?;
          if (timestamp == null) continue;

          final messageDate = timestamp.toDate();
          final messageDay =
              DateTime(messageDate.year, messageDate.month, messageDate.day);

          // Add date separator if this is a new day
          if (currentDate == null ||
              !currentDate.isAtSameMomentAs(messageDay)) {
            currentDate = messageDay;
            messageWidgets.add(_buildDateSeparator(messageDate));
          }

          // Create ChatMessage model from data
          final chatMessage = ChatMessage.fromMap(data, message.id);
          final bool isMe = chatMessage.senderId == widget.userId;

          // Get sender name
          String sender = isMe ? 'You' : chatMessage.senderId;
          if (widget.chatType == 'Private') {
            sender = isMe ? 'You' : 'Friend';
          }

          // Add message bubble using extracted component
          messageWidgets.add(
            MessageBubble(
              message: chatMessage,
              isMe: isMe,
              sender: sender,
              chatColor: chatColor,
              onDoubleTap: () {
                _chatService.toggleLike(message.id, data['likes'] ?? []);
                // If you want to keep the animation effect:
                setState(() {
                  _showingLikeAnimation = true;
                });

                // Hide animation after delay
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted) {
                    setState(() {
                      _showingLikeAnimation = false;
                    });
                  }
                });
              },
              onLongPress: () => _showMessageOptions(message.id, chatMessage),
              showProfileInfo: widget.chatType != 'Private',
            ),
          );
        }

        return ListView(
          controller: _scrollController,
          reverse: true,
          padding: const EdgeInsets.all(8.0),
          children: messageWidgets,
        );
      },
    );
  }

  // Widget _buildEmptyMessagesView() {
  //   return Center(
  //     child: Column(
  //       mainAxisAlignment: MainAxisAlignment.center,
  //       children: [
  //         Icon(
  //           Icons.chat_bubble_outline,
  //           size: 64,
  //           color: Colors.grey[400],
  //         ),
  //         const SizedBox(height: 16),
  //         Text(
  //           'No messages yet',
  //           style: TextStyle(
  //             fontSize: 18,
  //             color: Colors.grey[600],
  //           ),
  //         ),
  //         const SizedBox(height: 8),
  //         Text(
  //           'Be the first to say something!',
  //           style: TextStyle(
  //             fontSize: 14,
  //             color: Colors.grey[500],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

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

  void _showMessageOptions(String messageId, ChatMessage message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Message Actions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                message.isLikedByCurrentUser(widget.userId)
                    ? Icons.thumb_down
                    : Icons.thumb_up,
                color: chatColor,
              ),
              title: Text(message.isLikedByCurrentUser(widget.userId)
                  ? 'Unlike'
                  : 'Like'),
              onTap: () {
                Navigator.pop(context);
                _chatService.toggleLike(messageId, message.likes);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.blue),
              title: const Text('Copy Text'),
              onTap: () {
                Navigator.pop(context);
                // Implement copy to clipboard
              },
            ),
          ],
        ),
      ),
    );
  }

  // void _toggleLike(String messageId, List<dynamic> currentLikes) {
  //   _chatService.toggleLike(messageId, currentLikes);
  // }

  void _showChatInfoOptions(BuildContext context) {
    // Determine if this is a private chat with one other person
    bool isOneOnOneChat =
        widget.chatType == 'Private' && participants.length == 2;

    // If one-on-one chat, get the other user's ID
    String otherUserId = "";
    String otherUserName = "";

    // Determine the other user
    if (widget.chatType == 'Private' && participants.length == 2) {
      otherUserId = participants.firstWhere((id) => id != widget.userId,
          orElse: () => '');
      // Get name from your data source - this is just a placeholder
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
                              otherUserName.isNotEmpty
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
                                ? otherUserName
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
              if (isOneOnOneChat && otherUserId.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.person_add, color: Colors.green),
                  title: Text('Add ${otherUserName} as Friend'),
                  onTap: () {
                    Navigator.pop(context);
                    _addFriend(otherUserId, otherUserName);
                  },
                ),

              // Block user option (only for private chats)
              if (isOneOnOneChat && otherUserId.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.block, color: Colors.red),
                  title: Text('Block ${otherUserName}'),
                  subtitle: const Text('You won\'t see their messages anymore'),
                  onTap: () {
                    Navigator.pop(context);
                    showBlockUserDialog(
                      context: context,
                      userId: widget.userId,
                      otherUserId: otherUserId,
                      otherUserName: otherUserName,
                      onBlockComplete: () {
                        // Any action you want to take after blocking
                        Navigator.pop(context); // For example
                      },
                    );
                  },
                ),

              // Report option (for all chat types)
              ListTile(
                leading: const Icon(Icons.report_problem, color: Colors.orange),
                title: const Text('Report'),
                subtitle: isOneOnOneChat
                    ? Text('Report ${otherUserName} for inappropriate behavior')
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
}
