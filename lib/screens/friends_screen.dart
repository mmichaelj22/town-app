import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_header.dart';
import '../widgets/profile_action_menu.dart';
import '../utils/user_blocking_service.dart';

class FriendsScreen extends StatefulWidget {
  final String userId;
  final double detectionRadius;
  final Function(String) onSelectFriend;

  const FriendsScreen({
    super.key,
    required this.userId,
    required this.detectionRadius,
    required this.onSelectFriend,
  });

  @override
  _FriendsScreenState createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final UserBlockingService _blockingService = UserBlockingService();
  List<Map<String, dynamic>> _nearbyUsers = [];
  List<Map<String, dynamic>> _friends = [];
  List<String> _blockedUsers = [];
  List<String> _blockedByUsers = [];
  List<String> _pendingFriendRequests = [];
  List<String> _sentFriendRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load user data including friends list and requests
      await _loadUserData();

      // Load blocked users list
      await _loadBlockedUsers();

      // Load users who have blocked the current user
      await _loadBlockedByUsers();
    } catch (e) {
      print("Error loading initial data: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserData() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>?;
        if (data != null) {
          setState(() {
            // Load friends list if exists
            _friends = data.containsKey('friends')
                ? List<Map<String, dynamic>>.from(data['friends'] ?? [])
                : [];

            // Load pending friend requests if exists
            _pendingFriendRequests = data.containsKey('pendingFriendRequests')
                ? List<String>.from(data['pendingFriendRequests'] ?? [])
                : [];

            // Load sent friend requests if exists
            _sentFriendRequests = data.containsKey('sentFriendRequests')
                ? List<String>.from(data['sentFriendRequests'] ?? [])
                : [];
          });
        }
      }
    } catch (e) {
      print("Error loading user data: $e");
    }
  }

  Future<void> _loadBlockedUsers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('blocked_users')
          .get();

      setState(() {
        _blockedUsers = snapshot.docs.map((doc) => doc.id).toList();
      });
    } catch (e) {
      print("Error loading blocked users: $e");
    }
  }

  Future<void> _loadBlockedByUsers() async {
    try {
      // This is more complex as we need to query across all user documents
      // to find who has blocked the current user
      final usersSnapshot =
          await FirebaseFirestore.instance.collection('users').get();

      List<String> blockedByList = [];

      for (var userDoc in usersSnapshot.docs) {
        if (userDoc.id != widget.userId) {
          final blockedSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(userDoc.id)
              .collection('blocked_users')
              .doc(widget.userId)
              .get();

          if (blockedSnapshot.exists) {
            blockedByList.add(userDoc.id);
          }
        }
      }

      setState(() {
        _blockedByUsers = blockedByList;
      });
    } catch (e) {
      print("Error loading users who blocked current user: $e");
    }
  }

  Stream<List<Map<String, dynamic>>> _getNearbyUsers(double radius) {
    return FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .asyncMap((snapshot) async {
      List<Map<String, dynamic>> nearby = [];

      // Find the current user document
      DocumentSnapshot? currentUserDoc;
      try {
        currentUserDoc = snapshot.docs.firstWhere((d) => d.id == widget.userId);
      } catch (e) {
        print("Current user not found in Firestore: $e");
        return nearby; // Return empty list if user not found
      }

      // Check if the current user has latitude and longitude
      if (!currentUserDoc.exists) {
        print("Current user document doesn't exist");
        return nearby;
      }

      final currentUserData = currentUserDoc.data() as Map<String, dynamic>?;
      if (currentUserData == null) {
        print("Current user data is null");
        return nearby;
      }

      if (!currentUserData.containsKey('latitude') ||
          !currentUserData.containsKey('longitude')) {
        print("Current user missing location data");
        return nearby;
      }

      double userLat = currentUserData['latitude'] as double;
      double userLon = currentUserData['longitude'] as double;

      for (var doc in snapshot.docs) {
        if (doc.id != widget.userId) {
          try {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null) continue;

            // Skip users who have undetectable mode enabled
            // *** This is the key change to respect undetectable mode ***
            if (data.containsKey('undetectable') &&
                data['undetectable'] == true) {
              continue; // Skip this user - they are in undetectable mode
            }

            // Safely check all required fields
            if (!data.containsKey('latitude') ||
                !data.containsKey('longitude') ||
                !data.containsKey('name')) {
              continue;
            }

            String userId = doc.id;
            String name = data['name'] as String;

            // Check if either user has blocked the other
            bool isBlocked = _blockedUsers.contains(userId);
            bool isBlockedBy = _blockedByUsers.contains(userId);

            // Safely get profileImageUrl
            String profileImageUrl = '';
            if (data.containsKey('profileImageUrl')) {
              profileImageUrl = data['profileImageUrl'] as String? ?? '';
            }

            // Check if this is a friend
            bool isFriend = _friends.any((friend) => friend['id'] == userId);

            // Check pending friend requests
            bool hasPendingRequest = _pendingFriendRequests.contains(userId);
            bool hasSentRequest = _sentFriendRequests.contains(userId);

            // Include blocked users but with an indicator
            double lat = data['latitude'] as double;
            double lon = data['longitude'] as double;

            double distanceMeters =
                Geolocator.distanceBetween(userLat, userLon, lat, lon);
            double distanceFeet = distanceMeters * 3.28084; // Convert to feet

            if (distanceFeet <= radius) {
              nearby.add({
                'name': name,
                'id': userId,
                'profileImageUrl': profileImageUrl,
                'isBlocked': isBlocked,
                'isBlockedBy': isBlockedBy,
                'isFriend': isFriend,
                'hasPendingRequest': hasPendingRequest,
                'hasSentRequest': hasSentRequest,
              });
            }
          } catch (e) {
            print("Error processing user ${doc.id}: $e");
          }
        }
      }

      // Shuffle to avoid giving away proximity information
      nearby.shuffle();

      return nearby;
    });
  }

  // Show profile options menu
  void _showProfileOptions(BuildContext context, Map<String, dynamic> user) {
    final String userId = user['id'];
    final String name = user['name'];
    final bool isFriend = user['isFriend'];
    final bool hasPendingRequest = user['hasPendingRequest'];
    final bool hasSentRequest = user['hasSentRequest'];

    ProfileActionMenu.show(
      context: context,
      currentUserId: widget.userId,
      userId: userId,
      userName: name,
      isFriend: isFriend,
      hasSentRequest: hasSentRequest,
      hasReceivedRequest: hasPendingRequest,
      onFriendRequestSent: () {
        setState(() {
          _sentFriendRequests.add(userId);
        });
      },
      onFriendRequestAccepted: () {
        setState(() {
          _pendingFriendRequests.remove(userId);
          _friends.add({'id': userId, 'name': name});
        });
      },
      onUserBlocked: () {
        setState(() {
          _blockedUsers.add(userId);
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Custom gradient header
          CustomHeader(
            title: 'Friends & Nearby',
            subtitle:
                'Detection radius: ${widget.detectionRadius.round()} feet',
            primaryColor: AppTheme.blue,
          ),

          // Friend requests section (if there are any)
          if (_pendingFriendRequests.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.coral.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.coral),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_add,
                              color: AppTheme.coral, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Friend Requests (${_pendingFriendRequests.length})',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // List of friend requests
                    ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: _pendingFriendRequests.length,
                      itemBuilder: (context, index) {
                        final requesterId = _pendingFriendRequests[index];

                        // We need to get the requester's name
                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(requesterId)
                              .get(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return ListTile(
                                title: Text('Loading...'),
                                leading: CircleAvatar(
                                  backgroundColor: Colors.grey[300],
                                ),
                              );
                            }

                            final data =
                                snapshot.data!.data() as Map<String, dynamic>?;
                            if (data == null) {
                              return SizedBox.shrink();
                            }

                            final requesterName =
                                data['name'] as String? ?? 'Unknown User';
                            final profileImageUrl =
                                data['profileImageUrl'] as String? ?? '';

                            final requesterData = {
                              'id': requesterId,
                              'name': requesterName,
                              'profileImageUrl': profileImageUrl,
                              'isFriend': false,
                              'hasPendingRequest': true,
                              'hasSentRequest': false,
                              'isBlocked': false,
                              'isBlockedBy': false,
                            };

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    AppTheme.coral.withOpacity(0.2),
                                backgroundImage: profileImageUrl.isNotEmpty
                                    ? NetworkImage(profileImageUrl)
                                    : null,
                                child: profileImageUrl.isEmpty
                                    ? Text(
                                        requesterName[0].toUpperCase(),
                                        style: TextStyle(
                                          color: AppTheme.coral,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                              title: Text(requesterName),
                              subtitle: Text('Sent you a friend request'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.close, color: Colors.red),
                                    onPressed: () => _respondToFriendRequest(
                                        requesterId, requesterName,
                                        accept: false),
                                  ),
                                  IconButton(
                                    icon:
                                        Icon(Icons.check, color: Colors.green),
                                    onPressed: () => _respondToFriendRequest(
                                        requesterId, requesterName,
                                        accept: true),
                                  ),
                                ],
                              ),
                              onTap: () =>
                                  _showProfileOptions(context, requesterData),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
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
                      // This will trigger a refresh of the stream
                      setState(() {});
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
            stream: _getNearbyUsers(widget.detectionRadius),
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

              // Filter out friends from nearby users to show them only once
              // but keep blocked users with an indicator
              List<Map<String, dynamic>> filteredNearbyUsers =
                  nearbyUsers.where((user) => !user['isFriend']).toList();

              // Update our stored nearby users for use in other methods
              _nearbyUsers = filteredNearbyUsers;

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
                      final user = filteredNearbyUsers[index];
                      final String name = user['name'] as String;
                      final String userId = user['id'] as String;
                      final String profileImageUrl =
                          user['profileImageUrl'] as String;
                      final bool isBlocked = user['isBlocked'] as bool;
                      final bool isBlockedBy = user['isBlockedBy'] as bool;
                      final bool hasSentRequest =
                          user['hasSentRequest'] as bool;
                      final bool hasPendingRequest =
                          user['hasPendingRequest'] as bool;

                      // Check if this nearby user is also a friend
                      final bool isFriend = user['isFriend'] as bool;

                      // Assign color
                      final colorIndex =
                          name.hashCode % AppTheme.squareColors.length;
                      final color = AppTheme.squareColors[colorIndex];

                      return GestureDetector(
                        onTap: () => isBlocked || isBlockedBy
                            ? null // Do nothing if blocked
                            : _showProfileOptions(context, user),
                        child: Column(
                          children: [
                            // Profile image
                            Stack(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      // Orange ring for friends
                                      color: isFriend ? AppTheme.orange : color,
                                      width: isFriend ? 3 : 2,
                                    ),
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
                                            errorBuilder: (_, __, ___) =>
                                                Center(
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

                                // If blocked, show "X" icon
                                if (isBlocked || isBlockedBy)
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.1),
                                            blurRadius: 4,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        '❌',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),

                                // If pending friend request, show indicator
                                if (hasPendingRequest)
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.coral,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.person_add,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                  ),

                                // If sent friend request, show indicator
                                if (hasSentRequest)
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[400],
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.hourglass_empty,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                              ],
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
                            // Nearby or Friend label
                            Text(
                              isFriend ? 'Friend' : 'Nearby',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    childCount: filteredNearbyUsers.length,
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
                .doc(widget.userId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              // Safely get the friends list
              List<Map<String, dynamic>> friends = [];
              try {
                if (snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>?;
                  if (data != null && data.containsKey('friends')) {
                    // Handle both formats: List<String> and List<Map>
                    final rawFriends = data['friends'];
                    if (rawFriends is List) {
                      for (var friend in rawFriends) {
                        if (friend is String) {
                          // Old format: convert to map
                          friends.add({
                            'id': friend,
                            'name': friend,
                          });
                        } else if (friend is Map) {
                          // New format: just add
                          friends.add(Map<String, dynamic>.from(friend));
                        }
                      }
                    }
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
                      final friend = friends[index];
                      final String name = friend['name'] as String;
                      final String friendId = friend['id'] as String;

                      // Get color based on friend name
                      final colorIndex =
                          name.hashCode % AppTheme.squareColors.length;
                      final color = AppTheme.squareColors[colorIndex];

                      return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(friendId)
                              .get(),
                          builder: (context, snapshot) {
                            String profileImageUrl = '';
                            if (snapshot.hasData && snapshot.data!.exists) {
                              final data = snapshot.data!.data()
                                  as Map<String, dynamic>?;
                              if (data != null &&
                                  data.containsKey('profileImageUrl')) {
                                profileImageUrl =
                                    data['profileImageUrl'] as String? ?? '';
                              }
                            }

                            final friendData = {
                              'id': friendId,
                              'name': name,
                              'profileImageUrl': profileImageUrl,
                              'isFriend': true,
                              'hasPendingRequest': false,
                              'hasSentRequest': false,
                              'isBlocked': false,
                              'isBlockedBy': false,
                            };

                            return GestureDetector(
                              onTap: () =>
                                  _showProfileOptions(context, friendData),
                              child: Column(
                                children: [
                                  // Profile circle
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: color.withOpacity(0.2),
                                      border:
                                          Border.all(color: color, width: 2),
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
                                              errorBuilder: (_, __, ___) =>
                                                  Center(
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
                          });
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

  // Respond to friend request function
  Future<void> _respondToFriendRequest(String senderId, String senderName,
      {required bool accept}) async {
    try {
      // Get current user info
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      final userData = userDoc.data();
      if (userData == null) return;

      final String receiverName =
          userData.containsKey('name') ? userData['name'] as String : 'User';

      // Remove from pending requests
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({
        'pendingFriendRequests': FieldValue.arrayRemove([senderId]),
      });

      // Remove from sent requests
      await FirebaseFirestore.instance
          .collection('users')
          .doc(senderId)
          .update({
        'sentFriendRequests': FieldValue.arrayRemove([widget.userId]),
      });

      if (accept) {
        // Add each user to the other's friends list
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .update({
          'friends': FieldValue.arrayUnion([
            {'id': senderId, 'name': senderName}
          ]),
        });

        await FirebaseFirestore.instance
            .collection('users')
            .doc(senderId)
            .update({
          'friends': FieldValue.arrayUnion([
            {'id': widget.userId, 'name': receiverName}
          ]),
        });

        // Add notification for the sender
        await FirebaseFirestore.instance
            .collection('users')
            .doc(senderId)
            .collection('notifications')
            .add({
          'type': 'friendRequestAccepted',
          'senderId': widget.userId,
          'senderName': receiverName,
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You are now friends with $senderName')),
        );
      } else {
        // No notification for rejected requests
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Friend request declined')),
        );
      }

      // Update local state
      setState(() {
        _pendingFriendRequests.remove(senderId);
        if (accept) {
          _friends.add({'id': senderId, 'name': senderName});
        }
      });

      // Refresh the page
      _loadInitialData();
    } catch (e) {
      print("Error responding to friend request: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error responding to friend request: $e')),
      );
    }
  }
}
