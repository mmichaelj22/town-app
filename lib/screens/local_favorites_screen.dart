// lib/screens/local_favorites_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';
import 'place_picker_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocalFavoritesScreen extends StatefulWidget {
  final String userId;
  final List<LocalFavorite> favorites;

  const LocalFavoritesScreen({
    Key? key,
    required this.userId,
    required this.favorites,
  }) : super(key: key);

  @override
  _LocalFavoritesScreenState createState() => _LocalFavoritesScreenState();
}

class _LocalFavoritesScreenState extends State<LocalFavoritesScreen> {
  List<LocalFavorite> _favorites = [];
  bool _isSubmitting = false;
  final int _maxFavorites = 5;

  // Controllers for the add/edit favorite form
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedType = 'Restaurant';
  bool _useCurrentLocation = true;
  double? _latitude;
  double? _longitude;
  bool _isAddingFavorite = false;
  int? _editingIndex;

  // Available place types
  final List<String> _placeTypes = [
    'Restaurant',
    'Coffee Shop',
    'Bar',
    'Park',
    'Museum',
    'Shopping',
    'Gym',
    'Library',
    'Theater',
    'Beach',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _favorites = List.from(widget.favorites);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveFavorites() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'localFavorites': _favorites.map((fav) => fav.toMap()).toList(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Local favorites updated successfully')),
      );

      Navigator.pop(context, true); // Return true to indicate success
    } catch (e) {
      print("Error updating local favorites: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating favorites: $e')),
      );
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _addNewFavorite() async {
    if (_favorites.length >= _maxFavorites) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('You can add a maximum of $_maxFavorites favorites')),
      );
      return;
    }

    final result = await Navigator.push<LocalFavorite>(
      context,
      MaterialPageRoute(
        builder: (context) => const PlacePickerScreen(),
      ),
    );

    if (result != null) {
      setState(() {
        _favorites.add(result);
      });
    }
  }

  Future<void> _editFavorite(int index) async {
    final result = await Navigator.push<LocalFavorite>(
      context,
      MaterialPageRoute(
        builder: (context) => PlacePickerScreen(
          initialFavorite: _favorites[index],
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _favorites[index] = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Favorites'),
        backgroundColor: Colors.white,
        titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20),
        elevation: 4,
      ),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header with count
                Container(
                  color: Colors.grey[100],
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.favorite, color: AppTheme.blue),
                      const SizedBox(width: 8),
                      Text(
                        'Your Favorite Places (${_favorites.length}/$_maxFavorites)',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      if (_favorites.length < _maxFavorites)
                        ElevatedButton.icon(
                          onPressed: _addNewFavorite,
                          icon: const Icon(Icons.add),
                          label: const Text('Add'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),

                // Favorites list
                Expanded(
                  child: _favorites.isEmpty
                      ? _buildEmptyState()
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            // Map with pins for all favorites
                            if (_favorites.isNotEmpty) _buildFavoritesMap(),

                            // List of favorites below the map
                            ..._favorites.asMap().entries.map((entry) {
                              final index = entry.key;
                              final favorite = entry.value;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  title: Text(
                                    favorite.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        favorite.formattedAddress,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      if (favorite.recommendation.isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Text(
                                            '"${favorite.recommendation}"',
                                            style: TextStyle(
                                              fontStyle: FontStyle.italic,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        onPressed: () => _editFavorite(index),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete),
                                        onPressed: () =>
                                            _confirmDeleteFavorite(index),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                ),

                // Save button
                if (_favorites.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    child: ElevatedButton(
                      onPressed: _saveFavorites,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: AppTheme.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Save Favorites',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.place_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No favorite places yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your favorite local spots',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addNewFavorite,
            icon: const Icon(Icons.add),
            label: const Text('Add a Place'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesMap() {
    // Create a list of markers from favorites
    final Set<Marker> markers = _favorites.map((favorite) {
      return Marker(
        markerId: MarkerId(favorite.id),
        position: LatLng(favorite.latitude, favorite.longitude),
        infoWindow: InfoWindow(title: favorite.name),
      );
    }).toSet();

    // Calculate bounds to fit all markers
    double? minLat, maxLat, minLng, maxLng;
    for (final favorite in _favorites) {
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

    return Container(
      height: 200,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GoogleMap(
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
        ),
      ),
    );
  }

  void _confirmDeleteFavorite(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Favorite'),
        content: Text(
            'Are you sure you want to delete "${_favorites[index].name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _favorites.removeAt(index);
              });
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
