// lib/services/chat_service.dart - New service class
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import '../utils/conversation_manager.dart';

class ChatService {
  final String chatId;
  final String userId;
  final String chatType;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  ChatService({
    required this.chatId,
    required this.userId,
    required this.chatType,
  });

  // Get messages stream
  Stream<QuerySnapshot> get messagesStream {
    return _firestore
        .collection('conversations')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Load participants
  Future<List<String>> loadParticipants() async {
    final doc = await _firestore.collection('conversations').doc(chatId).get();
    if (doc.exists) {
      final data = doc.data();
      if (data != null && data.containsKey('participants')) {
        return List<String>.from(data['participants']);
      }
    }
    return [];
  }

  // Send text message
  Future<void> sendTextMessage(String text) async {
    if (text.isEmpty) return;

    try {
      await _firestore
          .collection('conversations')
          .doc(chatId)
          .collection('messages')
          .add({
        'text': text,
        'senderId': userId,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': [],
      });

      // Update conversation metadata
      await ConversationManager.updateLastActivity(chatId);
      await ConversationManager.addParticipant(chatId, userId);
    } catch (e) {
      print("Error sending message: $e");
      throw e; // Allow caller to handle the error
    }
  }

  // Send image message
  Future<void> sendImageMessage(File imageFile) async {
    try {
      // Upload image
      final fileName = path.basename(imageFile.path);
      final storageRef = _storage
          .ref()
          .child('chat_images')
          .child(chatId)
          .child('${DateTime.now().millisecondsSinceEpoch}_$fileName');

      final uploadTask = storageRef.putFile(imageFile);
      await uploadTask.whenComplete(() => print('Image upload complete'));

      // Get download URL
      final imageUrl = await storageRef.getDownloadURL();

      // Add message to chat
      await _firestore
          .collection('conversations')
          .doc(chatId)
          .collection('messages')
          .add({
        'text': '📷 Photo', // Text placeholder for non-image compatible clients
        'imageUrl': imageUrl,
        'senderId': userId,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': [],
      });

      // Update conversation metadata
      await ConversationManager.updateLastActivity(chatId);
      await ConversationManager.addParticipant(chatId, userId);
    } catch (e) {
      print("Error sending image: $e");
      throw e;
    }
  }

  // Toggle like on message
  Future<void> toggleLike(String messageId, List<dynamic> currentLikes) async {
    try {
      // Check if user already liked this message
      final bool alreadyLiked = currentLikes.contains(userId);

      // Update the likes array
      if (alreadyLiked) {
        // Remove like
        await _firestore
            .collection('conversations')
            .doc(chatId)
            .collection('messages')
            .doc(messageId)
            .update({
          'likes': FieldValue.arrayRemove([userId])
        });
      } else {
        // Add like
        await _firestore
            .collection('conversations')
            .doc(chatId)
            .collection('messages')
            .doc(messageId)
            .update({
          'likes': FieldValue.arrayUnion([userId])
        });
      }
    } catch (e) {
      print("Error toggling like: $e");
      throw e;
    }
  }
}
