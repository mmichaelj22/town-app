import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_header.dart';
import '../models/user.dart';
import 'edit_profile_screen.dart';
import 'status_editor_screen.dart';
import 'interests_editor_screen.dart';
import 'local_favorites_screen.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
  TownUser? userData;
  bool isLoading = true;
  final ValueNotifier<bool> _isMapReady = ValueNotifier<bool>(false);
  late StreamSubscription<DocumentSnapshot> _userSubscription;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _requestLocationPermission(); // Add this line
    // Add this listener for real-time updates to profile visibility
    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((docSnapshot) {
      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        setState(() {
          userData = TownUser.fromMap(data, userId);
        });
      }
    });
  }

  @override
  void dispose() {
    // Cancel the subscription when the widget is disposed
    _userSubscription.cancel();
    super.dispose();
  }

  // Add this new method
  Future<void> _requestLocationPermission() async {
    try {
      await Geolocator.requestPermission();
    } catch (e) {
      print("Error requesting location permission: $e");
    }
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Fetch user data from Firestore
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        setState(() {
          userData = TownUser.fromMap(data, userId);
        });

        // Add this line to debug local favorites
        _debugLocalFavorites();
      }
    } catch (e) {
      print("Error loading profile: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading profile: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // If userData is loaded but has no favorites, add test data
    if (!isLoading && userData != null) {}

    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : userData == null
              ? const Center(child: Text("Error loading profile"))
              : RefreshIndicator(
                  onRefresh: _loadUserProfile,
                  child: CustomScrollView(
                    slivers: [
                      // Custom gradient header
                      CustomHeader(
                        title: 'Profile',
                        subtitle: userData!.name,
                        primaryColor: AppTheme.coral, // Using coral from theme
                      ),

                      // Profile content
                      SliverToBoxAdapter(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Profile image and basic info in a card
                              _buildProfileCard(),
                              const SizedBox(height: 12),

                              // Public/Private indicator
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: userData!.profilePublic
                                      ? AppTheme.green.withOpacity(0.1)
                                      : AppTheme.coral.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: userData!.profilePublic
                                        ? AppTheme.green
                                        : AppTheme.coral,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      userData!.profilePublic
                                          ? Icons.public
                                          : Icons.lock,
                                      size: 16,
                                      color: userData!.profilePublic
                                          ? AppTheme.green
                                          : AppTheme.coral,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      userData!.profilePublic
                                          ? "Your Profile is Public!"
                                          : "Your Profile is Private",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: userData!.profilePublic
                                            ? AppTheme.green
                                            : AppTheme.coral,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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

                              // Edit Profile Button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => EditProfileScreen(
                                          user: userData!,
                                        ),
                                      ),
                                    );

                                    if (result == true) {
                                      // Profile was updated, reload data
                                      _loadUserProfile();
                                    }
                                  },
                                  icon: const Icon(Icons.edit),
                                  label: const Text('Edit Profile'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    backgroundColor: AppTheme.coral,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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

            const SizedBox(height: 8),

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
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StatusEditorScreen(
                          currentStatus: userData!.statusMessage,
                          currentEmoji: userData!.statusEmoji,
                        ),
                      ),
                    );

                    if (result == true) {
                      _loadUserProfile();
                    }
                  },
                ),
              ],
            ),
            const Divider(),
            if (userData!.statusMessage.isEmpty &&
                userData!.statusEmoji.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Tap edit to set your status',
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
                    if (userData!.statusEmoji.isNotEmpty)
                      Text(
                        userData!.statusEmoji,
                        style: const TextStyle(fontSize: 28),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userData!.statusMessage,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Updated ${timeago.format(userData!.statusUpdatedAt)}',
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
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => InterestsEditorScreen(
                          currentInterests: userData!.interests,
                        ),
                      ),
                    );

                    if (result == true) {
                      _loadUserProfile();
                    }
                  },
                ),
              ],
            ),
            const Divider(),
            if (userData!.interests.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Tap edit to add your interests',
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
                  children: userData!.interests.map((interest) {
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
            // Header
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
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LocalFavoritesScreen(
                          userId: userId,
                          favorites: userData!.localFavorites,
                        ),
                      ),
                    );

                    if (result == true) {
                      _loadUserProfile();
                    }
                  },
                ),
              ],
            ),

            const Divider(),

            if (userData!.localFavorites.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Tap edit to add your local favorites',
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
                  Container(
                    height: 300, // Ensure sufficient height
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                      color: Colors.grey[
                          100], // Background color in case map doesn't load
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          // The map
                          _buildFavoritesMap(userData!.localFavorites),

                          // Optional loading indicator overlay that disappears when map is ready
                          ValueListenableBuilder<bool>(
                            valueListenable:
                                _isMapReady, // Create this as a ValueNotifier<bool> in your state class
                            builder: (context, isReady, child) {
                              return isReady
                                  ? const SizedBox.shrink()
                                  : Container(
                                      color: Colors.white.withOpacity(0.7),
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // List of favorites with recommendations
                  ...userData!.localFavorites
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

// This should be implemented in profile_screen.dart and local_favorites_screen.dart

  Widget _buildFavoritesMap(List<LocalFavorite> favorites) {
    print("====== MAP DEBUG ======");
    print("Building map with ${favorites.length} favorites");
    for (var fav in favorites) {
      print("Favorite: ${fav.name} at (${fav.latitude}, ${fav.longitude})");
    }

    if (favorites.isEmpty) return Container();

    // Create a list of markers from favorites
    final Set<Marker> markers = {};

    // Calculate bounds to fit all markers
    double? minLat, maxLat, minLng, maxLng;

    // Debug the markers creation
    print("Creating map with ${favorites.length} favorites");

    // Process all favorites to create markers and calculate bounds
    for (final favorite in favorites) {
      print(
          "Adding marker: ${favorite.name} at (${favorite.latitude}, ${favorite.longitude})");

      // Create a marker for this favorite
      markers.add(Marker(
        markerId: MarkerId(favorite.id),
        position: LatLng(favorite.latitude, favorite.longitude),
        infoWindow: InfoWindow(title: favorite.name),
      ));

      // Update the bounds
      if (minLat == null || favorite.latitude < minLat) {
        minLat = favorite.latitude;
      }
      if (maxLat == null || favorite.latitude > maxLat) {
        maxLat = favorite.latitude;
      }
      if (minLng == null || favorite.longitude < minLng) {
        minLng = favorite.longitude;
      }
      if (maxLng == null || favorite.longitude > maxLng) {
        maxLng = favorite.longitude;
      }
    }

    // Use default coordinates if no favorites or invalid coordinates
    if (markers.isEmpty ||
        minLat == null ||
        maxLat == null ||
        minLng == null ||
        maxLng == null) {
      print("No valid markers found, using default location");
      // Default to San Francisco coordinates
      final defaultPosition = LatLng(37.7749, -122.4194);
      markers.add(Marker(
        markerId: const MarkerId('default'),
        position: defaultPosition,
        infoWindow: const InfoWindow(title: "Default Location"),
      ));

      return GoogleMap(
        initialCameraPosition: CameraPosition(
          target: defaultPosition,
          zoom: 14,
        ),
        markers: markers,
        myLocationEnabled: false,
        zoomControlsEnabled: true,
        mapToolbarEnabled: true,
        mapType: MapType.normal,
        onMapCreated: (GoogleMapController controller) {
          // Store the controller if needed
          print("Map created successfully");
          _isMapReady.value = true;
        },
      );
    }

    // Add padding to bounds
    minLat = minLat - 0.02; // Increased padding
    maxLat = maxLat + 0.02;
    minLng = minLng - 0.02;
    maxLng = maxLng + 0.02;

    // Center position
    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;

    // Print the final map parameters
    print("Map will be centered at ($centerLat, $centerLng)");
    print("Map has ${markers.length} markers");

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(centerLat, centerLng),
        zoom: 13, // Increased zoom level
      ),
      markers: markers,
      myLocationEnabled: false,
      zoomControlsEnabled: true,
      mapToolbarEnabled: true,
      mapType: MapType.normal,
      onMapCreated: (GoogleMapController controller) {
        print("Map created successfully");
        _isMapReady.value = true;

        // Wait a moment for the map to initialize before animating camera
        Future.delayed(const Duration(milliseconds: 1000), () {
          try {
            controller.animateCamera(
              CameraUpdate.newLatLngBounds(
                LatLngBounds(
                  southwest: LatLng(minLat!, minLng!),
                  northeast: LatLng(maxLat!, maxLng!),
                ),
                100, // Increased padding
              ),
            );
            print("Camera animated to show all markers");
          } catch (e) {
            print("Error animating camera: $e");
          }
        });
      },
    );
  }

  void _debugLocalFavorites() {
    if (userData == null) {
      print("DEBUG: userData is null!");
      return;
    }

    print("DEBUG: Local favorites count: ${userData!.localFavorites.length}");

    if (userData!.localFavorites.isEmpty) {
      print("DEBUG: No local favorites found!");
      return;
    }

    for (var i = 0; i < userData!.localFavorites.length; i++) {
      final fav = userData!.localFavorites[i];
      print("DEBUG: Favorite #$i");
      print("  Name: ${fav.name}");
      print("  Coordinates: (${fav.latitude}, ${fav.longitude})");
      print("  PlaceId: ${fav.placeId}");
      print("  Address: ${fav.formattedAddress}");
    }
  }

// Helper method to get appropriate icon based on favorite type
  IconData _getIconForFavoriteType(String type) {
    switch (type.toLowerCase()) {
      case 'restaurant':
        return Icons.restaurant;
      case 'coffee shop':
        return Icons.coffee;
      case 'bar':
        return Icons.local_bar;
      case 'park':
        return Icons.park;
      case 'museum':
        return Icons.museum;
      // Add other cases as needed
      default:
        return Icons.place;
    }
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

// Call this method in build() or after loading user data:
// _addTestFavoritesIfNeeded();
}
