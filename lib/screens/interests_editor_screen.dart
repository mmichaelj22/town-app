// lib/screens/interests_editor_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

class InterestsEditorScreen extends StatefulWidget {
  final List<String> currentInterests;

  const InterestsEditorScreen({
    Key? key,
    required this.currentInterests,
  }) : super(key: key);

  @override
  _InterestsEditorScreenState createState() => _InterestsEditorScreenState();
}

class _InterestsEditorScreenState extends State<InterestsEditorScreen> {
  final TextEditingController _customInterestController =
      TextEditingController();
  List<String> _selectedInterests = [];
  bool _isSubmitting = false;
  final int _maxInterests = 5;

  // Predefined interest categories
  final List<String> _interestCategories = [
    'Music',
    'Movies',
    'Books',
    'Art',
    'Photography',
    'Hiking',
    'Travel',
    'Cooking',
    'Baking',
    'Coffee',
    'Fitness',
    'Yoga',
    'Running',
    'Cycling',
    'Swimming',
    'Gaming',
    'Technology',
    'Coding',
    'Design',
    'Fashion',
    'Dancing',
    'Singing',
    'Writing',
    'Gardening',
    'Crafts',
    'Sports',
    'Football',
    'Basketball',
    'Tennis',
    'Soccer',
    'Pets',
    'Dogs',
    'Cats',
    'Plants',
    'Nature',
    'History',
    'Science',
    'Politics',
    'Philosophy',
    'Psychology',
  ];

  @override
  void initState() {
    super.initState();
    _selectedInterests = List.from(widget.currentInterests);
  }

  @override
  void dispose() {
    _customInterestController.dispose();
    super.dispose();
  }

  Future<void> _saveInterests() async {
    if (_selectedInterests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one interest')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'interests': _selectedInterests,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Interests updated successfully')),
      );

      Navigator.pop(context, true); // Return true to indicate success
    } catch (e) {
      print("Error updating interests: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating interests: $e')),
      );
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _toggleInterest(String interest) {
    setState(() {
      if (_selectedInterests.contains(interest)) {
        _selectedInterests.remove(interest);
      } else {
        if (_selectedInterests.length < _maxInterests) {
          _selectedInterests.add(interest);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('You can only select up to $_maxInterests interests')),
          );
        }
      }
    });
  }

  void _addCustomInterest() {
    final interest = _customInterestController.text.trim();
    if (interest.isEmpty) {
      return;
    }

    // Check if the interest already exists
    if (_selectedInterests.contains(interest) ||
        _interestCategories.contains(interest)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This interest already exists')),
      );
      return;
    }

    if (_selectedInterests.length >= _maxInterests) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('You can only select up to $_maxInterests interests')),
      );
      return;
    }

    setState(() {
      _selectedInterests.add(interest);
      _customInterestController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Interests'),
        backgroundColor: Colors.white,
        titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20),
        elevation: 4,
      ),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Selected interests display
                Container(
                  color: Colors.grey[100],
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.favorite, color: AppTheme.green),
                          const SizedBox(width: 8),
                          Text(
                            'Selected Interests (${_selectedInterests.length}/$_maxInterests)',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _selectedInterests.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text(
                                  'Select up to 5 interests below',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            )
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _selectedInterests.map((interest) {
                                final colorIndex = interest.hashCode %
                                    AppTheme.squareColors.length;
                                final color = AppTheme.squareColors[colorIndex];

                                return Chip(
                                  backgroundColor: color.withOpacity(0.2),
                                  side: BorderSide(color: color, width: 1),
                                  avatar: CircleAvatar(
                                    backgroundColor: color,
                                    child: Text(
                                      interest[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  label: Text(
                                    interest,
                                    style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  deleteIcon: const Icon(
                                    Icons.cancel,
                                    size: 18,
                                  ),
                                  onDeleted: () {
                                    setState(() {
                                      _selectedInterests.remove(interest);
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                    ],
                  ),
                ),

                // Custom interest input
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _customInterestController,
                          decoration: const InputDecoration(
                            labelText: 'Add custom interest',
                            hintText: 'E.g., Rock climbing',
                            border: OutlineInputBorder(),
                          ),
                          textCapitalization: TextCapitalization.words,
                          onSubmitted: (_) => _addCustomInterest(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.add_circle),
                        color: AppTheme.green,
                        onPressed: _addCustomInterest,
                      ),
                    ],
                  ),
                ),

                // Interest categories
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text(
                        'Popular Interests',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _interestCategories.map((interest) {
                          final isSelected =
                              _selectedInterests.contains(interest);
                          final colorIndex =
                              interest.hashCode % AppTheme.squareColors.length;
                          final color = AppTheme.squareColors[colorIndex];

                          return FilterChip(
                            selected: isSelected,
                            selectedColor: color.withOpacity(0.2),
                            backgroundColor: Colors.grey[200],
                            checkmarkColor: color,
                            side: isSelected
                                ? BorderSide(color: color, width: 1)
                                : null,
                            label: Text(interest),
                            onSelected: (_) => _toggleInterest(interest),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),

                // Save button
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: _saveInterests,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: AppTheme.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Save Interests',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
