import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import '../utils/conversation_manager.dart';
import '../widgets/custom_header.dart';
import '../services/message_tracker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../widgets/message_list_tile.dart';

class MessagesScreen extends StatefulWidget {
  final String userId;
  final MessageTracker messageTracker;

  const MessagesScreen({
    super.key,
    required this.userId,
    required this.messageTracker,
  });

  @override
  _MessagesScreenState createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  StreamSubscription? _conversationsSubscription;
  List<QueryDocumentSnapshot> _conversations = [];
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, int> _unreadCounts = {};
  String _currentFilter = 'Private'; // Default to Private chats

  @override
  void initState() {
    super.initState();
    _setupFirestoreListener();
  }

  void _setupFirestoreListener() {
    // Cancel existing subscription
    _conversationsSubscription?.cancel();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Set up listener with error handling
    _conversationsSubscription = FirebaseFirestore.instance
        .collection('conversations')
        .where('participants', arrayContains: widget.userId)
        .snapshots()
        .handleError((error) {
      print("Firestore error: $error");
      setState(() {
        _isLoading = false;
        _errorMessage = "Couldn't load messages: $error";
      });
    }).listen((snapshot) {
      _processConversationsSnapshot(snapshot);
    });
  }

  Widget _buildFilterUI() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Slider on the left (1/3 width)
          Expanded(
            flex: 1,
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppTheme.green.withOpacity(0.2),
                  inactiveTrackColor: Colors.grey[300],
                  thumbColor: AppTheme.green,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 12.0,
                  ),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 16.0),
                  trackHeight: 8.0,
                  overlayColor: AppTheme.blue.withOpacity(0.2),
                ),
                child: Slider(
                  value: _getValueForFilter(_currentFilter),
                  min: 0,
                  max: 2,
                  divisions: 2,
                  onChanged: (value) {
                    String newFilter = _getFilterForValue(value);
                    if (newFilter != _currentFilter) {
                      setState(() {
                        _currentFilter = newFilter;
                      });
                      // Re-process conversations with the new filter
                      _conversationsSubscription?.cancel();
                      _setupFirestoreListener();
                    }
                  },
                ),
              ),
            ),
          ),

          // Icons in the middle (1/3 width)
          Expanded(
            flex: 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildFilterIcon(
                    Icons.person, _currentFilter == 'Private', 'Private'),
                const SizedBox(width: 8),
                _buildFilterIcon(Icons.lock, _currentFilter == 'Private Group',
                    'Private Group'),
                const SizedBox(width: 8),
                _buildFilterIcon(
                    Icons.group, _currentFilter == 'Group', 'Group'),
              ],
            ),
          ),

          // Text label on the right (1/3 width)
          Expanded(
            flex: 1,
            child: Container(
              alignment: Alignment.center,
              child: Text(
                _getLabelForFilter(_currentFilter),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to get the label for a filter
  String _getLabelForFilter(String filter) {
    switch (filter) {
      case 'Private':
        return 'Private Chat';
      case 'Private Group':
        return 'Private Group';
      case 'Group':
        return 'Public Group';
      default:
        return '';
    }
  }

  // Helper method to build a filter icon
  Widget _buildFilterIcon(IconData icon, bool isActive, String filterType) {
    // Determine the color based on the filter type
    Color iconColor;
    if (filterType == 'Private') {
      iconColor = AppTheme.coral; // Theme red for Private Chat
    } else if (filterType == 'Private Group') {
      iconColor = AppTheme.orange; // Theme orange for Private Group
    } else {
      iconColor = AppTheme.blue; // Theme blue for Public Group
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isActive ? iconColor : Colors.grey[300],
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: isActive ? Colors.white : Colors.grey[600],
        size: 16,
      ),
    );
  }

  // Helper method to get the slider value for a filter
  double _getValueForFilter(String filter) {
    switch (filter) {
      case 'Private':
        return 0;
      case 'Private Group':
        return 1;
      case 'Group':
        return 2;
      default:
        return 0;
    }
  }

  // Helper method to get the filter for a slider value
  String _getFilterForValue(double value) {
    if (value < 0.5) {
      return 'Private';
    } else if (value < 1.5) {
      return 'Private Group';
    } else {
      return 'Group';
    }
  }

  Future<void> _processConversationsSnapshot(QuerySnapshot snapshot) async {
    if (!mounted) return;

    try {
      // Filter conversations based on visibility rule and current filter
      List<QueryDocumentSnapshot> visibleConversations =
          snapshot.docs.where((doc) {
        bool isVisible = ConversationManager.shouldShowOnMessagesScreen(
          userId: widget.userId,
          conversation: doc,
        );

        if (!isVisible) return false;

        // Apply type filter
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) return false;

        final type = data['type'] as String? ?? 'Group';
        return type == _currentFilter; // Always filter by current filter
      }).toList();

      // Process unread counts efficiently
      await _updateUnreadCounts(visibleConversations);

      // Sort by most recent activity (with null safety)
      visibleConversations.sort((a, b) {
        // Extract timestamps safely
        final aTimestamp = _getLastActivityTimestamp(a);
        final bTimestamp = _getLastActivityTimestamp(b);

        if (aTimestamp == null && bTimestamp == null) return 0;
        if (aTimestamp == null) return 1; // Null timestamps at end
        if (bTimestamp == null) return -1;

        return bTimestamp.compareTo(aTimestamp);
      });

      if (mounted) {
        setState(() {
          _conversations = visibleConversations;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error processing conversations: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Error loading messages: $e";
        });
      }
    }
  }

  // Helper method to get timestamp safely
  Timestamp? _getLastActivityTimestamp(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>?;
      return data?['lastActivity'] as Timestamp?;
    } catch (e) {
      return null;
    }
  }

  // Efficiently batch process unread counts
  Future<void> _updateUnreadCounts(
      List<QueryDocumentSnapshot> conversations) async {
    final Map<String, int> counts = {};

    // Process in small batches to avoid UI jank
    for (int i = 0; i < conversations.length; i += 5) {
      final batch = conversations.skip(i).take(5);

      await Future.wait(batch.map((conversation) async {
        final conversationId = conversation.id;
        try {
          counts[conversationId] = await _getUnreadCount(conversationId);
        } catch (e) {
          print("Error counting unread for $conversationId: $e");
          counts[conversationId] = 0;
        }
      }));

      // Update state periodically to show progress
      if (mounted && i + 5 < conversations.length) {
        setState(() {
          _unreadCounts = Map.from(_unreadCounts)..addAll(counts);
        });
      }
    }

    if (mounted) {
      setState(() {
        _unreadCounts = counts;
      });
    }
  }

  @override
  void dispose() {
    _conversationsSubscription?.cancel();
    super.dispose();
  }

  // Get unread message count for a conversation
  Future<int> _getUnreadCount(String conversationId) async {
    try {
      // Get the last read timestamp for this conversation
      final prefs = await SharedPreferences.getInstance();
      final timestampStr =
          prefs.getString('last_read_${widget.userId}_$conversationId');
      Timestamp lastReadTimestamp = Timestamp(0, 0);

      if (timestampStr != null) {
        final parts = timestampStr.split('_');
        if (parts.length == 2) {
          final seconds = int.parse(parts[0]);
          final nanoseconds = int.parse(parts[1]);
          lastReadTimestamp = Timestamp(seconds, nanoseconds);
        }
      }

      // Count messages newer than the last read timestamp and not from current user
      final querySnapshot = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .where('timestamp', isGreaterThan: lastReadTimestamp)
          .where('senderId', isNotEqualTo: widget.userId)
          .get();

      return querySnapshot.docs.length;
    } catch (e) {
      print("Error getting unread count: $e");
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Custom gradient header
          CustomHeader(
            title: 'Messages',
            subtitle: 'Your conversations',
            primaryColor: AppTheme.green,
          ),

          // Add filter UI
          SliverToBoxAdapter(
            child: _buildFilterUI(),
          ),

          // Error message if needed
          if (_errorMessage != null)
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.all(16),
                color: Colors.red.shade100,
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _setupFirestoreListener,
                      tooltip: 'Try again',
                    ),
                  ],
                ),
              ),
            ),

          // Loading, empty state, or message list
          _isLoading
              ? const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              : _conversations.isEmpty
                  ? SliverFillRemaining(
                      child: _buildEmptyState(),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final conversation = _conversations[index];
                          final conversationId = conversation.id;

                          return Dismissible(
                            key: Key(conversationId),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20.0),
                              color: Colors.red,
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),
                            onDismissed: (direction) {
                              // Delete the conversation from Firestore
                              FirebaseFirestore.instance
                                  .collection('conversations')
                                  .doc(conversationId)
                                  .delete()
                                  .then((_) {
                                // Also delete any messages in the conversation subcollection
                                FirebaseFirestore.instance
                                    .collection('conversations')
                                    .doc(conversationId)
                                    .collection('messages')
                                    .get()
                                    .then((snapshot) {
                                  for (DocumentSnapshot doc in snapshot.docs) {
                                    doc.reference.delete();
                                  }
                                });

                                // Show success message
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Conversation deleted'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              }).catchError((error) {
                                print("Error deleting conversation: $error");
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'Error deleting conversation: $error')),
                                );
                              });
                            },
                            child: MessageListTile(
                              conversation: conversation,
                              currentUserId: widget.userId,
                              unreadCount: _unreadCounts[conversationId] ?? 0,
                              onTap: () {
                                final data = conversation.data()
                                    as Map<String, dynamic>?;
                                final type =
                                    data?['type'] as String? ?? 'Group';

                                // Mark conversation as read
                                widget.messageTracker
                                    .markConversationAsRead(conversationId);

                                // Navigate to chat screen
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatScreen(
                                      userId: widget.userId,
                                      chatTitle: conversationId,
                                      chatType: type,
                                      messageTracker: widget.messageTracker,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                        childCount: _conversations.length,
                      ),
                    ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    String message = '';

    switch (_currentFilter) {
      case 'Private':
        message = 'No private chats yet';
        break;
      case 'Private Group':
        message = 'No private group conversations yet';
        break;
      case 'Group':
        message = 'No public group conversations yet';
        break;
      default:
        message = 'No conversations yet';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.message_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 18, color: Colors.grey),
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

  // Format timestamp for display
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
