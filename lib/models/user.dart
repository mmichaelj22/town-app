import 'dart:io';

class TownUser {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final File? profilePicture;

  TownUser({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.profilePicture,
  });
}
