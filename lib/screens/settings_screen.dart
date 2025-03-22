import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Add this import

class SettingsScreen extends StatelessWidget {
  final double detectionRadius;
  final ValueChanged<double> onRadiusChanged;

  const SettingsScreen({
    super.key,
    required this.detectionRadius,
    required this.onRadiusChanged,
  });

  // Add this method to handle logout
  Future<void> _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      // Navigate back to login page - will happen automatically due to AuthGate
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully logged out')),
      );
    } catch (e) {
      print("Error signing out: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.white,
        elevation: 4,
        titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Detection Radius', style: TextStyle(fontSize: 18)),
            Slider(
              value: detectionRadius,
              min: 50.0,
              max: 500.0,
              divisions: 9,
              label: '${detectionRadius.round()} ft',
              onChanged: onRadiusChanged,
            ),
            Text('Current radius: ${detectionRadius.round()} feet'),

            const SizedBox(height: 32), // Add spacing

            // Add a divider
            const Divider(),

            // Add Account section
            const Text('Account',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Add Logout button
            InkWell(
              onTap: () => _showLogoutConfirmation(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Row(
                  children: [
                    const Icon(Icons.logout, color: Colors.red),
                    const SizedBox(width: 16),
                    const Text(
                      'Log Out',
                      style: TextStyle(fontSize: 16, color: Colors.red),
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_forward_ios,
                        color: Colors.grey[400], size: 16),
                  ],
                ),
              ),
            ),

            // Add a divider after logout
            const Divider(),
          ],
        ),
      ),
    );
  }

  // Add confirmation dialog
  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _logout(context);
            },
            child: const Text('LOG OUT', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
