// lib/screens/profile_viewer_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../models/user.dart';

class ProfileViewerScreen extends StatefulWidget {
  final String currentUserId;
  final String userId;
  final String userName;

  const ProfileViewerScreen({
    Key? key,
    required this.currentUserId,
    required this.userId,
    required this.userName,
  }) : super(key: key);

  @override
  _ProfileViewerScreenState createState() => _ProfileViewerScreenState();
}

class _ProfileViewerScreenState extends State<ProfileViewerScreen> {
  TownUser? userData; // Define the userData variable here
  bool _isLoading = true;
  bool _hasAccessError = false;

  @override
  void initState() {
    super.initState();
    _checkAccessAndLoadProfile();
  }

  Future<bool> _canViewProfile() async {
    // The current user can always view their own profile
    if (widget.userId == widget.currentUserId) {
      return true;
    }

    try {
      // First check if they are friends
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId)
          .get();

      if (currentUserDoc.exists) {
        final userData = currentUserDoc.data();
        if (userData != null && userData.containsKey('friends')) {
          final friends = userData['friends'];
          if (friends is List) {
            for (var friend in friends) {
              String friendId;
              if (friend is String) {
                friendId = friend;
              } else if (friend is Map) {
                friendId = friend['id'] as String? ?? '';
              } else {
                continue;
              }

              if (friendId == widget.userId) {
                // They are friends, can view profile
                return true;
              }
            }
          }
        }
      }

      // Not friends, check if the profile is public
      final targetUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (targetUserDoc.exists) {
        final targetData = targetUserDoc.data();
        if (targetData != null) {
          return targetData['profilePublic'] as bool? ?? true;
        }
      }

      // Default to false if something went wrong
      return false;
    } catch (e) {
      print("Error checking profile visibility: $e");
      return false;
    }
  }

  Future<void> _checkAccessAndLoadProfile() async {
    setState(() {
      _isLoading = true;
      _hasAccessError = false;
    });

    final bool canView = await _canViewProfile();

    if (canView) {
      // Load the profile data
      _loadUserProfile();
    } else {
      // Show restricted access message
      setState(() {
        _isLoading = false;
        _hasAccessError = true;
      });
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        setState(() {
          userData = TownUser.fromMap(data, widget.userId);
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading profile: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading profile: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildRestrictedAccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '${widget.userName}\'s Profile is Private',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'You need to be friends to view this profile',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _sendFriendRequest,
              icon: const Icon(Icons.person_add),
              label: const Text('Send Friend Request'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.blue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendFriendRequest() async {
    try {
      // Get current user name
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId)
          .get();

      if (!currentUserDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Your profile not found')),
        );
        return;
      }

      final currentUserData = currentUserDoc.data();
      if (currentUserData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Your profile data not found')),
        );
        return;
      }

      final String currentUserName =
          currentUserData['name'] as String? ?? 'User';

      // Add to the target user's pending requests
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({
        'pendingFriendRequests': FieldValue.arrayUnion([widget.currentUserId]),
      });

      // Add to the current user's sent requests
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId)
          .update({
        'sentFriendRequests': FieldValue.arrayUnion([widget.userId]),
      });

      // Add notification for the target user
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('notifications')
          .add({
        'type': 'friendRequest',
        'senderId': widget.currentUserId,
        'senderName': currentUserName,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Friend request sent to ${widget.userName}')),
      );

      Navigator.pop(context);
    } catch (e) {
      print("Error sending friend request: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending friend request: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userName),
        elevation: 0,
        backgroundColor: AppTheme.coral,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasAccessError
              ? _buildRestrictedAccessView()
              : userData == null
                  ? const Center(child: Text("Error loading profile"))
                  : _buildProfileContent(),
    );
  }

  Widget _buildProfileContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileCard(),
          if (userData!.statusMessage.isNotEmpty ||
              userData!.statusEmoji.isNotEmpty)
            _buildStatusCard(),
          if (userData!.interests.isNotEmpty) _buildInterestsCard(),
          if (userData!.localFavorites.isNotEmpty) _buildLocalFavoritesCard(),
          _buildPersonalInfoCard(),
        ],
      ),
    );
  }

  // Profile card with image, name, and bio
  Widget _buildProfileCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Profile Image
            Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.4,
                height: MediaQuery.of(context).size.width * 0.4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.coral.withOpacity(0.5),
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: userData!.profileImageUrl != null &&
                          userData!.profileImageUrl!.isNotEmpty
                      ? Image.network(
                          userData!.profileImageUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: AppTheme.coral.withOpacity(0.2),
                              child: Center(
                                child: Text(
                                  userData!.name.isNotEmpty
                                      ? userData!.name[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    fontSize: 60,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.coral,
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                      : Container(
                          color: AppTheme.coral.withOpacity(0.2),
                          child: Center(
                            child: Text(
                              userData!.name.isNotEmpty
                                  ? userData!.name[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontSize: 60,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.coral,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Name
            Text(
              userData!.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            // Bio
            if (userData!.bio.isNotEmpty && userData!.bio != 'No bio yet.')
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  userData!.bio,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Status card with emoji and message
  Widget _buildStatusCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.yellow.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.mood, color: AppTheme.yellow),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Status',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  if (userData!.statusEmoji.isNotEmpty)
                    Text(
                      userData!.statusEmoji,
                      style: const TextStyle(fontSize: 28),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      userData!.statusMessage,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Interests card with chips
  Widget _buildInterestsCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.interests, color: AppTheme.green),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Interests',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: userData!.interests.map((interest) {
                  final colorIndex =
                      interest.hashCode % AppTheme.squareColors.length;
                  final color = AppTheme.squareColors[colorIndex];

                  return Chip(
                    backgroundColor: color.withOpacity(0.2),
                    side: BorderSide(color: color, width: 1),
                    label: Text(
                      interest,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Local favorites card with places
  Widget _buildLocalFavoritesCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.favorite, color: AppTheme.blue),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Local Favorites',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: userData!.localFavorites.map((favorite) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        favorite.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        favorite.formattedAddress,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (favorite.recommendation.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '"${favorite.recommendation}"',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.grey[800],
                              fontSize: 14,
                            ),
                          ),
                        ),
                      if (userData!.localFavorites.last != favorite)
                        const Divider(height: 16),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // Personal information card
  Widget _buildPersonalInfoCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Personal Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            userData!.birthDate != null
                ? _buildInfoItem(Icons.cake, 'Age', '${userData!.age} years')
                : _buildInfoItem(Icons.cake, 'Age', 'Not specified'),
            _buildInfoItem(Icons.favorite, 'Relationship Status',
                userData!.relationshipStatus),
            _buildInfoItem(
                Icons.location_city, 'Current City', userData!.currentCity),
            _buildInfoItem(Icons.home, 'Hometown', userData!.hometown),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.coral.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.coral),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
