import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_header.dart';
import 'chat_screen.dart';

class FriendsScreen extends StatelessWidget {
  final String userId;
  final double detectionRadius;
  final Function(String) onSelectFriend;

  const FriendsScreen({
    super.key,
    required this.userId,
    required this.detectionRadius,
    required this.onSelectFriend,
  });

  Stream<List<Map<String, dynamic>>> _getNearbyUsers(double radius) {
    return FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .map((snapshot) {
      List<Map<String, dynamic>> nearby = [];

      // Find the current user document
      DocumentSnapshot? currentUserDoc;
      try {
        currentUserDoc = snapshot.docs.firstWhere((d) => d.id == userId);
      } catch (e) {
        print("Current user not found in Firestore: $e");
        return nearby; // Return empty list if user not found
      }

      // Check if the current user has latitude and longitude
      if (!currentUserDoc.exists ||
          !currentUserDoc.data().toString().contains('latitude') ||
          !currentUserDoc.data().toString().contains('longitude')) {
        print("Current user missing location data");
        return nearby;
      }

      double userLat = currentUserDoc['latitude'] as double;
      double userLon = currentUserDoc['longitude'] as double;

      snapshot.docs.forEach((doc) {
        if (doc.id != userId &&
            doc.exists &&
            doc.data().toString().contains('latitude') &&
            doc.data().toString().contains('longitude') &&
            doc.data().toString().contains('name')) {
          try {
            double lat = doc['latitude'] as double;
            double lon = doc['longitude'] as double;
            String name = doc['name'] as String;

            double distanceMeters =
                Geolocator.distanceBetween(userLat, userLon, lat, lon);
            double distanceFeet = distanceMeters * 3.28084; // Convert to feet

            if (distanceFeet <= radius) {
              nearby.add({
                'name': name,
                'id': doc.id,
                'profileImageUrl': doc['profileImageUrl'] ?? '',
              });
            }
          } catch (e) {
            print("Error processing user ${doc.id}: $e");
          }
        }
      });

      // Shuffle to avoid giving away proximity information
      nearby.shuffle();

      return nearby;
    });
  }

  // Direct navigation to chat for Friends
  void _navigateToChat(BuildContext context, String friendName) {
    print("Navigating directly to chat with friend: $friendName");
    try {
      // Create the conversation path with a default topic
      final String chatTitle = "Chat with $friendName";

      // Create or update the conversation
      FirebaseFirestore.instance
          .collection('conversations')
          .doc(chatTitle)
          .set({
        'title': chatTitle,
        'type': 'Private',
        'participants': FieldValue.arrayUnion([userId, friendName]),
        'createdAt': FieldValue.serverTimestamp(),
        'lastActivity': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).then((_) {
        print("Conversation created successfully");

        // Navigate to chat screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              userId: userId,
              chatTitle: chatTitle,
              chatType: 'Private',
            ),
          ),
        );
      }).catchError((error) {
        print("Error creating conversation: $error");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating conversation: $error')),
        );
      });
    } catch (e) {
      print("Exception in _navigateToChat: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // Show emoji picker for Nearby users
  void _showEmojiPickerForNearby(BuildContext context, String nearbyUserName) {
    showDialog(
      context: context,
      builder: (context) => _buildEmojiPickerDialog(context, nearbyUserName),
    );
  }

  // Emoji picker dialog
  Widget _buildEmojiPickerDialog(BuildContext context, String userName) {
    final List<String> emojiOptions = [
      '👋',
      '😍',
      '❓',
      '❗',
      '🎉',
      '🎮',
      '📚',
      '👨‍💻',
      '🏋️',
      '🧘',
      '☕',
      '🍕',
      '🎵',
      '📱',
      '🏖️',
      '🚴',
      '🎬'
    ];

    return AlertDialog(
      title: Text('Say Hi to $userName'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Pick an emoji to start the conversation:'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: emojiOptions
                .map((emoji) => GestureDetector(
                      onTap: () {
                        Navigator.pop(context); // Close emoji picker
                        _startChatWithEmoji(context, userName, emoji);
                      },
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Center(
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  // Start chat with selected emoji
  void _startChatWithEmoji(
      BuildContext context, String userName, String emoji) {
    try {
      // Create the conversation path with emoji
      final String chatTitle = "$emoji with $userName";

      // Create or update the conversation
      FirebaseFirestore.instance
          .collection('conversations')
          .doc(chatTitle)
          .set({
        'title': chatTitle,
        'type': 'Private',
        'participants': FieldValue.arrayUnion([userId, userName]),
        'createdAt': FieldValue.serverTimestamp(),
        'lastActivity': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).then((_) {
        print("Conversation with emoji created successfully");

        // Navigate to chat screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              userId: userId,
              chatTitle: chatTitle,
              chatType: 'Private',
            ),
          ),
        ).then((_) {
          // After navigating to chat, add the emoji as first message
          FirebaseFirestore.instance
              .collection('conversations')
              .doc(chatTitle)
              .collection('messages')
              .add({
            'text': emoji,
            'senderId': userId,
            'timestamp': FieldValue.serverTimestamp(),
            'likes': [],
          }).catchError((error) {
            print("Error adding emoji message: $error");
          });
        });
      }).catchError((error) {
        print("Error creating conversation with emoji: $error");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating conversation: $error')),
        );
      });
    } catch (e) {
      print("Exception in _startChatWithEmoji: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Custom gradient header
          CustomHeader(
            title: 'Friends & Nearby',
            subtitle: 'Detection radius: ${detectionRadius.round()} feet',
            primaryColor: AppTheme.blue,
          ),

          // Nearby users section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.yellow.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.yellow),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on,
                            color: AppTheme.yellow, size: 16),
                        const SizedBox(width: 4),
                        const Text(
                          'Nearby',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Refresh button
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      // This will trigger the stream to refresh
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Refreshing nearby users...')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Nearby users grid/empty state
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _getNearbyUsers(detectionRadius),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              List<Map<String, dynamic>> nearbyUsers = snapshot.data!;

              if (nearbyUsers.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline,
                              size: 48, color: Colors.grey),
                          const SizedBox(height: 8),
                          const Text(
                            'No nearby users found',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          const Text(
                            'Try increasing your detection radius',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                );
              }

              // Grid of nearby users
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final user = nearbyUsers[index];
                      final name = user['name'] as String;
                      final profileImageUrl = user['profileImageUrl'] as String;

                      // Assign color
                      final colorIndex =
                          name.hashCode % AppTheme.squareColors.length;
                      final color = AppTheme.squareColors[colorIndex];

                      return GestureDetector(
                        onTap: () => _showEmojiPickerForNearby(context, name),
                        child: Column(
                          children: [
                            // Profile image
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: color, width: 2),
                                color: color.withOpacity(0.1),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: profileImageUrl.isNotEmpty
                                    ? Image.network(
                                        profileImageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Center(
                                          child: Text(
                                            name[0].toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.bold,
                                              color: color,
                                            ),
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Text(
                                          name[0].toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                            color: color,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Name
                            Text(
                              name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            // Nearby label
                            Text(
                              'Nearby',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    childCount: nearbyUsers.length,
                  ),
                ),
              );
            },
          ),

          // Friends section divider
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.coral.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.coral),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people, color: AppTheme.coral, size: 16),
                        const SizedBox(width: 4),
                        const Text(
                          'My Friends',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Friends grid
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              // Safely get the friends list
              List<String> friends = [];
              try {
                if (snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>?;
                  if (data != null &&
                      data.containsKey('friends') &&
                      data['friends'] != null) {
                    friends = List<String>.from(data['friends']);
                  }
                }
              } catch (e) {
                print("Error getting friends: $e");
              }

              if (friends.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.group_add, size: 48, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No friends yet',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          Text(
                            'Add friends from nearby users',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              // Grid of friends
              return SliverPadding(
                padding: const EdgeInsets.all(16.0),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final name = friends[index];

                      // Get color based on friend name
                      final colorIndex =
                          name.hashCode % AppTheme.squareColors.length;
                      final color = AppTheme.squareColors[colorIndex];

                      return GestureDetector(
                        onTap: () => _navigateToChat(context, name),
                        child: Column(
                          children: [
                            // Profile circle
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: color.withOpacity(0.2),
                                border: Border.all(color: color, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  name[0].toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Name
                            Text(
                              name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            // Friend label
                            Text(
                              'Friend',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    childCount: friends.length,
                  ),
                ),
              );
            },
          ),

          // Bottom spacing
          const SliverToBoxAdapter(
            child: SizedBox(height: 20),
          ),
        ],
      ),
    );
  }
}
