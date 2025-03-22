import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class EditProfileScreen extends StatefulWidget {
  final String name;
  final String gender;
  final String hometown;
  final String bio;
  final String profileImageUrl;

  const EditProfileScreen({
    super.key,
    required this.name,
    required this.gender,
    required this.hometown,
    required this.bio,
    required this.profileImageUrl,
  });

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _genderController;
  late TextEditingController _hometownController;
  late TextEditingController _bioController;

  File? _imageFile;
  bool _isUploading = false;
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.name);
    _genderController = TextEditingController(text: widget.gender);
    _hometownController = TextEditingController(text: widget.hometown);
    _bioController = TextEditingController(text: widget.bio);
    _profileImageUrl = widget.profileImageUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _genderController.dispose();
    _hometownController.dispose();
    _bioController.dispose();
    super.dispose();
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

// Update the _saveProfile method in edit_profile_screen.dart

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
          print(
              "Current user auth state: ${FirebaseAuth.instance.currentUser != null ? 'Authenticated' : 'Not authenticated'}");
          print("Current user ID: ${FirebaseAuth.instance.currentUser?.uid}");
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
          'gender': _genderController.text.trim(),
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
        print("Error details: ${e.toString()}");
        // Print the stack trace to see where the error occurs
        print(StackTrace.current);
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
                                color: Colors.grey[300]!,
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
                                            return const Icon(
                                              Icons.person,
                                              size: 80,
                                              color: Colors.grey,
                                            );
                                          },
                                        )
                                      : const Icon(
                                          Icons.person,
                                          size: 80,
                                          color: Colors.grey,
                                        )),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFF07004D),
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
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Gender
                    TextFormField(
                      controller: _genderController,
                      decoration: const InputDecoration(
                        labelText: 'Gender',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Hometown
                    TextFormField(
                      controller: _hometownController,
                      decoration: const InputDecoration(
                        labelText: 'Hometown',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Bio
                    TextFormField(
                      controller: _bioController,
                      decoration: const InputDecoration(
                        labelText: 'Bio',
                        border: OutlineInputBorder(),
                        helperText: 'Maximum 150 words',
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
                    const SizedBox(height: 32),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: const Color(0xFF07004D),
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
}
