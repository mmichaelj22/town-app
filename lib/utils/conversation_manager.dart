import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class ConversationManager {
  // Configuration parameters
  // Easy to modify time limits here
  static const int conversationExpiryMinutes =
      15; // Time until conversation disappears if no response
  static const int locationExpiryMinutes =
      15; // Time until conversation disappears after leaving area

  // Check if a conversation should be visible on the home screen
  static Future<bool> shouldShowOnHomeScreen({
    required String userId,
    required DocumentSnapshot conversation,
    required double detectionRadius,
    required double userLat,
    required double userLon,
  }) async {
    final data = conversation.data() as Map<String, dynamic>?;
    if (data == null) return false;

    // Get conversation details
    final String type = data['type'] ?? 'Group';
    final List<dynamic> participants = data['participants'] ?? [];
    final GeoPoint? origin = data['origin'] as GeoPoint?;
    final Timestamp? lastActivity = data['lastActivity'] as Timestamp?;
    final Timestamp? createdAt = data['createdAt'] as Timestamp?;

    // Rule 1: Private messages are only visible to participants
    if (type == 'Private' || type == 'Private Group') {
      return participants.contains(userId);
    }

    // Rule 2: Check if conversation has expired due to inactivity
    if (lastActivity != null) {
      final lastActiveTime = lastActivity.toDate();
      final timeSinceActivity = DateTime.now().difference(lastActiveTime);

      // If no response within expiry time, don't show
      if (timeSinceActivity.inMinutes > conversationExpiryMinutes &&
          participants.length <= 1) {
        return false;
      }
    } else if (createdAt != null) {
      // If no activity recorded, use creation time
      final creationTime = createdAt.toDate();
      final timeSinceCreation = DateTime.now().difference(creationTime);

      // If no response within expiry time, don't show
      if (timeSinceCreation.inMinutes > conversationExpiryMinutes &&
          participants.length <= 1) {
        return false;
      }
    }

    // Rule 3: Check if user has left the area
    if (origin != null) {
      // Calculate distance from conversation origin
      final double distance = Geolocator.distanceBetween(
              userLat, userLon, origin.latitude, origin.longitude) *
          3.28084; // Convert to feet

      // Check if user is outside detection radius
      if (distance > detectionRadius) {
        // If outside radius, check when user last was in the area
        final Timestamp? userLastInArea =
            data['userLastInArea_$userId'] as Timestamp?;

        if (userLastInArea != null) {
          final lastInAreaTime = userLastInArea.toDate();
          final timeSinceInArea = DateTime.now().difference(lastInAreaTime);

          // If user left area more than expiry time ago, don't show
          if (timeSinceInArea.inMinutes > locationExpiryMinutes) {
            return false;
          }
        } else {
          // If no record of user being in area, don't show
          return false;
        }
      } else {
        // User is in area, update the timestamp
        await _updateUserLastInArea(conversation.id, userId);
      }
    }

    // Default: Show the conversation
    return true;
  }

  // Check if a conversation should be visible on the messages screen
  static bool shouldShowOnMessagesScreen({
    required String userId,
    required DocumentSnapshot conversation,
  }) {
    final data = conversation.data() as Map<String, dynamic>?;
    if (data == null) return false;

    // Rule 4: Only show conversations the user has participated in
    final List<dynamic> participants = data['participants'] ?? [];
    return participants.contains(userId);
  }

  // Helper method to update when user was last in the conversation area
  static Future<void> _updateUserLastInArea(
      String conversationId, String userId) async {
    await FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .update({
      'userLastInArea_$userId': FieldValue.serverTimestamp(),
    });
  }

  // Method to update conversation's last activity timestamp
  static Future<void> updateLastActivity(String conversationId) async {
    await FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .update({
      'lastActivity': FieldValue.serverTimestamp(),
    });
  }

  // Method to add user to conversation participants
  static Future<void> addParticipant(
      String conversationId, String userId) async {
    await FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .update({
      'participants': FieldValue.arrayUnion([userId]),
    });
  }

  // Method to create a new conversation with proper fields
  static Future<void> createConversation({
    required String title,
    required String type,
    required String creatorId,
    required List<String> initialParticipants,
    required double latitude,
    required double longitude,
  }) async {
    // Combine creator with initial participants
    final List<String> allParticipants = [creatorId, ...initialParticipants];

    // Remove any duplicates
    final List<String> uniqueParticipants = allParticipants.toSet().toList();

    await FirebaseFirestore.instance
        .collection('conversations')
        .doc(title)
        .set({
      'title': title,
      'type': type,
      'creatorId': creatorId,
      'participants': uniqueParticipants,
      'createdAt': FieldValue.serverTimestamp(),
      'lastActivity': FieldValue.serverTimestamp(),
      'origin': GeoPoint(latitude, longitude),
    });
  }
}
