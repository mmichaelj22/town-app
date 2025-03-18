import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';
import 'camera_screen.dart';
import 'sign_in_screen.dart';

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

  Future<bool> _verifyFace() async {
    if (_profileImage == null) return false;
    setState(() => _isVerifying = true);

    final controller =
        CameraController(widget.cameras[0], ResolutionPreset.medium);
    await controller.initialize();
    final selfie = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => CameraScreen(controller: controller)),
    );
    await controller.dispose();

    if (selfie == null) {
      setState(() => _isVerifying = false);
      return false;
    }

    const apiKey = 'YOUR_FACEPP_API_KEY';
    const apiSecret = 'YOUR_FACEPP_API_SECRET';
    var request = http.MultipartRequest(
        'POST', Uri.parse('https://api-us.faceplusplus.com/facepp/v3/compare'));
    request.fields['api_key'] = apiKey;
    request.fields['api_secret'] = apiSecret;
    request.files.add(
        await http.MultipartFile.fromPath('image_file1', _profileImage!.path));
    request.files
        .add(await http.MultipartFile.fromPath('image_file2', selfie.path));

    var response = await request.send();
    var responseData = await response.stream.bytesToString();
    setState(() => _isVerifying = false);

    if (response.statusCode == 200 && responseData.contains('"confidence"')) {
      var confidence = double.parse(RegExp(r'"confidence":(\d+\.\d+)')
          .firstMatch(responseData)!
          .group(1)!);
      return confidence > 80.0;
    }
    return false;
  }

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

      if (await _verifyFace()) {
        UserCredential userCredential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        String name = email.contains('@')
            ? email.split('@')[0]
            : 'User'; // Fallback to 'User' if split fails
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
          'name': name,
          'email': email,
          'profileImage': 'pending',
          'friends': [],
        });
        print("Registration successful for ${userCredential.user!.uid}");
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Face verification failed')));
      }
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
