import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:camera/camera.dart'; // Add this import
import 'register_screen.dart';
import 'main_screen.dart';

class SignInScreen extends StatelessWidget {
  final List<CameraDescription> cameras; // Add cameras parameter

  const SignInScreen({super.key, required this.cameras}); // Update constructor

  @override
  Widget build(BuildContext context) {
    final _emailController = TextEditingController();
    final _passwordController = TextEditingController();

    Future<void> _signIn() async {
      try {
        String email = _emailController.text.trim();
        String password = _passwordController.text.trim();
        if (email.isEmpty || !email.contains('@') || password.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Please enter a valid email and password')),
          );
          return;
        }

        print("Attempting sign-in with email: $email");
        UserCredential userCredential =
            await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        print("Sign-in successful: ${userCredential.user?.uid}");
        // Force navigation if sign-in succeeds
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      } catch (e) {
        print("Error signing in: $e");
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
        // Check if user is signed in despite error
        User? user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          print("User signed in despite error: ${user.uid}");
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainScreen()),
          );
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Sign In')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
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
              onPressed: _signIn,
              child: const Text('Sign In'),
            ),
            TextButton(
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        RegisterScreen(cameras: cameras)), // Pass cameras
              ),
              child: const Text('Need an account? Register'),
            ),
          ],
        ),
      ),
    );
  }
}
