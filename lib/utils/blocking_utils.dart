import 'package:cloud_firestore/cloud_firestore.dart';

class BlockingUtils {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Filter out conversations that contain blocked users
  static Future<List<DocumentSnapshot>> filterConversationsWithBlockedUsers({
    required String currentUserId,
    required List<DocumentSnapshot> conversations,
  }) async {
    try {
      // Get all blocked users for the current user
      final blockedUsersSnapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('blocked_users')
          .get();

      // If there are no blocked users, return all conversations
      if (blockedUsersSnapshot.docs.isEmpty) {
        return conversations;
      }

      // Create a set of blocked user IDs for efficient lookup
      final Set<String> blockedUserIds =
          blockedUsersSnapshot.docs.map((doc) => doc.id).toSet();

      // Filter conversations to exclude those with blocked users
      final filteredConversations = conversations.where((conversation) {
        final data = conversation.data() as Map<String, dynamic>?;
        if (data == null) return false;

        // Get participants from the conversation
        final List<dynamic> participants = data['participants'] ?? [];

        // Check if any participant is blocked
        for (final participant in participants) {
          if (blockedUserIds.contains(participant)) {
            return false; // Filter out this conversation
          }
        }

        return true; // Keep this conversation
      }).toList();

      return filteredConversations;
    } catch (e) {
      print('Error filtering conversations with blocked users: $e');
      return conversations; // Return original list on error
    }
  }

  // Check if a conversation contains blocked users
  static Future<bool> conversationContainsBlockedUsers({
    required String currentUserId,
    required DocumentSnapshot conversation,
  }) async {
    try {
      final data = conversation.data() as Map<String, dynamic>?;
      if (data == null) return false;

      // Get participants from the conversation
      final List<dynamic> participants = data['participants'] ?? [];

      // If it's just the current user, no blocked users
      if (participants.length <= 1) {
        return false;
      }

      // Get the IDs of other participants (excluding current user)
      final otherParticipantIds =
          participants.where((id) => id != currentUserId).toList();

      if (otherParticipantIds.isEmpty) {
        return false;
      }

      // Check if any other participant is blocked
      final blockedUserDocs = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('blocked_users')
          .where(FieldPath.documentId, whereIn: otherParticipantIds)
          .get();

      return blockedUserDocs.docs.isNotEmpty;
    } catch (e) {
      print('Error checking if conversation contains blocked users: $e');
      return false; // Default to not blocked on error
    }
  }

  // Filter nearby users to exclude blocked users
  static Future<List<Map<String, dynamic>>> filterNearbyUsers({
    required String currentUserId,
    required List<Map<String, dynamic>> nearbyUsers,
  }) async {
    try {
      // Get all blocked users for the current user
      final blockedUsersSnapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('blocked_users')
          .get();

      // If there are no blocked users, return all nearby users
      if (blockedUsersSnapshot.docs.isEmpty) {
        return nearbyUsers;
      }

      // Create a set of blocked user IDs for efficient lookup
      final Set<String> blockedUserIds =
          blockedUsersSnapshot.docs.map((doc) => doc.id).toSet();

      // Filter nearby users to exclude blocked users
      return nearbyUsers
          .where((user) => !blockedUserIds.contains(user['id']))
          .toList();
    } catch (e) {
      print('Error filtering nearby users: $e');
      return nearbyUsers; // Return original list on error
    }
  }
}
