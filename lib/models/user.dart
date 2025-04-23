// lib/models/user.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

// Define the LocalFavorite class first since it's used in TownUser
class LocalFavorite {
  final String id; // Add a unique identifier
  final String name;
  final String placeId; // Google Maps Place ID for the location
  final String recommendation; // User's recommendation about the place
  final double latitude;
  final double longitude;
  final String formattedAddress; // Complete address from Google

  LocalFavorite({
    this.id = '',
    required this.name,
    required this.placeId,
    this.recommendation = '',
    required this.latitude,
    required this.longitude,
    required this.formattedAddress,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'placeId': placeId,
      'recommendation': recommendation,
      'latitude': latitude,
      'longitude': longitude,
      'formattedAddress': formattedAddress,
    };
  }

  factory LocalFavorite.fromMap(Map<String, dynamic> map) {
    return LocalFavorite(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      placeId: map['placeId'] ?? '',
      recommendation: map['recommendation'] ?? '',
      latitude: map['latitude'] ?? 0.0,
      longitude: map['longitude'] ?? 0.0,
      formattedAddress: map['formattedAddress'] ?? '',
    );
  }
}

class TownUser {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final File? profilePicture;
  final String? profileImageUrl;
  final DateTime? birthDate;
  final String hometown;
  final String currentCity;
  final String relationshipStatus;
  final String bio;
  final List<String> interests;
  final String statusMessage;
  final String statusEmoji;
  final DateTime statusUpdatedAt;
  final List<LocalFavorite> localFavorites;
  final List<Map<String, dynamic>>
      friends; // Updated to include more friend info
  final List<String> pendingFriendRequests; // Friend requests received
  final List<String> sentFriendRequests; // Friend requests sent

  TownUser({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.profilePicture,
    this.profileImageUrl,
    this.birthDate,
    this.relationshipStatus = 'Not specified',
    this.hometown = 'Not specified',
    this.currentCity = 'Not specified',
    this.bio = 'No bio yet.',
    this.interests = const [],
    this.statusMessage = '',
    this.statusEmoji = '',
    DateTime? statusUpdatedAt,
    this.localFavorites = const [],
    this.friends = const [],
    this.pendingFriendRequests = const [],
    this.sentFriendRequests = const [],
  }) : statusUpdatedAt = statusUpdatedAt ?? DateTime.now();

  // Calculate age based on birthDate
  int get age {
    if (birthDate == null) return 0;

    final today = DateTime.now();
    int age = today.year - birthDate!.year;

    // Account for birthday not yet happened this year
    if (today.month < birthDate!.month ||
        (today.month == birthDate!.month && today.day < birthDate!.day)) {
      age--;
    }

    return age;
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'profileImageUrl': profileImageUrl ?? '',
      'birthDate': birthDate,
      'relationshipStatus': relationshipStatus,
      'currentCity': currentCity,
      'hometown': hometown,
      'bio': bio,
      'interests': interests,
      'statusMessage': statusMessage,
      'statusEmoji': statusEmoji,
      'statusUpdatedAt': statusUpdatedAt,
      'localFavorites':
          localFavorites.map((favorite) => favorite.toMap()).toList(),
      'friends': friends,
      'pendingFriendRequests': pendingFriendRequests,
      'sentFriendRequests': sentFriendRequests,
    };
  }

  // Create from Firestore document
  factory TownUser.fromMap(Map<String, dynamic> map, String id) {
    List<LocalFavorite> favorites = [];
    if (map['localFavorites'] != null) {
      favorites = List<Map<String, dynamic>>.from(map['localFavorites'])
          .map((favMap) => LocalFavorite.fromMap(favMap))
          .toList();
    }

    // Handle friends list which can be in different formats
    List<Map<String, dynamic>> friendsList = [];
    if (map['friends'] != null) {
      final rawFriends = map['friends'];
      if (rawFriends is List) {
        for (var friend in rawFriends) {
          if (friend is String) {
            // Old format - just the name
            friendsList.add({
              'id': friend,
              'name': friend,
            });
          } else if (friend is Map) {
            // New format - includes ID and name
            friendsList.add(Map<String, dynamic>.from(friend));
          }
        }
      }
    }

    return TownUser(
      id: id,
      name: map['name'] ?? 'User',
      latitude: map['latitude'] ?? 0.0,
      longitude: map['longitude'] ?? 0.0,
      profileImageUrl: map['profileImageUrl'],
      birthDate: map['birthDate'] != null
          ? (map['birthDate'] as Timestamp).toDate()
          : null,
      relationshipStatus:
          map['relationshipStatus'] ?? 'Not specified', // New field
      hometown: map['hometown'] ?? 'Not specified',
      currentCity: map['currentCity'] ?? 'Not specified', // New field
      bio: map['bio'] ?? 'No bio yet.',
      interests: List<String>.from(map['interests'] ?? []),
      statusMessage: map['statusMessage'] ?? '',
      statusEmoji: map['statusEmoji'] ?? '',
      statusUpdatedAt:
          (map['statusUpdatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      localFavorites: favorites,
      friends: friendsList,
      pendingFriendRequests:
          List<String>.from(map['pendingFriendRequests'] ?? []),
      sentFriendRequests: List<String>.from(map['sentFriendRequests'] ?? []),
    );
  }

  // Create a copy with updated fields
  TownUser copyWith({
    String? name,
    double? latitude,
    double? longitude,
    File? profilePicture,
    String? profileImageUrl,
    DateTime? birthDate,
    String? relationshipStatus, // New field
    String? hometown,
    String? currentCity, // New field
    String? bio,
    List<String>? interests,
    String? statusMessage,
    String? statusEmoji,
    DateTime? statusUpdatedAt,
    List<LocalFavorite>? localFavorites,
    List<Map<String, dynamic>>? friends,
    List<String>? pendingFriendRequests,
    List<String>? sentFriendRequests,
  }) {
    return TownUser(
      id: this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      profilePicture: profilePicture ?? this.profilePicture,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      birthDate: birthDate ?? this.birthDate,
      relationshipStatus:
          relationshipStatus ?? this.relationshipStatus, // New field
      hometown: hometown ?? this.hometown,
      currentCity: currentCity ?? this.currentCity, // New field
      bio: bio ?? this.bio,
      interests: interests ?? this.interests,
      statusMessage: statusMessage ?? this.statusMessage,
      statusEmoji: statusEmoji ?? this.statusEmoji,
      statusUpdatedAt: statusUpdatedAt ?? this.statusUpdatedAt,
      localFavorites: localFavorites ?? this.localFavorites,
      friends: friends ?? this.friends,
      pendingFriendRequests:
          pendingFriendRequests ?? this.pendingFriendRequests,
      sentFriendRequests: sentFriendRequests ?? this.sentFriendRequests,
    );
  }
}

// Notification model for friend requests
class Notification {
  final String id;
  final String type; // 'friendRequest', 'friendRequestAccepted', etc.
  final String senderId;
  final String senderName;
  final DateTime timestamp;
  final bool read;

  Notification({
    required this.id,
    required this.type,
    required this.senderId,
    required this.senderName,
    required this.timestamp,
    this.read = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'senderId': senderId,
      'senderName': senderName,
      'timestamp': timestamp,
      'read': read,
    };
  }

  factory Notification.fromMap(Map<String, dynamic> map, String id) {
    return Notification(
      id: id,
      type: map['type'] ?? 'unknown',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? 'Unknown User',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      read: map['read'] ?? false,
    );
  }
}

// Database structure overview:

// - users/
//   - {userId}/
//     - name: String
//     - latitude: double
//     - longitude: double
//     - profileImageUrl: String
//     - friends: Array<Map> (new format with id and name)
//     - pendingFriendRequests: Array<String> (userIds who sent requests)
//     - sentFriendRequests: Array<String> (userIds the user sent requests to)
//     - blocked_users/
//       - {blockedUserId}: Map
//         - blockedAt: Timestamp
//         - name: String
//     - notifications/
//       - {notificationId}: Map
//         - type: String ('friendRequest', 'friendRequestAccepted', etc.)
//         - senderId: String
//         - senderName: String
//         - timestamp: Timestamp
//         - read: boolean
