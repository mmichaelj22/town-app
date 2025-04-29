// lib/screens/profile_viewer_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../theme/app_theme.dart';
import '../models/user.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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
  bool _isLoading = true;
  TownUser? _userData;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch user data from Firestore
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _userData = TownUser.fromMap(data, widget.userId);
        });
      }
    } catch (e) {
      print("Error loading profile: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading profile: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userName),
        backgroundColor: AppTheme.coral,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userData == null
              ? const Center(child: Text("User profile not found"))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile image and basic info in a card
                      _buildProfileCard(),

                      const SizedBox(height: 20),

                      // Status message card
                      _buildStatusCard(),

                      const SizedBox(height: 20),

                      // Interests card
                      _buildInterestsCard(),

                      const SizedBox(height: 20),

                      // Local favorites card
                      _buildLocalFavoritesCard(),

                      const SizedBox(height: 20),

                      // Personal Information Section
                      _buildPersonalInfoCard(),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }

  Widget _buildProfileCard() {
    return Card(
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
                  child: _userData!.profileImageUrl != null &&
                          _userData!.profileImageUrl!.isNotEmpty
                      ? Image.network(
                          _userData!.profileImageUrl!,
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
                                  _userData!.name.isNotEmpty
                                      ? _userData!.name[0].toUpperCase()
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
                              _userData!.name.isNotEmpty
                                  ? _userData!.name[0].toUpperCase()
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
              _userData!.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            // Bio
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _userData!.bio,
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

  Widget _buildStatusCard() {
    return Card(
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
            if (_userData!.statusMessage.isEmpty &&
                _userData!.statusEmoji.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'No status set',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    if (_userData!.statusEmoji.isNotEmpty)
                      Text(
                        _userData!.statusEmoji,
                        style: const TextStyle(fontSize: 28),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userData!.statusMessage,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Updated ${timeago.format(_userData!.statusUpdatedAt)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
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

  Widget _buildInterestsCard() {
    return Card(
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
            if (_userData!.interests.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'No interests added',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _userData!.interests.map((interest) {
                    final colorIndex =
                        interest.hashCode % AppTheme.squareColors.length;
                    final color = AppTheme.squareColors[colorIndex];

                    return Chip(
                      backgroundColor: color.withOpacity(0.2),
                      side: BorderSide(color: color, width: 1),
                      avatar: CircleAvatar(
                        backgroundColor: color,
                        child: Text(
                          interest[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
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

  Widget _buildLocalFavoritesCard() {
    return Card(
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
            if (_userData!.localFavorites.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No local favorites added',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Map with all favorites
                  SizedBox(
                    height: 180,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _buildFavoritesMap(_userData!.localFavorites),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // List of favorites with recommendations
                  ..._userData!.localFavorites
                      .map((favorite) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Place name in bold
                              Text(
                                favorite.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 4),

                              // Address in lighter grey
                              Text(
                                favorite.formattedAddress,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),

                              // Recommendation in italics with quote marks
                              if (favorite.recommendation.isNotEmpty)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(top: 6, bottom: 6),
                                  child: Text(
                                    '"${favorite.recommendation}"',
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey[800],
                                      fontSize: 15,
                                    ),
                                  ),
                                ),

                              // Divider between items
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Divider(height: 1),
                              ),
                            ],
                          ))
                      .toList(),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoritesMap(List<LocalFavorite> favorites) {
    if (favorites.isEmpty) return Container();

    // Create a list of markers from favorites
    final Set<Marker> markers = favorites.map((favorite) {
      return Marker(
        markerId: MarkerId(favorite.id),
        position: LatLng(favorite.latitude, favorite.longitude),
        infoWindow: InfoWindow(title: favorite.name),
      );
    }).toSet();

    // Calculate bounds to fit all markers
    double? minLat, maxLat, minLng, maxLng;
    for (final favorite in favorites) {
      if (minLat == null || favorite.latitude < minLat)
        minLat = favorite.latitude;
      if (maxLat == null || favorite.latitude > maxLat)
        maxLat = favorite.latitude;
      if (minLng == null || favorite.longitude < minLng)
        minLng = favorite.longitude;
      if (maxLng == null || favorite.longitude > maxLng)
        maxLng = favorite.longitude;
    }

    // Add padding to bounds
    minLat = minLat! - 0.01;
    maxLat = maxLat! + 0.01;
    minLng = minLng! - 0.01;
    maxLng = maxLng! + 0.01;

    // Center position
    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(centerLat, centerLng),
        zoom: 12,
      ),
      markers: markers,
      myLocationEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      onMapCreated: (controller) {
        // Fit bounds when map is created
        controller.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(minLat!, minLng!),
              northeast: LatLng(maxLat!, maxLng!),
            ),
            50, // padding
          ),
        );
      },
    );
  }

  Widget _buildPersonalInfoCard() {
    return Card(
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
            _buildInfoItem(Icons.cake, 'Age', _userData!.age.toString()),
            _buildInfoItem(Icons.person, 'Relationship Status',
                _userData!.relationshipStatus),
            _buildInfoItem(
                Icons.person, 'Current City', _userData!.currentCity),
            _buildInfoItem(
                Icons.location_city, 'Hometown', _userData!.hometown),
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
