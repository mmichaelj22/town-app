import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_header.dart'; // Import custom header
import 'new_private_chat_dialog.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Use the CustomHeader component instead of a custom SliverAppBar
          CustomHeader(
            title: 'Friends & Nearby',
            subtitle: 'Detection radius: ${detectionRadius.round()} feet',
            primaryColor: AppTheme.blue,
            // No explicit expandedHeight - will use the default 120.0
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

          // Nearby users list
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _getNearbyUsers(detectionRadius),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              List<Map<String, dynamic>> nearbyUsers = snapshot.data!;

              if (nearbyUsers.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline,
                            size: 48, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No nearby users found',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        Text(
                          'Try increasing your detection radius',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final user = nearbyUsers[index];
                    final name = user['name'] as String;
                    final profileImageUrl = user['profileImageUrl'] as String;

                    // Assign a color from our theme colors in a random-seeming but consistent way
                    final colorIndex =
                        name.hashCode % AppTheme.squareColors.length;
                    final cardColor =
                        AppTheme.squareColors[colorIndex].withOpacity(0.1);
                    final borderColor = AppTheme.squareColors[colorIndex];

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: borderColor, width: 1),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => onSelectFriend(name),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                // Profile picture or initial
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: borderColor.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: borderColor, width: 2),
                                  ),
                                  child: profileImageUrl.isNotEmpty
                                      ? ClipOval(
                                          child: Image.network(
                                            profileImageUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Center(
                                              child: Text(
                                                name[0].toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.bold,
                                                  color: borderColor,
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                      : Center(
                                          child: Text(
                                            name[0].toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: borderColor,
                                            ),
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 12),
                                // User info - without distance
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Nearby',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Action button
                                Container(
                                  decoration: BoxDecoration(
                                    color: borderColor.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.message),
                                    color: borderColor,
                                    onPressed: () => onSelectFriend(name),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: nearbyUsers.length,
                ),
              );
            },
          ),

          // Friends section divider
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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

          // Friends list
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

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final name = friends[index];
                    // Use a different color palette for friends
                    final colorIndex = index % AppTheme.squareColors.length;
                    final cardColor =
                        AppTheme.squareColors[colorIndex].withOpacity(0.7);

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: cardColor,
                            child: Text(
                              name[0].toUpperCase(),
                              style: TextStyle(
                                color: cardColor.computeLuminance() > 0.5
                                    ? Colors.black
                                    : Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          trailing: Icon(Icons.chat, color: cardColor),
                          onTap: () => onSelectFriend(name),
                        ),
                      ),
                    );
                  },
                  childCount: friends.length,
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
