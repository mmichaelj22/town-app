import 'package:flutter/material.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';

class PlaceSearchScreen extends StatefulWidget {
  final LocalFavorite? initialFavorite;

  const PlaceSearchScreen({Key? key, this.initialFavorite}) : super(key: key);

  @override
  _PlaceSearchScreenState createState() => _PlaceSearchScreenState();
}

class _PlaceSearchScreenState extends State<PlaceSearchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _recommendationController = TextEditingController();

  // Default to a location (San Francisco)
  LatLng _selectedLocation = const LatLng(37.7749, -122.4194);
  bool _isLoading = false;

  // Google Places API client
  final _placesApi = GoogleMapsPlaces(
    apiKey: 'YOUR_API_KEY', // Replace with your actual API key
  );

  List<PlacesSearchResult> _searchResults = [];
  bool _searching = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialFavorite != null) {
      _nameController.text = widget.initialFavorite!.name;
      _addressController.text = widget.initialFavorite!.formattedAddress;
      _recommendationController.text = widget.initialFavorite!.recommendation;
      _selectedLocation = LatLng(
        widget.initialFavorite!.latitude,
        widget.initialFavorite!.longitude,
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _recommendationController.dispose();
    _searchController.dispose();
    _placesApi.dispose();
    super.dispose();
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _searching = true;
      _searchResults = [];
    });

    try {
      final response = await _placesApi.searchByText(
        query,
        language: 'en',
      );

      if (response.status == 'OK') {
        setState(() {
          _searchResults = response.results;
          _searching = false;
        });
      } else {
        print("Place search error: ${response.errorMessage}");
        setState(() {
          _searching = false;
        });
      }
    } catch (e) {
      print("Error searching places: $e");
      setState(() {
        _searching = false;
      });
    }
  }

  void _selectPlace(PlacesSearchResult place) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get place details to get more accurate coordinates
      final details = await _placesApi.getDetailsByPlaceId(place.placeId);

      if (details.status == 'OK' && details.result != null) {
        final result = details.result!;
        final location = result.geometry?.location;

        if (location != null) {
          setState(() {
            _nameController.text = place.name;
            _addressController.text = place.formattedAddress ?? '';
            _selectedLocation = LatLng(location.lat, location.lng);
            _searchResults = [];
            _searchController.clear();
          });
        }
      }
    } catch (e) {
      print("Error getting place details: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _saveFavorite() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final favorite = LocalFavorite(
      id: widget.initialFavorite?.id ?? const Uuid().v4(),
      name: _nameController.text,
      placeId: widget.initialFavorite?.placeId ?? 'manual_${const Uuid().v4()}',
      recommendation: _recommendationController.text,
      latitude: _selectedLocation.latitude,
      longitude: _selectedLocation.longitude,
      formattedAddress: _addressController.text,
    );

    Navigator.pop(context, favorite);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialFavorite == null
            ? 'Add Favorite Place'
            : 'Edit Favorite Place'),
        backgroundColor: AppTheme.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Stack(
                children: [
                  // Main form
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Search box
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            labelText: 'Search for a place',
                            hintText: 'Enter a location name',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchResults = [];
                                      });
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (value) {
                            if (value.length > 2) {
                              _searchPlaces(value);
                            }
                          },
                        ),

                        // Search results
                        if (_searching)
                          const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_searchResults.isNotEmpty)
                          Container(
                            height: 200,
                            margin: const EdgeInsets.only(top: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: ListView.builder(
                              itemCount: _searchResults.length,
                              itemBuilder: (context, index) {
                                final place = _searchResults[index];
                                return ListTile(
                                  title: Text(place.name),
                                  subtitle: Text(
                                    place.formattedAddress ??
                                        'No address available',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () => _selectPlace(place),
                                );
                              },
                            ),
                          ),

                        const SizedBox(height: 16),

                        // Place details form
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Place Name',
                            hintText: 'Enter the name of this place',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _addressController,
                          decoration: const InputDecoration(
                            labelText: 'Address',
                            hintText: 'Enter the address',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter an address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Map preview
                        const Text(
                          'Location Preview:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),

                        SizedBox(
                          height: 200,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: _selectedLocation,
                                zoom: 14,
                              ),
                              markers: {
                                Marker(
                                  markerId: const MarkerId('selected'),
                                  position: _selectedLocation,
                                  draggable: true,
                                  onDragEnd: (newPosition) {
                                    setState(() {
                                      _selectedLocation = newPosition;
                                    });
                                  },
                                ),
                              },
                              onTap: (position) {
                                setState(() {
                                  _selectedLocation = position;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Recommendation
                        TextFormField(
                          controller: _recommendationController,
                          decoration: const InputDecoration(
                            labelText: 'What do you recommend here?',
                            hintText: 'Share what you like about this place',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 24),

                        // Save button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _saveFavorite,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Save Place',
                                style: TextStyle(fontSize: 16)),
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
}
