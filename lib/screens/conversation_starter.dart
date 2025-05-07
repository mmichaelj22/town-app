import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

class ConversationStarter extends StatefulWidget {
  final String userId;
  final Function(String, String, List<String>) onCreateConversation;
  final double detectionRadius;

  const ConversationStarter({
    Key? key,
    required this.userId,
    required this.onCreateConversation,
    required this.detectionRadius,
  }) : super(key: key);

  @override
  _ConversationStarterState createState() => _ConversationStarterState();
}

class _ConversationStarterState extends State<ConversationStarter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _heightAnimation;
  bool _isExpanded = false;
  String _selectedType = '';
  String? _selectedEmoji;
  final TextEditingController _messageController = TextEditingController();
  List<String> _selectedUsers = [];
  List<String> _nearbyUsers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _heightAnimation = Tween<double>(
      begin: 60,
      end: 320,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
        _loadNearbyUsers();
      } else {
        _controller.reverse();
        _selectedType = '';
        _selectedUsers = [];
        _selectedEmoji = null;
        _messageController.clear();
      }
    });
  }

  Future<void> _loadNearbyUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get current user location
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (!userDoc.exists) {
        setState(() {
          _isLoading = false;
          _nearbyUsers = [];
        });
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>?;
      if (userData == null ||
          !userData.containsKey('latitude') ||
          !userData.containsKey('longitude')) {
        setState(() {
          _isLoading = false;
          _nearbyUsers = [];
        });
        return;
      }

      double userLat = userData['latitude'] as double;
      double userLon = userData['longitude'] as double;

      // Query all users
      QuerySnapshot allUsers =
          await FirebaseFirestore.instance.collection('users').get();

      List<String> nearby = [];

      for (var doc in allUsers.docs) {
        if (doc.id != widget.userId) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data != null &&
              data.containsKey('latitude') &&
              data.containsKey('longitude') &&
              data.containsKey('name')) {
            double lat = data['latitude'] as double;
            double lon = data['longitude'] as double;
            String name = data['name'] as String;

            // Calculate distance (simplified for now - would need proper geolocation)
            double distance = _calculateDistance(userLat, userLon, lat, lon);

            if (distance <= widget.detectionRadius) {
              nearby.add(name);
            }
          }
        }
      }

      setState(() {
        _nearbyUsers = nearby;
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading nearby users: $e");
      setState(() {
        _isLoading = false;
        _nearbyUsers = [];
      });
    }
  }

  // Simplified distance calculation (not accurate for real-world use)
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    // This is a placeholder. In a real app, use Geolocator package or similar
    var dLat = (lat2 - lat1).abs();
    var dLon = (lon2 - lon1).abs();
    return (dLat + dLon) * 111000; // rough conversion to meters
  }

  void _selectConversationType(String type) {
    setState(() {
      _selectedType = type;
      _selectedUsers = [];
      _selectedEmoji = null;
      _messageController.clear();
    });
  }

  void _toggleUserSelection(String userName) {
    setState(() {
      if (_selectedUsers.contains(userName)) {
        _selectedUsers.remove(userName);
      } else {
        if (_selectedType == 'Private Chat' && _selectedUsers.isEmpty) {
          _selectedUsers.add(userName);
        } else if (_selectedType == 'Private Group') {
          _selectedUsers.add(userName);
        }
      }
    });
  }

  void _selectEmoji(String emoji) {
    setState(() {
      _selectedEmoji = emoji;
      _messageController.text = emoji;
    });
  }

  void _createConversation() {
    if (_selectedType.isEmpty) return;

    String topic = _messageController.text.trim();
    if (_selectedType == 'Private Chat' && _selectedEmoji == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an emoji')),
      );
      return;
    }

    if (topic.isEmpty &&
        (_selectedType == 'Private Group' || _selectedType == 'Public Group')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a topic for the conversation')),
      );
      return;
    }

    if ((_selectedType == 'Private Chat' || _selectedType == 'Private Group') &&
        _selectedUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one recipient')),
      );
      return;
    }

    String chatType;
    if (_selectedType == 'Private Chat') {
      chatType = 'Private';
    } else if (_selectedType == 'Private Group') {
      chatType = 'Private Group';
    } else {
      chatType = 'Group';
    }

    widget.onCreateConversation(topic, chatType, _selectedUsers);
    _toggleExpanded();
  }

  Widget _buildEmojiSelector() {
    final emojis = ['👋', '😍', '❓', '❗'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: emojis
          .map((emoji) => GestureDetector(
                onTap: () => _selectEmoji(emoji),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(30),
                    border: _selectedEmoji == emoji
                        ? Border.all(color: AppTheme.blue, width: 3)
                        : null,
                    boxShadow: _selectedEmoji == emoji
                        ? [
                            BoxShadow(
                                color: AppTheme.blue.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 2)
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 30),
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          height: _heightAnimation.value,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Always visible part
              GestureDetector(
                onTap: _toggleExpanded,
                child: Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isExpanded ? Icons.close : Icons.add_circle_outline,
                        color: AppTheme.blue,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _isExpanded
                              ? 'New Conversation'
                              : 'Start a conversation!',
                          style: TextStyle(
                            color:
                                _isExpanded ? Colors.black : Colors.grey[600],
                            fontWeight: _isExpanded
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Expandable part
              if (_isExpanded && _heightAnimation.value > 60)
                Expanded(
                  child: Stack(
                    children: [
                      // Main content
                      SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Conversation type selector
                              if (_selectedType.isEmpty)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Select conversation type:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _buildTypeOption(
                                        'Private Chat', AppTheme.yellow),
                                    _buildTypeOption(
                                        'Private Group', AppTheme.coral),
                                    _buildTypeOption(
                                        'Public Group', AppTheme.green),
                                  ],
                                )
                              else
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          _selectedType,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const Spacer(),
                                        TextButton(
                                          onPressed: () {
                                            _selectConversationType('');
                                          },
                                          child: const Text('Change'),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // Input field or emoji selector
                                    if (_selectedType == 'Private Chat')
                                      _buildEmojiSelector()
                                    else
                                      TextField(
                                        controller: _messageController,
                                        decoration: InputDecoration(
                                          hintText: 'Enter conversation topic',
                                          border: const OutlineInputBorder(),
                                          suffixIcon: IconButton(
                                            icon: const Icon(Icons.clear),
                                            onPressed: () {
                                              _messageController.clear();
                                            },
                                          ),
                                        ),
                                      ),

                                    const SizedBox(height: 24),

                                    // User selector (not for public groups)
                                    if (_selectedType != 'Public Group')
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _selectedType == 'Private Chat'
                                                ? 'Select recipient:'
                                                : 'Select recipients:',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 8),
                                          _isLoading
                                              ? const Center(
                                                  child:
                                                      CircularProgressIndicator())
                                              : _nearbyUsers.isEmpty
                                                  ? const Text(
                                                      'No nearby users found')
                                                  : Wrap(
                                                      spacing: 8,
                                                      runSpacing: 8,
                                                      children: _nearbyUsers
                                                          .map((user) {
                                                        bool isSelected =
                                                            _selectedUsers
                                                                .contains(user);
                                                        return FilterChip(
                                                          avatar: CircleAvatar(
                                                            backgroundColor:
                                                                isSelected
                                                                    ? AppTheme
                                                                        .blue
                                                                    : Colors.grey[
                                                                        300],
                                                            child: Text(
                                                              user[0]
                                                                  .toUpperCase(),
                                                              style: TextStyle(
                                                                color: isSelected
                                                                    ? Colors
                                                                        .white
                                                                    : Colors
                                                                        .black,
                                                              ),
                                                            ),
                                                          ),
                                                          label: Text(user),
                                                          selected: isSelected,
                                                          selectedColor:
                                                              AppTheme.blue
                                                                  .withOpacity(
                                                                      0.2),
                                                          onSelected: (_) {
                                                            _toggleUserSelection(
                                                                user);
                                                          },
                                                        );
                                                      }).toList(),
                                                    ),
                                        ],
                                      ),

                                    // Space for bottom buttons
                                    const SizedBox(height: 60),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),

                      // Bottom buttons
                      if (_selectedType.isNotEmpty)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, -2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Cancel button
                                TextButton(
                                  onPressed: _toggleExpanded,
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.grey[700],
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                  ),
                                  child: const Text('Cancel'),
                                ),

                                // Create button
                                ElevatedButton(
                                  onPressed: _createConversation,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.blue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                  ),
                                  child: const Text('Create'),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTypeOption(String title, Color color) {
    return GestureDetector(
      onTap: () => _selectConversationType(title),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: 1),
        ),
        child: Row(
          children: [
            Icon(
              title == 'Private Chat'
                  ? Icons.person
                  : title == 'Private Group'
                      ? Icons.group
                      : Icons.public,
              color: color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14),
          ],
        ),
      ),
    );
  }
}
