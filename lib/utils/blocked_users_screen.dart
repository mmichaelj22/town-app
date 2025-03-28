import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_header.dart';

class BlockedUsersScreen extends StatelessWidget {
  final String userId;

  const BlockedUsersScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  Future<void> _unblockUser(BuildContext context, String blockedUserId,
      String blockedUserName) async {
    try {
      // Show confirmation dialog
      final bool confirm = await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Unblock User'),
              content:
                  Text('Are you sure you want to unblock $blockedUserName?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('CANCEL'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('UNBLOCK'),
                ),
              ],
            ),
          ) ??
          false;

      if (!confirm) return;

      // Delete from blocked_users collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('blocked_users')
          .doc(blockedUserId)
          .delete();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$blockedUserName has been unblocked')),
      );
    } catch (e) {
      print('Error unblocking user: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // Custom gradient header
          CustomHeader(
            title: 'Blocked Users',
            subtitle: 'Manage your blocked users',
            primaryColor: Colors.red,
          ),

          // Blocked users list
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('blocked_users')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.block_flipped, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No blocked users',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'When you block someone, they will appear here',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              final blockedUsers = snapshot.data!.docs;
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final blockedUser = blockedUsers[index];
                    final blockedUserId = blockedUser.id;
                    final blockedUserName =
                        blockedUser['name'] ?? 'Unknown User';
                    final blockedAt = blockedUser['blockedAt'] as Timestamp?;
                    final blockedAtString = blockedAt != null
                        ? _formatDate(blockedAt.toDate())
                        : 'Unknown date';

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 4.0,
                      ),
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.grey[200],
                            child: Text(
                              blockedUserName.isNotEmpty
                                  ? blockedUserName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                          title: Text(
                            blockedUserName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('Blocked on $blockedAtString'),
                          trailing: TextButton(
                            onPressed: () => _unblockUser(
                                context, blockedUserId, blockedUserName),
                            child: const Text(
                              'UNBLOCK',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: blockedUsers.length,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    }
  }
}
