import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';

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

  // Default to a location (San Francisco)
  LatLng _selectedLocation = const LatLng(37.7749, -122.4194);

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
    super.dispose();
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
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Place name
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

              // Address
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

              // Map section (with instructions)
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
                  child:
                      const Text('Save Place', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
