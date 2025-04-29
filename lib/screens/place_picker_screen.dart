import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:google_maps_webservice/places.dart';
import '../utils/api_config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

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
  final _focusNode = FocusNode();

  // Default to a location (New York City)
  LatLng _selectedLocation = const LatLng(40.7128, -74.0060);

  bool _isLoading = false;
  String _placeId = '';
  final uuid = Uuid();
  GoogleMapController? _mapController;

  // For address suggestions
  List<Prediction> _addressSuggestions = [];
  bool _showSuggestions = false;

  // Google Places API client
  late GoogleMapsPlaces _placesApi;
  bool _placesApiInitialized = false;

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

    // Initialize Google Places API client
    _initPlacesApi();

    // Set up listener for the search field to show/hide suggestions as the user types
    _searchController.addListener(_onSearchChanged);
    _focusNode.addListener(() {
      // Show suggestions when the search field is focused
      if (_focusNode.hasFocus && _searchController.text.isNotEmpty) {
        setState(() {
          _showSuggestions = true;
        });
      }
    });
  }

  // Initialize the Places API with the API key
  Future<void> _initPlacesApi() async {
    if (_placesApiInitialized) return;

    try {
      // Try to get API key from platform-specific storage
      String apiKey = "";
      try {
        apiKey = await ApiConfig.getGoogleApiKey();
      } catch (e) {
        print("Error getting API key from platform channel: $e");
        // Fallback to using a placeholder - you'll need to replace this with your actual API key
        // For development testing only - don't commit your actual API key to source control
        apiKey = ""; // Leave this empty in production code
      }

      if (apiKey.isNotEmpty) {
        _placesApi = GoogleMapsPlaces(apiKey: apiKey);
        _placesApiInitialized = true;
        print("Google Places API initialized successfully");
      } else {
        print("Failed to get Google API key, fallback to geocoding only");
      }
    } catch (e) {
      print("Error initializing Google Places API: $e");
    }
  }

  void _onSearchChanged() {
    if (_searchController.text.length >= 3) {
      _getAddressSuggestions(_searchController.text);
    } else {
      setState(() {
        _addressSuggestions = [];
        _showSuggestions = false;
      });
    }
  }

  Future<void> _getAddressSuggestions(String query) async {
    if (query.isEmpty) return;

    // Clear existing suggestions
    setState(() {
      _addressSuggestions = [];
      _showSuggestions = false;
    });

    if (!_placesApiInitialized) {
      await _initPlacesApi();
      if (!_placesApiInitialized) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Location search is currently unavailable. Please try again later.'),
          ),
        );
        return;
      }
    }

    try {
      // Use Google Places API to get autocomplete suggestions
      final response = await _placesApi.autocomplete(
        query,
        language: 'en',
        components: [
          Component(Component.country, 'us')
        ], // Limit to US for simplicity
        location: Location(
            lat: _selectedLocation.latitude, lng: _selectedLocation.longitude),
        radius: 50000, // 50km radius
      );

      if (response.status == "OK") {
        setState(() {
          _addressSuggestions = response.predictions;
          _showSuggestions = response.predictions.isNotEmpty;
        });
      } else {
        print("Places autocomplete error: ${response.errorMessage}");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Location search is currently unavailable. Please try again later.'),
          ),
        );
      }
    } catch (e) {
      print("Error getting place suggestions: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Location search is currently unavailable. Please try again later.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _recommendationController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _focusNode.dispose();
    // Properly dispose of API client if needed
    if (_placesApiInitialized) {
      _placesApi.dispose();
    }
    super.dispose();
  }

  // When search field is submitted, search for the location
  Future<void> _searchLocation() async {
    // If we already have values in the fields, use those
    if (_nameController.text.isNotEmpty && _addressController.text.isNotEmpty) {
      final query = _addressController.text;
      if (query.isEmpty) return;

      setState(() {
        _isLoading = true;
      });

      try {
        // Try multiple geocoding providers by using different geocoding formats
        List<geocoding.Location> locations = [];

        try {
          // Try standard format first
          locations = await geocoding.locationFromAddress(query);
          print("Successfully found location for: $query");
        } catch (e) {
          // The geocoding package throws exceptions when no results are found
          print("First geocoding attempt failed: $e");

          if (e.toString().contains("Could not find any result") ||
              e.toString().contains("network error")) {
            try {
              // Try adding more context if it failed (e.g., add "New York" if not present)
              if (!query.toLowerCase().contains("new york")) {
                print("Trying with New York context...");
                locations =
                    await geocoding.locationFromAddress("$query, New York");
                print("Successfully found location with New York context");
              }
            } catch (e2) {
              print("Second geocoding attempt failed: $e2");

              // Try with just the main part of the query (remove any street numbers, etc.)
              try {
                // Remove numbers and specific details to get more general results
                final simplifiedQuery =
                    query.replaceAll(RegExp(r'\d+'), '').trim();
                if (simplifiedQuery != query) {
                  print("Trying with simplified query: $simplifiedQuery");
                  locations =
                      await geocoding.locationFromAddress(simplifiedQuery);
                  print("Successfully found location with simplified query");
                }
              } catch (e3) {
                print("Third geocoding attempt failed: $e3");
              }
            }
          }
        }

        if (locations.isNotEmpty) {
          final location = locations.first;

          // Get the address details from the coordinates
          List<geocoding.Placemark> placemarks = [];
          try {
            placemarks = await geocoding.placemarkFromCoordinates(
                location.latitude, location.longitude);
          } catch (e) {
            print("Error getting placemark from coordinates: $e");
          }

          setState(() {
            // Only update the address if we don't already have one
            if (_addressController.text.isEmpty && placemarks.isNotEmpty) {
              final placemark = placemarks.first;
              _addressController.text = _formatAddress(placemark);
            }

            _selectedLocation = LatLng(location.latitude, location.longitude);
          });

          // Update map camera
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(
              _selectedLocation,
              15,
            ),
          );

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Found location: ${_nameController.text}')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Location not found. Try a more specific search or include city name.')),
          );
        }
      } catch (e) {
        print("Error searching location: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Error searching location. Try a different format or more specific address.')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      // Use the original search implementation if fields are empty
      final query = _searchController.text;
      // Rest of your existing _searchLocation code...
    }
  }

  // Format address from placemark
  String _formatAddress(geocoding.Placemark placemark) {
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
      // Use geocoding to get address from coordinates
      List<geocoding.Placemark> placemarks = [];
      try {
        placemarks = await geocoding.placemarkFromCoordinates(
            _selectedLocation.latitude, _selectedLocation.longitude);
      } catch (e) {
        print("Error getting address from location: $e");
      }

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        setState(() {
          _addressController.text = _formatAddress(placemark);

          // If the name is empty, try to set it from the placemark
          if (_nameController.text.isEmpty) {
            if (placemark.name != null &&
                placemark.name!.isNotEmpty &&
                placemark.name != "null") {
              _nameController.text = placemark.name!;
            } else if (placemark.thoroughfare != null &&
                placemark.thoroughfare!.isNotEmpty) {
              _nameController.text = placemark.thoroughfare!;
            }
          }
        });
      }
    } catch (e) {
      print("Error updating address from location: $e");
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

  void _selectSuggestion(Prediction prediction) {
    // Store the place ID and update UI
    _placeId = prediction.placeId ?? 'place_${uuid.v4()}';
    setState(() {
      _showSuggestions = false;
      _searchController.text = prediction.description ?? "";
    });

    // Hide keyboard
    FocusScope.of(context).unfocus();

    // Fetch detailed place information
    if (prediction.placeId != null && _placesApiInitialized) {
      _getDetailedPlaceInfo(prediction.placeId!);
    } else {
      _searchLocation();
    }
  }

  Future<void> _getDetailedPlaceInfo(String placeId) async {
    print("======= FETCHING PLACE DETAILS =======");
    print("Place ID: $placeId");

    setState(() {
      _isLoading = true;
    });

    try {
      // Get API key
      String apiKey = await ApiConfig.getGoogleApiKey();

      // Make direct HTTP request to Places API
      final url = 'https://maps.googleapis.com/maps/api/place/details/json'
          '?place_id=$placeId'
          '&fields=name,formatted_address,geometry,address_component'
          '&key=$apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        print("Response JSON status: ${data['status']}");

        if (data['status'] == 'OK' && data['result'] != null) {
          final result = data['result'];

          // Extract and update location
          if (result['geometry'] != null &&
              result['geometry']['location'] != null) {
            final location = result['geometry']['location'];
            setState(() {
              _selectedLocation = LatLng(location['lat'], location['lng']);
            });
          }

          // Extract and set name and address
          setState(() {
            _nameController.text = result['name'] ?? '';
            _addressController.text = result['formatted_address'] ?? '';
          });

          // Update map
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(_selectedLocation, 15),
          );

          print("Place data successfully processed");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Found location: ${_nameController.text}')),
          );
        } else {
          _searchLocation();
        }
      } else {
        _searchLocation();
      }
    } catch (e) {
      _searchLocation();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

// Update the map with current location
  void _updateMap() {
    try {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          _selectedLocation,
          15,
        ),
      );

      // Success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Found location: ${_nameController.text}')),
      );
    } catch (e) {
      print("Error updating map: $e");
    }
  }

// Improved place name extraction that handles multiple formats
  String extractPlaceName(String? name, String? address) {
    if (name == null || name.isEmpty) {
      return "Unnamed Place";
    }

    // Case 1: If there are bullets (•) in the name, take just the first part
    // Example: "Siena Cafe • Italian • Bar • Restaurant, 3rd Ave"
    if (name.contains('•')) {
      final bulletParts = name.split('•');
      if (bulletParts.isNotEmpty) {
        return bulletParts[0].trim();
      }
    }

    // Case 2: If there's a comma, try to extract just the place name
    // Example: "Monkey Bar, East 54th Street, New York, NY, USA"
    if (name.contains(',')) {
      final commaParts = name.split(',');
      if (commaParts.isNotEmpty) {
        // Check if the first part might contain category info after a hyphen or dash
        String firstPart = commaParts[0].trim();
        if (firstPart.contains('-')) {
          return firstPart.split('-')[0].trim();
        }
        return firstPart;
      }
    }

    // Case 3: If there's address info after the name with indicators like "on", "at", "in"
    // Example: "Siena Cafe on 3rd Avenue" or "Central Park in Manhattan"
    final addressIndicators = [' on ', ' at ', ' in '];
    for (var indicator in addressIndicators) {
      if (name.contains(indicator)) {
        return name.split(indicator)[0].trim();
      }
    }

    // Case 4: Some location strings might include the type after the name like "Siena Restaurant"
    // Try to extract just the name part if it's more than one word
    final words = name.split(' ');
    if (words.length > 1) {
      // Common business type suffixes to remove
      final commonTypes = [
        'Restaurant',
        'Café',
        'Cafe',
        'Bar',
        'Pub',
        'Shop',
        'Store'
      ];
      if (commonTypes.contains(words.last)) {
        return words.sublist(0, words.length - 1).join(' ');
      }
    }

    // If none of the above patterns match, return the original name
    return name;
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
                            focusNode: _focusNode,
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

                    // Address suggestions dropdown
                    if (_showSuggestions && _addressSuggestions.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.3),
                              spreadRadius: 1,
                              blurRadius: 3,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListView.separated(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            physics: _addressSuggestions.length > 5
                                ? const ClampingScrollPhysics()
                                : const NeverScrollableScrollPhysics(),
                            itemCount: _addressSuggestions.length > 5
                                ? 5
                                : _addressSuggestions.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final prediction = _addressSuggestions[index];

                              // Show proper restaurant icon for establishments
                              IconData icon = Icons.place;
                              if (prediction.types != null) {
                                if (prediction.types!.contains('restaurant') ||
                                    prediction.types!.contains('food')) {
                                  icon = Icons.restaurant;
                                } else if (prediction.types!.contains('bar')) {
                                  icon = Icons.local_bar;
                                } else if (prediction.types!
                                        .contains('school') ||
                                    prediction.types!.contains('university')) {
                                  icon = Icons.school;
                                }
                              }

                              // Get full name/title for the place
                              String mainText = "";
                              if (prediction.structuredFormatting?.mainText !=
                                  null) {
                                mainText =
                                    prediction.structuredFormatting!.mainText!;
                              } else if (prediction.description != null) {
                                // If no structured formatting, use the first part of the description
                                mainText = prediction.description!
                                    .split(',')
                                    .first
                                    .trim();
                              } else {
                                mainText = "Unknown Place";
                              }

                              // Get full address including street number
                              String subText = "";
                              if (prediction
                                      .structuredFormatting?.secondaryText !=
                                  null) {
                                subText = prediction
                                    .structuredFormatting!.secondaryText!;
                              } else if (prediction.description != null &&
                                  prediction.description!.contains(',')) {
                                // Get everything after the first comma for the address
                                subText = prediction.description!
                                    .substring(
                                        prediction.description!.indexOf(',') +
                                            1)
                                    .trim();
                              }

                              return ListTile(
                                dense: true,
                                leading: Icon(icon, color: Colors.grey),
                                title: Text(
                                  mainText,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  subText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () => _selectSuggestion(prediction),
                              );
                            }),
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

  Future<void> _getCompleteAddressDetails(String placeId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Request the full place details with all address components
      final details = await _placesApi.getDetailsByPlaceId(placeId, fields: [
        'name',
        'formatted_address',
        'geometry',
        'address_component'
      ]);

      if (details.status == "OK") {
        // Extract location coordinates
        if (details.result?.geometry?.location != null) {
          final location = details.result!.geometry!.location!;
          setState(() {
            _selectedLocation = LatLng(location.lat, location.lng);
          });
        }

        // Set the place name - handle null safely
        setState(() {
          _nameController.text = details.result?.name ?? "";
        });

        // Set the complete formatted address with street number - handle null safely
        setState(() {
          _addressController.text = details.result?.formattedAddress ?? "";
        });

        // Update map camera only if we have valid coordinates
        if (_selectedLocation != null && _mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(
              _selectedLocation,
              15,
            ),
          );
        }

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Found location: ${_nameController.text}')),
        );
      } else {
        print(
            "Place details request failed: ${details.errorMessage ?? "Unknown error"}");
        _searchLocation(); // Fall back to geocoding
      }
    } catch (e) {
      print("Error getting place details: $e");
      _searchLocation(); // Fall back to geocoding
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
