// lib/screens/edit_profile_screen.dart - Updated for the new user model

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';

class EditProfileScreen extends StatefulWidget {
  final TownUser user;

  const EditProfileScreen({
    super.key,
    required this.user,
  });

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _relationshipStatusController; // New controller
  late TextEditingController _currentCityController; // New controller
  late TextEditingController _hometownController;
  late TextEditingController _bioController;
  final List<String> _relationshipOptions = [
    'Single',
    'In a relationship',
    'Don\'t show'
  ];
  File? _imageFile;
  bool _isUploading = false;
  String? _profileImageUrl;
  DateTime? _selectedBirthDate;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _selectedBirthDate = widget.user.birthDate;
    _relationshipStatusController =
        TextEditingController(text: widget.user.relationshipStatus); // New
    _currentCityController =
        TextEditingController(text: widget.user.currentCity); // New
    _hometownController = TextEditingController(text: widget.user.hometown);
    _bioController = TextEditingController(text: widget.user.bio);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _relationshipStatusController.dispose(); // New
    _currentCityController.dispose(); // New
    _hometownController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _selectBirthDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.coral,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedBirthDate) {
      setState(() {
        _selectedBirthDate = picked;
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isUploading = true;
      });

      try {
        String userId = FirebaseAuth.instance.currentUser!.uid;
        String? imageUrl = _profileImageUrl;

        // Upload new image if selected
        if (_imageFile != null) {
          // Create the storage reference
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('profile_images')
              .child('$userId.jpg');

          print("Uploading image to Firebase Storage: ${_imageFile!.path}");

          // Create the upload task
          UploadTask uploadTask = storageRef.putFile(_imageFile!);

          // Wait for the upload to complete
          await uploadTask.whenComplete(() => print("Image upload complete"));

          // Get the download URL
          imageUrl = await storageRef.getDownloadURL();
          print("Image uploaded successfully, URL: $imageUrl");
        }

        // Update user profile in Firestore
        Map<String, dynamic> updateData = {
          'name': _nameController.text.trim(),
          'birthDate': _selectedBirthDate,
          'relationshipStatus': _relationshipStatusController.text.trim(),
          'currentCity': _currentCityController.text.trim(),
          'hometown': _hometownController.text.trim(),
          'bio': _bioController.text.trim(),
        };

        // Only add the imageUrl if it's not null and not empty
        if (imageUrl != null && imageUrl.isNotEmpty) {
          updateData['profileImageUrl'] = imageUrl;
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update(updateData);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );

        Navigator.pop(context, true); // Return true to indicate success
      } catch (e) {
        print("Error updating profile: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      } finally {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate age from selected birth date for display
    String ageText = 'Not specified';
    if (_selectedBirthDate != null) {
      final today = DateTime.now();
      int age = today.year - _selectedBirthDate!.year;
      if (today.month < _selectedBirthDate!.month ||
          (today.month == _selectedBirthDate!.month &&
              today.day < _selectedBirthDate!.day)) {
        age--;
      }
      ageText = '$age years old';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.white,
        titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20),
        elevation: 4,
      ),
      body: _isUploading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Image
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.coral.withOpacity(0.5),
                                width: 2,
                              ),
                            ),
                            child: ClipOval(
                              child: _imageFile != null
                                  ? Image.file(
                                      _imageFile!,
                                      fit: BoxFit.cover,
                                    )
                                  : (_profileImageUrl != null &&
                                          _profileImageUrl!.isNotEmpty
                                      ? Image.network(
                                          _profileImageUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return Container(
                                              color: AppTheme.coral
                                                  .withOpacity(0.2),
                                              child: Center(
                                                child: Text(
                                                  _nameController
                                                          .text.isNotEmpty
                                                      ? _nameController.text[0]
                                                          .toUpperCase()
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
                                          color:
                                              AppTheme.coral.withOpacity(0.2),
                                          child: Center(
                                            child: Text(
                                              _nameController.text.isNotEmpty
                                                  ? _nameController.text[0]
                                                      .toUpperCase()
                                                  : '?',
                                              style: TextStyle(
                                                fontSize: 60,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.coral,
                                              ),
                                            ),
                                          ),
                                        )),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppTheme.coral,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                ),
                                onPressed: _pickImage,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Name
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Age field (new)
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () => _selectBirthDate(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Birthday',
                          hintText: 'Select your birthday',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.cake),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedBirthDate == null
                                  ? 'No date selected'
                                  : '${_selectedBirthDate!.month}/${_selectedBirthDate!.day}/${_selectedBirthDate!.year} ($ageText)',
                            ),
                            const Icon(Icons.calendar_today),
                          ],
                        ),
                      ),
                    ),

                    // Relationship Status (new)
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _relationshipStatusController.text.isEmpty ||
                              !_relationshipOptions
                                  .contains(_relationshipStatusController.text)
                          ? 'Don\'t show'
                          : _relationshipStatusController.text,
                      decoration: const InputDecoration(
                        labelText: 'Relationship Status',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.favorite),
                      ),
                      items: _relationshipOptions.map((status) {
                        return DropdownMenuItem<String>(
                          value: status,
                          child: Text(status),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          _relationshipStatusController.text = value;
                        }
                      },
                    ),

                    // Current City (new)
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _currentCityController,
                      decoration: const InputDecoration(
                        labelText: 'Current City',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_city),
                      ),
                    ),

                    // Hometown
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _hometownController,
                      decoration: const InputDecoration(
                        labelText: 'Hometown',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.home),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Bio
                    TextFormField(
                      controller: _bioController,
                      decoration: const InputDecoration(
                        labelText: 'Bio',
                        border: OutlineInputBorder(),
                        helperText:
                            'Tell others about yourself (max 150 words)',
                        prefixIcon: Icon(Icons.info),
                      ),
                      maxLines: 4,
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          final wordCount = value
                              .split(' ')
                              .where((word) => word.isNotEmpty)
                              .length;
                          if (wordCount > 150) {
                            return 'Bio must be 150 words or less';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),

                    // Info text about other profile sections
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info, color: AppTheme.blue, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Other Profile Features',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const Divider(),
                          const Text(
                            'You can edit these from your profile page:',
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          _buildFeatureInfoRow(
                            icon: Icons.mood,
                            color: AppTheme.yellow,
                            title: 'Status',
                            description: 'Share what you\'re up to',
                          ),
                          _buildFeatureInfoRow(
                            icon: Icons.interests,
                            color: AppTheme.green,
                            title: 'Interests',
                            description: 'Add your interests (up to 5)',
                          ),
                          _buildFeatureInfoRow(
                            icon: Icons.favorite,
                            color: AppTheme.blue,
                            title: 'Local Favorites',
                            description: 'Add your favorite local places',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: AppTheme.coral,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Save Profile',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFeatureInfoRow({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  description,
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
    );
  }
}
