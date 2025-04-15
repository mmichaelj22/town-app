import 'package:cloud_firestore/cloud_firestore.dart';

class UserBlockingService {
  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection names
  static const String _usersCollection = 'users';
  static const String _blockedUsersCollection = 'blocked_users';
  static const String _conversationsCollection = 'conversations';

  // Block a user
  Future<void> blockUser({
    required String currentUserId,
    required String userToBlockId,
    String? userToBlockName,
  }) async {
    try {
      // Add to blocked_users subcollection
      await _firestore
          .collection(_usersCollection)
          .doc(currentUserId)
          .collection(_blockedUsersCollection)
          .doc(userToBlockId)
          .set({
        'blockedAt': FieldValue.serverTimestamp(),
        'name': userToBlockName ?? 'Unknown User',
      });

      // Hide private conversations between the two users
      await _hidePrivateConversations(currentUserId, userToBlockId);

      print('User $userToBlockId blocked successfully');
    } catch (e) {
      print('Error blocking user: $e');
      rethrow; // Allow calling code to handle the error
    }
  }

  // Hide private conversations between two users
  Future<void> _hidePrivateConversations(String userId1, String userId2) async {
    try {
      // Get all conversations where both users are participants
      final conversationsQuery = await _firestore
          .collection(_conversationsCollection)
          .where('participants', arrayContains: userId1)
          .get();

      for (var doc in conversationsQuery.docs) {
        final participants = List<String>.from(doc['participants'] ?? []);
        final type = doc['type'] as String? ?? '';

        // Check if this is a private chat between the two users
        if (type == 'Private' && participants.contains(userId2)) {
          // For private chats, remove both users from participants
          // This will make the conversation disappear from both users' views
          await _firestore
              .collection(_conversationsCollection)
              .doc(doc.id)
              .update({
            'participants': FieldValue.arrayRemove([userId1, userId2]),
          });
        }
      }
    } catch (e) {
      print('Error hiding private conversations: $e');
    }
  }

  // Unblock a user
  Future<void> unblockUser({
    required String currentUserId,
    required String blockedUserId,
  }) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(currentUserId)
          .collection(_blockedUsersCollection)
          .doc(blockedUserId)
          .delete();

      print('User $blockedUserId unblocked successfully');
    } catch (e) {
      print('Error unblocking user: $e');
      rethrow;
    }
  }

  // Check if a user is blocked
  Future<bool> isUserBlocked({
    required String currentUserId,
    required String otherUserId,
  }) async {
    try {
      final docSnapshot = await _firestore
          .collection(_usersCollection)
          .doc(currentUserId)
          .collection(_blockedUsersCollection)
          .doc(otherUserId)
          .get();

      return docSnapshot.exists;
    } catch (e) {
      print('Error checking if user is blocked: $e');
      return false; // Default to not blocked on error
    }
  }

  // Check if current user is blocked by another user
  Future<bool> isBlockedByUser({
    required String currentUserId,
    required String otherUserId,
  }) async {
    try {
      final docSnapshot = await _firestore
          .collection(_usersCollection)
          .doc(otherUserId)
          .collection(_blockedUsersCollection)
          .doc(currentUserId)
          .get();

      return docSnapshot.exists;
    } catch (e) {
      print('Error checking if user is blocked by other: $e');
      return false; // Default to not blocked on error
    }
  }

  // Get all blocked users
  Stream<QuerySnapshot> getBlockedUsers(String userId) {
    return _firestore
        .collection(_usersCollection)
        .doc(userId)
        .collection(_blockedUsersCollection)
        .snapshots();
  }

  // Batch check if multiple users are blocked
  Future<List<String>> filterBlockedUsers({
    required String currentUserId,
    required List<String> userIds,
  }) async {
    try {
      final List<String> nonBlockedUsers = [];

      // Use a batch get to efficiently check multiple documents
      final blockedUserDocs = await _firestore
          .collection(_usersCollection)
          .doc(currentUserId)
          .collection(_blockedUsersCollection)
          .where(FieldPath.documentId, whereIn: userIds)
          .get();

      // Create a set of blocked user IDs for efficient lookup
      final blockedUserIds = blockedUserDocs.docs.map((doc) => doc.id).toSet();

      // Return only the user IDs that aren't in the blocked set
      return userIds.where((id) => !blockedUserIds.contains(id)).toList();
    } catch (e) {
      print('Error filtering blocked users: $e');
      return userIds; // Return all users on error (safer than blocking everyone)
    }
  }

  // Check if users can see each other's locations
  Future<bool> canViewLocation({
    required String viewerId,
    required String targetUserId,
  }) async {
    // If either user has blocked the other, they can't view locations
    bool userIsBlocked = await isUserBlocked(
      currentUserId: viewerId,
      otherUserId: targetUserId,
    );

    bool userIsBlockedBy = await isBlockedByUser(
      currentUserId: viewerId,
      otherUserId: targetUserId,
    );

    return !userIsBlocked && !userIsBlockedBy;
  }

  // Report a user (block + send report)
  Future<void> reportUser({
    required String currentUserId,
    required String reportedUserId,
    required String reportReason,
    String? reportedUserName,
    String? conversationId,
  }) async {
    try {
      // First block the user
      await blockUser(
        currentUserId: currentUserId,
        userToBlockId: reportedUserId,
        userToBlockName: reportedUserName,
      );

      // Then create a report document
      await _firestore.collection('reports').add({
        'reporterId': currentUserId,
        'reportedUserId': reportedUserId,
        'reportedUserName': reportedUserName,
        'reason': reportReason,
        'conversationId': conversationId,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending', // For admin review
      });

      print('User $reportedUserId reported successfully');
    } catch (e) {
      print('Error reporting user: $e');
      rethrow;
    }
  }
}
