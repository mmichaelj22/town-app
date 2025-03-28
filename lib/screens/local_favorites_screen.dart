// lib/screens/local_favorites_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';
import '../models/user.dart';

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

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Location permissions are permanently denied')),
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current location obtained')),
      );
    } catch (e) {
      print("Error getting location: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
    }
  }

  void _showAddFavoriteSheet({int? index}) {
    // Clear previous data
    _nameController.clear();
    _descriptionController.clear();
    _selectedType = 'Restaurant';
    _useCurrentLocation = true;
    _latitude = null;
    _longitude = null;
    _editingIndex = index;

    // If editing, populate fields with existing data
    if (index != null && index < _favorites.length) {
      final favorite = _favorites[index];
      _nameController.text = favorite.name;
      _descriptionController.text = favorite.description;
      _selectedType = favorite.type;
      _latitude = favorite.latitude;
      _longitude = favorite.longitude;
      _useCurrentLocation = false; // Since we're editing existing coordinates
    }

    setState(() {
      _isAddingFavorite = true;
    });
  }

  void _addOrUpdateFavorite() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();

    // Create new favorite
    final favorite = LocalFavorite(
      name: name,
      type: _selectedType,
      description: description,
      latitude: _useCurrentLocation ? null : _latitude,
      longitude: _useCurrentLocation ? null : _longitude,
    );

    setState(() {
      if (_editingIndex != null) {
        // Update existing favorite
        _favorites[_editingIndex!] = favorite;
      } else {
        // Add new favorite
        _favorites.add(favorite);
      }
      _isAddingFavorite = false;
    });
  }

  void _confirmDeleteFavorite(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Favorite'),
        content:
            const Text('Are you sure you want to delete this favorite place?'),
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
          : _isAddingFavorite
              ? _buildAddFavoriteForm()
              : _buildFavoritesList(),
    );
  }

  Widget _buildFavoritesList() {
    return Column(
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
                  onPressed: () => _showAddFavoriteSheet(),
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
              ? Center(
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
                        onPressed: () => _showAddFavoriteSheet(),
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
                )
              : ListView.builder(
                  itemCount: _favorites.length,
                  padding: const EdgeInsets.all(8),
                  itemBuilder: (context, index) {
                    final favorite = _favorites[index];

                    IconData iconData;
                    switch (favorite.type.toLowerCase()) {
                      case 'restaurant':
                        iconData = Icons.restaurant;
                        break;
                      case 'coffee shop':
                        iconData = Icons.coffee;
                        break;
                      case 'bar':
                        iconData = Icons.local_bar;
                        break;
                      case 'park':
                        iconData = Icons.park;
                        break;
                      case 'museum':
                        iconData = Icons.museum;
                        break;
                      case 'shopping':
                        iconData = Icons.shopping_bag;
                        break;
                      case 'gym':
                        iconData = Icons.fitness_center;
                        break;
                      case 'library':
                        iconData = Icons.local_library;
                        break;
                      case 'theater':
                        iconData = Icons.theaters;
                        break;
                      case 'beach':
                        iconData = Icons.beach_access;
                        break;
                      default:
                        iconData = Icons.place;
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.blue.withOpacity(0.2),
                          child: Icon(iconData, color: AppTheme.blue),
                        ),
                        title: Text(
                          favorite.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          favorite.description.isEmpty
                              ? favorite.type
                              : '${favorite.type} • ${favorite.description}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () =>
                                  _showAddFavoriteSheet(index: index),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _confirmDeleteFavorite(index),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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
    );
  }

  Widget _buildAddFavoriteForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              _editingIndex != null
                  ? 'Edit Favorite Place'
                  : 'Add Favorite Place',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // Name field
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Place Name',
                hintText: 'E.g., Central Park, Joe\'s Cafe',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.place),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a place name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Type selector
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Place Type',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: _placeTypes.map((type) {
                IconData iconData;
                switch (type.toLowerCase()) {
                  case 'restaurant':
                    iconData = Icons.restaurant;
                    break;
                  case 'coffee shop':
                    iconData = Icons.coffee;
                    break;
                  case 'bar':
                    iconData = Icons.local_bar;
                    break;
                  case 'park':
                    iconData = Icons.park;
                    break;
                  case 'museum':
                    iconData = Icons.museum;
                    break;
                  case 'shopping':
                    iconData = Icons.shopping_bag;
                    break;
                  case 'gym':
                    iconData = Icons.fitness_center;
                    break;
                  case 'library':
                    iconData = Icons.local_library;
                    break;
                  case 'theater':
                    iconData = Icons.theaters;
                    break;
                  case 'beach':
                    iconData = Icons.beach_access;
                    break;
                  default:
                    iconData = Icons.place;
                }

                return DropdownMenuItem<String>(
                  value: type,
                  child: Row(
                    children: [
                      Icon(iconData, size: 20, color: AppTheme.blue),
                      const SizedBox(width: 8),
                      Text(type),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedType = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Description field
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'What makes this place special?',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Location section
            const Text(
              'Location',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    title: const Text('Use current location'),
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _useCurrentLocation,
                    onChanged: (value) {
                      setState(() {
                        _useCurrentLocation = value ?? true;
                        if (_useCurrentLocation) {
                          _getCurrentLocation();
                        }
                      });
                    },
                  ),
                ),
                if (!_useCurrentLocation &&
                    (_latitude == null || _longitude == null))
                  ElevatedButton.icon(
                    onPressed: _getCurrentLocation,
                    icon: const Icon(Icons.my_location, size: 16),
                    label: const Text('Get Current'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),

            if (!_useCurrentLocation &&
                (_latitude != null && _longitude != null))
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Card(
                  margin: EdgeInsets.zero,
                  color: Colors.grey[100],
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Latitude: ${_latitude!.toStringAsFixed(6)}\nLongitude: ${_longitude!.toStringAsFixed(6)}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 20),
                          onPressed: _getCurrentLocation,
                          tooltip: 'Refresh location',
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 32),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _isAddingFavorite = false;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _addOrUpdateFavorite,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                    backgroundColor: AppTheme.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(_editingIndex != null ? 'Update' : 'Add'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
