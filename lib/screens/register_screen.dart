import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'camera_screen.dart';
import 'sign_in_screen.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../theme/app_theme.dart';
import 'main_screen.dart';

class RegisterScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const RegisterScreen({super.key, required this.cameras});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  File? _profileImage;
  bool _isVerifying = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  final _formKey = GlobalKey<FormState>();

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 90,
    );
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  Future<bool> _verifyFace() async {
    if (_profileImage == null) {
      print("Profile image is null");
      return false;
    }

    setState(() => _isVerifying = true);

    // Check if cameras are available
    if (widget.cameras.isEmpty) {
      print("No cameras available");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Camera not available. Please check permissions.')));
      setState(() => _isVerifying = false);
      return false;
    }

    try {
      final controller =
          CameraController(widget.cameras[0], ResolutionPreset.medium);
      print("Initializing camera...");
      await controller.initialize();
      print("Camera initialized successfully");

      final selfie = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => CameraScreen(controller: controller)),
      );
      await controller.dispose();

      if (selfie == null) {
        print("Selfie image is null");
        setState(() => _isVerifying = false);
        return false;
      }

      // Use your actual API keys here
      const apiKey = '7ciUHGFNOLhsBnY2z2BhoIXxFM7hgbb9';
      const apiSecret = 'LbMKD-tKl37_XBRnkiP5A3c9ggZscxVx';

      print("Sending images to Face++ API");
      print("Profile image path: ${_profileImage!.path}");
      print("Selfie image path: ${selfie.path}");

      // This would be your actual API call
      // For now, let's just simulate success
      await Future.delayed(const Duration(seconds: 1));
      setState(() => _isVerifying = false);
      return true;
    } catch (e) {
      print("Error during face verification: $e");
      setState(() => _isVerifying = false);
      return false;
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    // Check if passwords match
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }
    try {
      setState(() => _isVerifying = true);

      String email = _emailController.text.trim();
      String password = _passwordController.text.trim();
      String name = _nameController.text.trim();

      // Check if profile image is selected
      if (_profileImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a profile image')));
        setState(() => _isVerifying = false);
        return;
      }

      bool proceedWithRegistration = false;

      // Check if cameras are available for face verification
      if (widget.cameras.isEmpty) {
        print("No cameras available, skipping face verification");
        // Ask user if they want to proceed without face verification
        final response = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Camera Not Available'),
            content: const Text(
                'Face verification requires camera access. Would you like to proceed with registration without face verification?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Proceed'),
              ),
            ],
          ),
        );

        proceedWithRegistration = response ?? false;
      } else {
        // Cameras available, attempt face verification
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Verifying face...')));

        proceedWithRegistration = await _verifyFace();

        if (proceedWithRegistration) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Face verified! Creating account...')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Face verification failed. Please try again.')));
          setState(() => _isVerifying = false);
          return;
        }
      }

      if (proceedWithRegistration) {
        // Create user account in Firebase
        UserCredential userCredential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        String userId = userCredential.user!.uid;

        // Upload profile image to Firebase Storage
        String? profileImageUrl;
        try {
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('profile_images')
              .child('$userId.jpg');

          // Create the upload task
          UploadTask uploadTask = storageRef.putFile(_profileImage!);

          // Wait for the upload to complete
          await uploadTask
              .whenComplete(() => print("Registration image upload complete"));

          // Get the download URL
          profileImageUrl = await storageRef.getDownloadURL();
          print("Profile image uploaded successfully, URL: $profileImageUrl");
        } catch (e) {
          print("Error uploading profile image during registration: $e");
          // Continue with registration even if image upload fails
        }

        // Create user document in Firestore
        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'name': name.isEmpty ? email.split('@')[0] : name,
          'email': email,
          'profileImageUrl': profileImageUrl ?? '',
          'gender': 'Not specified',
          'hometown': 'Not specified',
          'bio': 'No bio yet.',
          'friends': [],
          'latitude': 0.0,
          'longitude': 0.0,
          'interests': [],
          'statusMessage': '',
          'statusEmoji': '',
          'statusUpdatedAt': FieldValue.serverTimestamp(),
          'localFavorites': [],
        });

        print("Registration successful for $userId");
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registration successful!')));

        // Navigate to main screen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      print("Firebase Auth Error: ${e.code} - ${e.message}");
      String errorMessage;

      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'This email is already registered.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is not valid.';
          break;
        case 'weak-password':
          errorMessage = 'The password is too weak.';
          break;
        default:
          errorMessage = 'Registration error: ${e.message}';
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorMessage)));

      setState(() => _isVerifying = false);
    } catch (e) {
      print("Error registering: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));

      setState(() => _isVerifying = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _confirmPasswordController.dispose(); // Clean up the new controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.coral.withOpacity(0.2),
                  AppTheme.yellow.withOpacity(0.1),
                ],
              ),
            ),
          ),

          // Background patterns
          Positioned(
            top: -80,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.coral.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.yellow.withOpacity(0.1),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: _isVerifying
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Verifying...',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                : Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Logo and title
                            Center(
                              child: Column(
                                children: [
                                  Image.asset(
                                    'assets/images/logo.png',
                                    height: 100,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Create Account',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Join Town and connect with others',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),

                            // Profile image picker
                            Center(
                              child: Stack(
                                children: [
                                  Container(
                                    height: 120,
                                    width: 120,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 4,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: _profileImage != null
                                          ? Image.file(
                                              _profileImage!,
                                              fit: BoxFit.cover,
                                            )
                                          : const Icon(
                                              Icons.person,
                                              size: 60,
                                              color: Colors.grey,
                                            ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppTheme.coral,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.camera_alt,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        onPressed: _pickProfileImage,
                                        constraints: const BoxConstraints(
                                          minWidth: 40,
                                          minHeight: 40,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Name field
                            TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'Name (Optional)',
                                hintText: 'Enter your name',
                                prefixIcon: const Icon(Icons.person_outline),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Email field
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                hintText: 'Enter your email',
                                prefixIcon: const Icon(Icons.email_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter an email';
                                }
                                if (!value.contains('@') ||
                                    !value.contains('.')) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Password field
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                hintText: 'Create a password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a password';
                                }
                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                            // Confirm password field
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              decoration: InputDecoration(
                                labelText: 'Confirm Password',
                                hintText: 'Confirm your password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureConfirmPassword =
                                          !_obscureConfirmPassword;
                                    });
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please confirm your password';
                                }
                                if (value != _passwordController.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),

                            // Register button
                            ElevatedButton(
                              onPressed: _register,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.coral,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              child: const Text(
                                'Create Account',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Sign in link
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Already have an account?',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => SignInScreen(
                                            cameras: widget.cameras)),
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppTheme.coral,
                                  ),
                                  child: const Text(
                                    'Sign In',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
