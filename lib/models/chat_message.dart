import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String text;
  final String senderId;
  final DateTime timestamp;
  final String? imageUrl;
  final List<String> likes;

  ChatMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.timestamp,
    this.imageUrl,
    this.likes = const [],
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map, String id) {
    return ChatMessage(
      id: id,
      text: map['text'] ?? '',
      senderId: map['senderId'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      imageUrl: map['imageUrl'],
      likes: List<String>.from(map['likes'] ?? []),
    );
  }

  bool isLikedByCurrentUser(String userId) {
    return likes.contains(userId);
  }
}
