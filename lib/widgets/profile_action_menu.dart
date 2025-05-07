// lib/widgets/profile_action_menu.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/chat_creation_service.dart';
import '../utils/user_blocking_service.dart';
import '../screens/profile_viewer_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileActionMenu extends StatelessWidget {
  final String currentUserId;
  final String userId;
  final String userName;
  final bool isFriend;
  final bool hasSentRequest;
  final bool hasReceivedRequest;
  final bool canViewProfile; // Add this new property
  final Function? onFriendRequestSent;
  final Function? onFriendRequestAccepted;
  final Function? onUserBlocked;

  const ProfileActionMenu({
    Key? key,
    required this.currentUserId,
    required this.userId,
    required this.userName,
    this.isFriend = false,
    this.hasSentRequest = false,
    this.hasReceivedRequest = false,
    this.canViewProfile = false, // Default to false for safety
    this.onFriendRequestSent,
    this.onFriendRequestAccepted,
    this.onUserBlocked,
  }) : super(key: key);

  // Method to show the menu options
  static Future<void> show({
    required BuildContext context,
    required String currentUserId,
    required String userId,
    required String userName,
    bool isFriend = false,
    bool hasSentRequest = false,
    bool hasReceivedRequest = false,
    bool canViewProfile = false, // Add this parameter
    Function? onFriendRequestSent,
    Function? onFriendRequestAccepted,
    Function? onUserBlocked,
  }) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => ProfileActionMenu(
        currentUserId: currentUserId,
        userId: userId,
        userName: userName,
        isFriend: isFriend,
        hasSentRequest: hasSentRequest,
        hasReceivedRequest: hasReceivedRequest,
        canViewProfile: canViewProfile, // Pass the parameter
        onFriendRequestSent: onFriendRequestSent,
        onFriendRequestAccepted: onFriendRequestAccepted,
        onUserBlocked: onUserBlocked,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.blue.withOpacity(0.2),
                  child: Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.blue),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isFriend ? 'Friend' : 'Nearby',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(),

          // Action options
          if (isFriend)
            _buildFriendOptions(context)
          else
            _buildNearbyOptions(context),

          // Common options for both friend and nearby
          _buildCommonOptions(context),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // Options shown when viewing a friend's profile
  Widget _buildFriendOptions(BuildContext context) {
    return Column(
      children: [
        // View Profile option - always show for friends
        _buildOptionTile(
          context: context,
          icon: Icons.person,
          iconColor: AppTheme.blue,
          title: 'View Profile',
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProfileViewerScreen(
                  currentUserId: currentUserId,
                  userId: userId,
                  userName: userName,
                ),
              ),
            );
          },
        ),

        // Private Chat option
        _buildOptionTile(
          context: context,
          icon: Icons.chat_bubble_outline,
          iconColor: AppTheme.green,
          title: 'Private Chat',
          onTap: () {
            Navigator.pop(context);
            _startPrivateChat(context);
          },
        ),
      ],
    );
  }

  // Options shown when viewing a nearby user who is not a friend
  Widget _buildNearbyOptions(BuildContext context) {
    return Column(
      children: [
        // View Profile option - only show if profile is public or user is a friend
        if (canViewProfile)
          _buildOptionTile(
            context: context,
            icon: Icons.person,
            iconColor: AppTheme.blue,
            title: 'View Profile',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileViewerScreen(
                    currentUserId: currentUserId,
                    userId: userId,
                    userName: userName,
                  ),
                ),
              );
            },
          ),

        // Send Friend Request option
        if (!isFriend && !hasSentRequest && !hasReceivedRequest)
          _buildOptionTile(
            context: context,
            icon: Icons.person_add_outlined,
            iconColor: AppTheme.blue,
            title: 'Send Friend Request',
            onTap: () {
              Navigator.pop(context);
              _sendFriendRequest(context);
            },
          ),

        // Accept Friend Request option
        if (hasReceivedRequest)
          _buildOptionTile(
            context: context,
            icon: Icons.check_circle_outline,
            iconColor: AppTheme.green,
            title: 'Accept Friend Request',
            onTap: () {
              Navigator.pop(context);
              _acceptFriendRequest(context);
            },
          ),

        // Request Sent indicator
        if (hasSentRequest)
          _buildOptionTile(
            context: context,
            icon: Icons.hourglass_empty,
            iconColor: Colors.grey,
            title: 'Friend Request Sent',
            subtitle: 'Waiting for response',
            enabled: false,
            onTap: () {},
          ),

        // Private Chat option - available for nearby users too
        _buildOptionTile(
          context: context,
          icon: Icons.chat_bubble_outline,
          iconColor: AppTheme.green,
          title: 'Private Chat',
          onTap: () {
            Navigator.pop(context);
            _startPrivateChat(context);
          },
        ),
      ],
    );
  }

  // Common options for both friend and nearby users
  Widget _buildCommonOptions(BuildContext context) {
    return Column(
      children: [
        // Block option
        _buildOptionTile(
          context: context,
          icon: Icons.block,
          iconColor: Colors.red,
          title: 'Block User',
          onTap: () {
            Navigator.pop(context);
            _blockUser(context);
          },
        ),

        // Report option
        _buildOptionTile(
          context: context,
          icon: Icons.report_outlined,
          iconColor: Colors.orange,
          title: 'Report User',
          onTap: () {
            Navigator.pop(context);
            _reportUser(context);
          },
        ),
      ],
    );
  }

  // Helper to build a consistent option tile
  Widget _buildOptionTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    bool enabled = true,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: enabled ? Colors.black : Colors.grey,
        ),
      ),
      subtitle: subtitle != null ? Text(subtitle) : null,
      enabled: enabled,
      onTap: enabled ? onTap : null,
    );
  }

  // Action implementations
  void _startPrivateChat(BuildContext context) {
    // Use the ChatCreationService to start or navigate to an existing chat
    ChatCreationService.startPrivateChat(
      context: context,
      currentUserId: currentUserId,
      recipientId: userId,
      recipientName: userName,
    );
  }

  void _sendFriendRequest(BuildContext context) async {
    try {
      // Add recipient to the sender's sentFriendRequests
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .update({
        'sentFriendRequests': FieldValue.arrayUnion([userId]),
      });

      // Add sender to recipient's pendingFriendRequests
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'pendingFriendRequests': FieldValue.arrayUnion([currentUserId]),
      });

      // Get current user name for the notification
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();

      final userData = userDoc.data();
      final String senderName = userData != null && userData.containsKey('name')
          ? userData['name'] as String
          : 'Someone';

      // Add a notification for the recipient
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'type': 'friendRequest',
        'senderId': currentUserId,
        'senderName': senderName,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      if (onFriendRequestSent != null) {
        onFriendRequestSent!();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Friend request sent to $userName')),
      );
    } catch (e) {
      print("Error sending friend request: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending friend request: $e')),
      );
    }
  }

  void _acceptFriendRequest(BuildContext context) async {
    try {
      // Get current user info
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();

      final userData = userDoc.data();
      if (userData == null) return;

      final String receiverName =
          userData.containsKey('name') ? userData['name'] as String : 'User';

      // Remove from pending requests
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .update({
        'pendingFriendRequests': FieldValue.arrayRemove([userId]),
      });

      // Remove from sent requests
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'sentFriendRequests': FieldValue.arrayRemove([currentUserId]),
      });

      // Add each user to the other's friends list
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .update({
        'friends': FieldValue.arrayUnion([
          {'id': userId, 'name': userName}
        ]),
      });

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'friends': FieldValue.arrayUnion([
          {'id': currentUserId, 'name': receiverName}
        ]),
      });

      // Add notification for the sender
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'type': 'friendRequestAccepted',
        'senderId': currentUserId,
        'senderName': receiverName,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      if (onFriendRequestAccepted != null) {
        onFriendRequestAccepted!();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You are now friends with $userName')),
      );
    } catch (e) {
      print("Error accepting friend request: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accepting friend request: $e')),
      );
    }
  }

  void _blockUser(BuildContext context) {
    // Show confirmation dialog first
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Block $userName?'),
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
            onPressed: () async {
              Navigator.pop(context);

              try {
                // Block the user
                final blockingService = UserBlockingService();
                await blockingService.blockUser(
                  currentUserId: currentUserId,
                  userToBlockId: userId,
                  userToBlockName: userName,
                );

                if (onUserBlocked != null) {
                  onUserBlocked!();
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$userName has been blocked')),
                );
              } catch (e) {
                print("Error blocking user: $e");
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error blocking user: $e')),
                );
              }
            },
            child: const Text('BLOCK USER'),
          ),
        ],
      ),
    );
  }

  void _reportUser(BuildContext context) {
    // Navigate to the report screen
    Navigator.pushNamed(context, '/report', arguments: {
      'currentUserId': currentUserId,
      'reportedUserId': userId,
      'reportedUserName': userName,
    });
  }
}
