import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';
import 'package:geocoding/geocoding.dart';

class PlacePickerScreen extends StatefulWidget {
  final LocalFavorite? initialFavorite;

  const PlacePickerScreen({Key? key, this.initialFavorite}) : super(key: key);

  @override
  _PlacePickerScreenState createState() => _PlacePickerScreenState();
}

class _PlacePickerScreenState extends State<PlacePickerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _recommendationController = TextEditingController();
  final _searchController = TextEditingController();

  // Default to a location (San Francisco)
  LatLng _selectedLocation = const LatLng(37.7749, -122.4194);

  bool _isLoading = false;
  String _placeId = '';
  final uuid = Uuid();

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
      _placeId = widget.initialFavorite!.placeId;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _recommendationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // When search field is submitted, search for the location
  Future<void> _searchLocation() async {
    final query = _searchController.text;
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Try to geocode the search term
      List<Location> locations = await locationFromAddress(query);

      if (locations.isNotEmpty) {
        final location = locations.first;

        // Get the address details from the coordinates
        List<Placemark> placemarks = await placemarkFromCoordinates(
            location.latitude, location.longitude);

        if (placemarks.isNotEmpty) {
          final placemark = placemarks.first;
          final formattedAddress = _formatAddress(placemark);

          setState(() {
            _nameController.text = query; // Use the search query as the name
            _addressController.text = formattedAddress;
            _selectedLocation = LatLng(location.latitude, location.longitude);
            _placeId = 'geocoded_${uuid.v4()}';
          });

          // Update map camera
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(
              _selectedLocation,
              15,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Location not found. Try a more specific search.')),
        );
      }
    } catch (e) {
      print("Error searching location: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching location: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Format address from placemark
  String _formatAddress(Placemark placemark) {
    List<String> addressParts = [];

    if (placemark.street != null && placemark.street!.isNotEmpty)
      addressParts.add(placemark.street!);

    if (placemark.locality != null && placemark.locality!.isNotEmpty)
      addressParts.add(placemark.locality!);

    if (placemark.administrativeArea != null &&
        placemark.administrativeArea!.isNotEmpty)
      addressParts.add(placemark.administrativeArea!);

    if (placemark.postalCode != null && placemark.postalCode!.isNotEmpty)
      addressParts.add(placemark.postalCode!);

    if (placemark.country != null && placemark.country!.isNotEmpty)
      addressParts.add(placemark.country!);

    return addressParts.join(', ');
  }

  // When marker is moved, update the address
  Future<void> _updateAddressFromLocation() async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
          _selectedLocation.latitude, _selectedLocation.longitude);

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        setState(() {
          _addressController.text = _formatAddress(placemark);
        });
      }
    } catch (e) {
      print("Error getting address from location: $e");
    }
  }

  void _saveFavorite() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final favorite = LocalFavorite(
      id: widget.initialFavorite?.id ?? uuid.v4(),
      name: _nameController.text,
      placeId: _placeId.isEmpty ? 'manual_${uuid.v4()}' : _placeId,
      recommendation: _recommendationController.text,
      latitude: _selectedLocation.latitude,
      longitude: _selectedLocation.longitude,
      formattedAddress: _addressController.text,
    );

    print(
        "Saving favorite: ${favorite.name} at (${favorite.latitude}, ${favorite.longitude})");
    Navigator.pop(context, favorite);
  }

  GoogleMapController? _mapController;

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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search box
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              labelText: 'Search for a place',
                              hintText: 'Enter a location name',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.search),
                            ),
                            onSubmitted: (_) => _searchLocation(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _searchLocation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(12),
                          ),
                          child: const Icon(Icons.search),
                        ),
                      ],
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

                    // Map section
                    const Text(
                      'Drag the marker to set the exact location:',
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
                                _updateAddressFromLocation();
                              },
                            ),
                          },
                          onTap: (position) {
                            setState(() {
                              _selectedLocation = position;
                            });
                            _updateAddressFromLocation();
                          },
                          onMapCreated: (controller) {
                            _mapController = controller;
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
            ),
    );
  }
}
