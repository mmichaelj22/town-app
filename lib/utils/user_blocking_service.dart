import 'package:cloud_firestore/cloud_firestore.dart';

class UserBlockingService {
  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection names
  static const String _usersCollection = 'users';
  static const String _blockedUsersCollection = 'blocked_users';

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

      print('User $userToBlockId blocked successfully');
    } catch (e) {
      print('Error blocking user: $e');
      rethrow; // Allow calling code to handle the error
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
