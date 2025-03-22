import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';
import 'camera_screen.dart';
import 'sign_in_screen.dart';
import 'package:firebase_storage/firebase_storage.dart';

class RegisterScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const RegisterScreen({super.key, required this.cameras});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  File? _profileImage;
  bool _isVerifying = false;

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

// For later use
  // const apiKey = '7ciUHGFNOLhsBnY2z2BhoIXxFM7hgbb9';
  // const apiSecret = 'LbMKD-tKl37_XBRnkiP5A3c9ggZscxVx';

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

      var request = http.MultipartRequest('POST',
          Uri.parse('https://api-us.faceplusplus.com/facepp/v3/compare'));
      request.fields['api_key'] = apiKey;
      request.fields['api_secret'] = apiSecret;
      request.files.add(await http.MultipartFile.fromPath(
          'image_file1', _profileImage!.path));
      request.files
          .add(await http.MultipartFile.fromPath('image_file2', selfie.path));

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      print("Face++ API response status: ${response.statusCode}");
      print("Face++ API response: $responseData");

      setState(() => _isVerifying = false);

      if (response.statusCode == 200 && responseData.contains('"confidence"')) {
        var confidence = double.parse(RegExp(r'"confidence":(\d+\.\d+)')
            .firstMatch(responseData)!
            .group(1)!);
        print("Face confidence: $confidence");
        return confidence > 80.0;
      } else {
        print("Failed to parse confidence from response");
        return false;
      }
    } catch (e) {
      print("Error during face verification: $e");
      setState(() => _isVerifying = false);
      return false;
    }
  }

// Update the _register method in register_screen.dart to upload the profile image

  Future<void> _register() async {
    try {
      String email = _emailController.text.trim();
      String password = _passwordController.text.trim();

      // Validate email and password
      if (email.isEmpty || !email.contains('@')) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter a valid email')));
        return;
      }
      if (password.isEmpty || password.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Password must be at least 6 characters')));
        return;
      }

      // Check if profile image is selected
      if (_profileImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a profile image')));
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

        String name = email.contains('@')
            ? email.split('@')[0]
            : 'User'; // Fallback to 'User' if split fails

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
          'name': name,
          'email': email,
          'profileImageUrl': profileImageUrl ?? '',
          'gender': 'Not specified',
          'hometown': 'Not specified',
          'bio': 'No bio yet.',
          'friends': [],
          'latitude': 0.0,
          'longitude': 0.0,
        });

        print("Registration successful for $userId");
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registration successful!')));
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
    } catch (e) {
      print("Error registering: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isVerifying
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _pickProfileImage,
                    child: Text(_profileImage == null
                        ? 'Pick Profile Image'
                        : 'Image Selected'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _register,
                    child: const Text('Register'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              SignInScreen(cameras: widget.cameras)),
                    ),
                    child: const Text('Already have an account? Sign In'),
                  ),
                ],
              ),
      ),
    );
  }
}
