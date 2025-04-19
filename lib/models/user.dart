// lib/models/user.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

// Define the LocalFavorite class first since it's used in TownUser
class LocalFavorite {
  final String name;
  final String type;
  final String description;
  final double? latitude;
  final double? longitude;

  LocalFavorite({
    required this.name,
    required this.type,
    this.description = '',
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory LocalFavorite.fromMap(Map<String, dynamic> map) {
    return LocalFavorite(
      name: map['name'] ?? '',
      type: map['type'] ?? '',
      description: map['description'] ?? '',
      latitude: map['latitude'],
      longitude: map['longitude'],
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
  final String gender;
  final String hometown;
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
    this.gender = 'Not specified',
    this.hometown = 'Not specified',
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

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'profileImageUrl': profileImageUrl ?? '',
      'gender': gender,
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
      gender: map['gender'] ?? 'Not specified',
      hometown: map['hometown'] ?? 'Not specified',
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
    String? gender,
    String? hometown,
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
      gender: gender ?? this.gender,
      hometown: hometown ?? this.hometown,
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
