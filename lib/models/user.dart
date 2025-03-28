// lib/models/user.dart - Updated with new profile fields

import 'dart:io';

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
          (map['statusUpdatedAt'] as dynamic)?.toDate() ?? DateTime.now(),
      localFavorites: favorites,
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
    );
  }
}

class LocalFavorite {
  final String name;
  final String type; // e.g., 'Restaurant', 'Park', 'Coffee Shop'
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
