import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../screens/chat_screen.dart';
import '../utils/conversation_manager.dart';

class ChatCreationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Start or navigate to an existing private chat
  static Future<void> startPrivateChat({
    required BuildContext context,
    required String currentUserId,
    required String recipientId,
    required String recipientName,
    String? initialEmoji,
  }) async {
    try {
      // Check if there's an existing chat with this user
      final existingChat =
          await _findExistingPrivateChat(currentUserId, recipientId);

      if (existingChat != null) {
        // Navigate to existing chat
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              userId: currentUserId,
              chatTitle: existingChat,
              chatType: 'Private',
            ),
          ),
        );

        // If there's an initial emoji, send it
        if (initialEmoji != null && initialEmoji.isNotEmpty) {
          await _sendMessage(existingChat, currentUserId, initialEmoji);
        }
      } else {
        // Create a new chat with emoji if provided
        final String chatTitle = initialEmoji != null && initialEmoji.isNotEmpty
            ? "$initialEmoji with $recipientName"
            : "Chat with $recipientName";

        // Get user location for creating the conversation
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(currentUserId).get();

        double latitude = 0.0;
        double longitude = 0.0;

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>?;
          if (userData != null) {
            latitude = userData['latitude'] as double? ?? 0.0;
            longitude = userData['longitude'] as double? ?? 0.0;
          }
        }

        // Create the conversation
        await ConversationManager.createConversation(
          title: chatTitle,
          type: 'Private',
          creatorId: currentUserId,
          initialParticipants: [recipientId],
          latitude: latitude,
          longitude: longitude,
        );

        // If there's an initial emoji, send it (even though it's in the title)
        if (initialEmoji != null && initialEmoji.isNotEmpty) {
          await _sendMessage(chatTitle, currentUserId, initialEmoji);
        }

        // Navigate to new chat
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              userId: currentUserId,
              chatTitle: chatTitle,
              chatType: 'Private',
            ),
          ),
        );
      }
    } catch (e) {
      print("Error starting private chat: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting chat: $e')),
      );
    }
  }

  // Start a private group chat
  static Future<void> startPrivateGroupChat({
    required BuildContext context,
    required String currentUserId,
    required List<String> members,
    required String groupName,
  }) async {
    try {
      // Create a new chat
      final chatTitle = groupName;

      // Include current user in members if not already
      if (!members.contains(currentUserId)) {
        members.add(currentUserId);
      }

      // Get user location for creating the conversation
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(currentUserId).get();

      double latitude = 0.0;
      double longitude = 0.0;

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>?;
        if (userData != null) {
          latitude = userData['latitude'] as double? ?? 0.0;
          longitude = userData['longitude'] as double? ?? 0.0;
        }
      }

      // Create the conversation
      await ConversationManager.createConversation(
        title: chatTitle,
        type: 'Private Group',
        creatorId: currentUserId,
        initialParticipants: members,
        latitude: latitude,
        longitude: longitude,
      );

      // Add system message about group creation
      await _sendMessage(chatTitle, 'system', 'Group created: $groupName');

      // Navigate to new chat
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            userId: currentUserId,
            chatTitle: chatTitle,
            chatType: 'Private Group',
          ),
        ),
      );
    } catch (e) {
      print("Error starting private group: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating group: $e')),
      );
    }
  }

  // Start a public group chat
  static Future<void> startPublicGroupChat({
    required BuildContext context,
    required String currentUserId,
    required String groupName,
  }) async {
    try {
      // Create a new chat
      final chatTitle = groupName;

      // Get user location for creating the conversation
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(currentUserId).get();

      double latitude = 0.0;
      double longitude = 0.0;

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>?;
        if (userData != null) {
          latitude = userData['latitude'] as double? ?? 0.0;
          longitude = userData['longitude'] as double? ?? 0.0;
        }
      }

      // Create the conversation
      await ConversationManager.createConversation(
        title: chatTitle,
        type: 'Group',
        creatorId: currentUserId,
        initialParticipants: [currentUserId],
        latitude: latitude,
        longitude: longitude,
      );

      // Add system message about group creation
      await _sendMessage(chatTitle, 'system', 'Group created: $groupName');

      // Navigate to new chat
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            userId: currentUserId,
            chatTitle: chatTitle,
            chatType: 'Group',
          ),
        ),
      );
    } catch (e) {
      print("Error starting public group: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating group: $e')),
      );
    }
  }

  // Helper to find existing private chat between two users
  static Future<String?> _findExistingPrivateChat(
      String userId1, String userId2) async {
    try {
      // Get all conversations where the current user is a participant
      final conversationsQuery = await _firestore
          .collection('conversations')
          .where('participants', arrayContains: userId1)
          .where('type', isEqualTo: 'Private')
          .get();

      // Find the conversation that includes the other user
      for (var doc in conversationsQuery.docs) {
        final participants = List<String>.from(doc['participants'] ?? []);
        if (participants.contains(userId2) && participants.length == 2) {
          return doc.id;
        }
      }

      // No existing chat found
      return null;
    } catch (e) {
      print("Error finding existing chat: $e");
      return null;
    }
  }

  // Helper to send a message to a conversation
  static Future<void> _sendMessage(
      String conversationId, String senderId, String message) async {
    try {
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .add({
        'text': message,
        'senderId': senderId,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': [],
      });

      // Update conversation's last activity timestamp
      await _firestore.collection('conversations').doc(conversationId).update({
        'lastActivity': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Error sending message: $e");
    }
  }
}
