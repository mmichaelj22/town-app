import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_header.dart';
import '../utils/blocked_users_screen.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class SettingsScreen extends StatefulWidget {
  final String userId;
  final double detectionRadius;
  final ValueChanged<double> onRadiusChanged;

  const SettingsScreen({
    super.key,
    required this.userId,
    required this.detectionRadius,
    required this.onRadiusChanged,
  });

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _undetectableMode = false;
  bool _isProfilePublic = true; // Default to public
  @override
  void initState() {
    super.initState();
    _loadProfileVisibility();
    _loadUndetectableMode();
  }

  Future<void> _loadUndetectableMode() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _undetectableMode = prefs.getBool('undetectableMode') ?? false;
    });
  }

  Future<void> _toggleUndetectableMode(bool value) async {
    setState(() {
      _undetectableMode = value;
    });

    // Save to local preferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('undetectableMode', value);

    // Update Firestore user document
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({
        'undetectable': value,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value
              ? 'Undetectable mode enabled'
              : 'Undetectable mode disabled'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error updating undetectable mode: $e');
      // Revert UI if update fails
      setState(() {
        _undetectableMode = !value;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating settings: $e')),
      );
    }
  }

  Future<void> _loadProfileVisibility() async {
    try {
      // Get from Firestore to ensure it's in sync with the server
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>?;
        if (data != null) {
          setState(() {
            _isProfilePublic = data['profilePublic'] ?? true;
          });
          return;
        }
      }

      // Fallback to local storage if Firestore fails
      SharedPreferences prefs = await SharedPreferences.getInstance();
      setState(() {
        _isProfilePublic = prefs.getBool('profilePublic') ?? true;
      });
    } catch (e) {
      print("Error loading profile visibility: $e");
      // Fallback to default
      setState(() {
        _isProfilePublic = true;
      });
    }
  }

// Add this method to toggle the profile visibility
  Future<void> _toggleProfileVisibility(bool value) async {
    setState(() {
      _isProfilePublic = value;
    });

    try {
      // Update Firestore user document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({
        'profilePublic': value,
      });

      // Also update local storage for redundancy
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('profilePublic', value);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value
              ? 'Your profile is now public'
              : 'Your profile is now private'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error updating profile visibility: $e');
      // Revert UI if update fails
      setState(() {
        _isProfilePublic = !value;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating settings: $e')),
      );
    }
  }

// Method to handle logout in settings_screen.dart
  Future<void> _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();

      // Navigate to the root of the app (which will show SignInScreen via AuthGate)
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);

      // Optional: Show a success message
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

  // Show confirmation dialog
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

  Widget _buildSettingsItem({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool showBorder = true,
    Widget? trailing,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                trailing ??
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey[400],
                    ),
              ],
            ),
          ),
        ),
        if (showBorder) Divider(color: Colors.grey[300], height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Custom gradient header
          CustomHeader(
            title: 'Settings',
            subtitle: 'Customize your experience',
            primaryColor: AppTheme.orange, // Using orange from theme
          ),

          // Settings content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Detection Radius Card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child:
                                    Icon(Icons.radar, color: AppTheme.orange),
                              ),
                              const SizedBox(width: 12),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Detection Radius',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'How far to look for nearby users',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '50 ft',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                '500 ft',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: AppTheme.orange,
                              inactiveTrackColor:
                                  AppTheme.orange.withOpacity(0.2),
                              thumbColor: AppTheme.orange,
                              overlayColor: AppTheme.orange.withOpacity(0.3),
                              valueIndicatorColor: AppTheme.orange,
                              valueIndicatorTextStyle:
                                  const TextStyle(color: Colors.white),
                            ),
                            child: Slider(
                              value: widget.detectionRadius,
                              min: 50.0,
                              max: 500.0,
                              divisions: 9,
                              label: '${widget.detectionRadius.round()} ft',
                              onChanged: widget.onRadiusChanged,
                            ),
                          ),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                'Current radius: ${widget.detectionRadius.round()} feet',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.orange,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Combined Settings Card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Undetectable Mode item with switch
                          _buildSettingsItem(
                            context: context,
                            icon: Icons.visibility_off,
                            iconColor: Colors.purple,
                            title: 'Undetectable Mode',
                            subtitle: _undetectableMode
                                ? 'On - Others cannot see you nearby'
                                : 'Off - You are visible to others nearby',
                            onTap: () {
                              // Toggle when tapped
                              _toggleUndetectableMode(!_undetectableMode);
                            },
                            trailing: Switch(
                              value: _undetectableMode,
                              onChanged: _toggleUndetectableMode,
                              activeColor: Colors.purple,
                            ),
                          ),
                          // Profile Visibility item with switch
                          _buildSettingsItem(
                            context: context,
                            icon: Icons.visibility,
                            iconColor: Colors.indigo,
                            title: 'Profile Visibility',
                            subtitle: _isProfilePublic
                                ? 'Public - Anyone nearby can view your profile'
                                : 'Private - Only friends can view your profile',
                            onTap: () {
                              _toggleProfileVisibility(!_isProfilePublic);
                            },
                            trailing: Switch(
                              value: _isProfilePublic,
                              onChanged: _toggleProfileVisibility,
                              activeColor: Colors.indigo,
                            ),
                          ),
                          // Blocked Users item
                          _buildSettingsItem(
                            context: context,
                            icon: Icons.block,
                            iconColor: Colors.red,
                            title: 'Blocked Users',
                            subtitle: 'Manage your blocked users list',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      BlockedUsersScreen(userId: widget.userId),
                                ),
                              );
                            },
                          ),

                          // Report Problem item
                          _buildSettingsItem(
                            context: context,
                            icon: Icons.report_problem,
                            iconColor: Colors.amber,
                            title: 'Report a Problem',
                            subtitle: 'Contact support with issues',
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Reporting coming soon!')),
                              );
                            },
                          ),

                          // Log Out item
                          _buildSettingsItem(
                            context: context,
                            icon: Icons.exit_to_app,
                            iconColor: Colors.red,
                            title: 'Log Out',
                            subtitle: 'Sign out of your account',
                            onTap: () => _showLogoutConfirmation(context),
                            showBorder: true,
                            // Import kDebugMode at the top of the file
                          ),
                          if (kDebugMode)
                            _buildSettingsItem(
                              context: context,
                              icon: Icons.bug_report,
                              iconColor: Colors.teal,
                              title: 'Developer Options',
                              subtitle: 'Debug tools for development',
                              onTap: () => _showDeveloperOptions(context),
                              showBorder:
                                  true, // Add a border if it's not the last item
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // App version info
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Town App v1.0.0',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeveloperOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Developer Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: const Text('Reset Intro Animation'),
              subtitle: const Text('Show intro on next app start'),
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('intro_seen', false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content:
                          Text('Intro animation will show on next restart')),
                );
                Navigator.pop(context);
              },
            ),
            // Add other debug options as needed
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }
}
