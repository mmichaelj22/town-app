import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import '../utils/conversation_manager.dart';
import '../utils/blocking_utils.dart';
import '../widgets/custom_header.dart';

class MessagesScreen extends StatefulWidget {
  final String userId;

  const MessagesScreen({super.key, required this.userId});

  @override
  _MessagesScreenState createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<DocumentSnapshot>? _filteredConversations;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Load conversations when screen initializes
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      // Get all conversations where user is a participant
      final snapshot = await FirebaseFirestore.instance
          .collection('conversations')
          .where('participants', arrayContains: widget.userId)
          .get();

      // Apply visibility filter
      final List<DocumentSnapshot> visibleConversations =
          snapshot.docs.where((doc) {
        try {
          return ConversationManager.shouldShowOnMessagesScreen(
            userId: widget.userId,
            conversation: doc,
          );
        } catch (e) {
          print("Error checking visibility for ${doc.id}: $e");
          return false;
        }
      }).toList();

      // Filter out conversations with blocked users
      final filteredConversations =
          await BlockingUtils.filterConversationsWithBlockedUsers(
        currentUserId: widget.userId,
        conversations: visibleConversations,
      );

      // Sort by most recent activity
      filteredConversations.sort((a, b) {
        Timestamp? aLastActivity;
        Timestamp? bLastActivity;

        // Safely access lastActivity field
        try {
          final aData = a.data() as Map<String, dynamic>?;
          if (aData != null && aData.containsKey('lastActivity')) {
            aLastActivity = aData['lastActivity'] as Timestamp?;
          }
        } catch (e) {
          print("Error accessing lastActivity for document ${a.id}: $e");
        }

        try {
          final bData = b.data() as Map<String, dynamic>?;
          if (bData != null && bData.containsKey('lastActivity')) {
            bLastActivity = bData['lastActivity'] as Timestamp?;
          }
        } catch (e) {
          print("Error accessing lastActivity for document ${b.id}: $e");
        }

        if (aLastActivity == null && bLastActivity == null) {
          return 0;
        } else if (aLastActivity == null) {
          return 1;
        } else if (bLastActivity == null) {
          return -1;
        }

        return bLastActivity.compareTo(aLastActivity);
      });

      setState(() {
        _filteredConversations = filteredConversations;
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading conversations: $e");
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  Future<List<String>> _getFriends() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('friends')) {
          return List<String>.from(data['friends']);
        }
      }
      print("No friends data found for user ${widget.userId}");
      return [];
    } catch (e) {
      print("Error getting friends: $e");
      return [];
    }
  }

  Future<String> _getLastMessage(String conversationId) async {
    try {
      final messagesSnapshot = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (messagesSnapshot.docs.isNotEmpty) {
        String messageText =
            messagesSnapshot.docs.first['text'] ?? 'No message';

        // Remove "Group created: " prefix if present
        if (messageText.startsWith("Group created: ")) {
          messageText = messageText.substring("Group created: ".length);
        }

        return messageText;
      }
    } catch (e) {
      print("Error getting last message: $e");
    }
    return 'No messages yet';
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final now = DateTime.now();
    final messageTime = timestamp.toDate();
    final difference = now.difference(messageTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${messageTime.month}/${messageTime.day}';
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.message_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No conversations yet',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start a new conversation from the home screen',
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'Error loading conversations',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Unknown error',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadConversations,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print("Building MessagesScreen for user: ${widget.userId}");

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: _loadConversations,
        child: CustomScrollView(
          slivers: [
            // Custom gradient header
            CustomHeader(
              title: 'Messages',
              subtitle: 'Your conversations',
              primaryColor: AppTheme.green,
            ),

            // Messages list or appropriate state
            SliverFillRemaining(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _hasError
                      ? _buildErrorState()
                      : _filteredConversations == null ||
                              _filteredConversations!.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: _filteredConversations!.length,
                              itemBuilder: (context, index) {
                                var doc = _filteredConversations![index];
                                String conversationId = doc.id;
                                Map<String, dynamic> data =
                                    doc.data() as Map<String, dynamic>;

                                String type = data['type'] ?? 'Group';
                                List<dynamic> participants =
                                    data['participants'] ?? [];

                                // Get the display name for user chat partner
                                String displayName = type == 'Private'
                                    ? participants
                                        .firstWhere((id) => id != widget.userId,
                                            orElse: () => 'Unknown')
                                        .toString()
                                    : conversationId;

                                // Get color based on index
                                Color tileColor = AppTheme.squareColors[
                                    index % AppTheme.squareColors.length];

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                      horizontal: 4), // Space between items
                                  child: Dismissible(
                                    key: Key(conversationId),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 20),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.delete,
                                        color: Colors.white,
                                      ),
                                    ),
                                    confirmDismiss: (direction) async {
                                      return await showDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return AlertDialog(
                                            title: const Text("Confirm"),
                                            content: const Text(
                                                "Are you sure you want to delete this conversation?"),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(context)
                                                        .pop(false),
                                                child: const Text("CANCEL"),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(context)
                                                        .pop(true),
                                                child: const Text("DELETE",
                                                    style: TextStyle(
                                                        color: Colors.red)),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                    onDismissed: (direction) {
                                      // Remove the user from the conversation participants
                                      FirebaseFirestore.instance
                                          .collection('conversations')
                                          .doc(conversationId)
                                          .update({
                                        'participants': FieldValue.arrayRemove(
                                            [widget.userId]),
                                      });

                                      // Show a snackbar
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content:
                                              Text('Removed from conversation'),
                                          action: SnackBarAction(
                                            label: 'UNDO',
                                            onPressed: () {
                                              // Add the user back to participants
                                              FirebaseFirestore.instance
                                                  .collection('conversations')
                                                  .doc(conversationId)
                                                  .update({
                                                'participants':
                                                    FieldValue.arrayUnion(
                                                        [widget.userId]),
                                              });
                                              // Reload conversations
                                              _loadConversations();
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                    child: Card(
                                      elevation: 2,
                                      margin: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: tileColor,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: ListTile(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 16, vertical: 6),
                                          leading: CircleAvatar(
                                            backgroundColor: tileColor
                                                        .computeLuminance() >
                                                    0.5
                                                ? Colors.black.withOpacity(0.1)
                                                : Colors.white.withOpacity(0.8),
                                            child: type == 'Private'
                                                ? Text(
                                                    displayName.isNotEmpty
                                                        ? displayName[0]
                                                            .toUpperCase()
                                                        : '?',
                                                    style: TextStyle(
                                                      color: tileColor
                                                                  .computeLuminance() >
                                                              0.5
                                                          ? Colors.black
                                                          : tileColor,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  )
                                                : Icon(
                                                    Icons.group,
                                                    color: tileColor
                                                                .computeLuminance() >
                                                            0.5
                                                        ? Colors.black
                                                        : tileColor,
                                                  ),
                                          ),

                                          // Directly use the message as the title
                                          title: FutureBuilder<String>(
                                              future: _getLastMessage(
                                                  conversationId),
                                              builder: (context,
                                                  lastMessageSnapshot) {
                                                String messageText =
                                                    lastMessageSnapshot.data ??
                                                        'Loading...';

                                                // We already strip "Group created:" in _getLastMessage

                                                return Text(
                                                  messageText,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.normal,
                                                    fontSize: 15,
                                                    color: tileColor
                                                                .computeLuminance() >
                                                            0.5
                                                        ? Colors.black
                                                        : Colors.white,
                                                  ),
                                                );
                                              }),

                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Show the contact name for private chats, or member count for group chats
                                              if (type == 'Private')
                                                Text(
                                                  displayName,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: tileColor
                                                                .computeLuminance() >
                                                            0.5
                                                        ? Colors.black
                                                            .withOpacity(0.8)
                                                        : Colors.white
                                                            .withOpacity(0.9),
                                                  ),
                                                )
                                              else
                                                Row(
                                                  children: [
                                                    if (type == 'Private Group')
                                                      const Text('🔒 ',
                                                          style: TextStyle(
                                                              fontSize: 12)),
                                                    Text(
                                                      participants.length == 1
                                                          ? '1 member'
                                                          : '${participants.length} members',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: tileColor
                                                                    .computeLuminance() >
                                                                0.5
                                                            ? Colors.black
                                                                .withOpacity(
                                                                    0.6)
                                                            : Colors.white
                                                                .withOpacity(
                                                                    0.8),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                            ],
                                          ),

                                          trailing:
                                              FutureBuilder<QuerySnapshot>(
                                            future: FirebaseFirestore.instance
                                                .collection('conversations')
                                                .doc(conversationId)
                                                .collection('messages')
                                                .orderBy('timestamp',
                                                    descending: true)
                                                .limit(1)
                                                .get(),
                                            builder:
                                                (context, messageSnapshot) {
                                              if (!messageSnapshot.hasData ||
                                                  messageSnapshot
                                                      .data!.docs.isEmpty) {
                                                return const SizedBox.shrink();
                                              }

                                              var message = messageSnapshot
                                                  .data!.docs.first;
                                              Timestamp? timestamp =
                                                  message['timestamp'];

                                              return Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: tileColor
                                                              .computeLuminance() >
                                                          0.5
                                                      ? Colors.black
                                                          .withOpacity(0.1)
                                                      : Colors.white
                                                          .withOpacity(0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  _formatTimestamp(timestamp),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: tileColor
                                                                .computeLuminance() >
                                                            0.5
                                                        ? Colors.black
                                                        : Colors.white,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    ChatScreen(
                                                  userId: widget.userId,
                                                  chatTitle: conversationId,
                                                  chatType: type,
                                                ),
                                              ),
                                            ).then((_) {
                                              // Refresh conversations when returning from chat
                                              _loadConversations();
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
