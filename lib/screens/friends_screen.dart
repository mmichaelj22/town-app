import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'new_private_chat_dialog.dart';

class FriendsScreen extends StatelessWidget {
  final String userId;
  final double detectionRadius;
  final Function(String) onSelectFriend;

  const FriendsScreen({
    super.key,
    required this.userId,
    required this.detectionRadius,
    required this.onSelectFriend,
  });

  Stream<List<String>> _getNearbyUsers(double radius) {
    return FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .map((snapshot) {
      List<String> nearby = [];

      // Find the current user document
      DocumentSnapshot? currentUserDoc;
      try {
        currentUserDoc = snapshot.docs.firstWhere((d) => d.id == userId);
      } catch (e) {
        print("Current user not found in Firestore: $e");
        return nearby; // Return empty list if user not found
      }

      // Check if the current user has latitude and longitude
      if (!currentUserDoc.exists ||
          !currentUserDoc.data().toString().contains('latitude') ||
          !currentUserDoc.data().toString().contains('longitude')) {
        print("Current user missing location data");
        return nearby;
      }

      double userLat = currentUserDoc['latitude'] as double;
      double userLon = currentUserDoc['longitude'] as double;

      snapshot.docs.forEach((doc) {
        if (doc.id != userId &&
            doc.exists &&
            doc.data().toString().contains('latitude') &&
            doc.data().toString().contains('longitude') &&
            doc.data().toString().contains('name')) {
          try {
            double lat = doc['latitude'] as double;
            double lon = doc['longitude'] as double;
            String name = doc['name'] as String;

            double distance =
                Geolocator.distanceBetween(userLat, userLon, lat, lon) *
                    3.28084;
            if (distance <= radius) {
              nearby.add(name);
            }
          } catch (e) {
            print("Error processing user ${doc.id}: $e");
          }
        }
      });
      return nearby;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Friends')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nearby',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Expanded(
              child: StreamBuilder<List<String>>(
                stream: _getNearbyUsers(detectionRadius),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.data!.isEmpty) {
                    return const Center(child: Text('No nearby users'));
                  }
                  return ListView.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      String name = snapshot.data![index];
                      return ListTile(
                        title: Text(name),
                        onTap: () => onSelectFriend(name),
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(),
            const Text('Friends',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // Safely get the friends list
                  List<String> friends = [];
                  try {
                    if (snapshot.data!.exists) {
                      // Check if 'friends' field exists and is not null
                      final data =
                          snapshot.data!.data() as Map<String, dynamic>?;
                      if (data != null &&
                          data.containsKey('friends') &&
                          data['friends'] != null) {
                        friends = List<String>.from(data['friends']);
                      }
                    }
                  } catch (e) {
                    print("Error getting friends: $e");
                  }

                  if (friends.isEmpty) {
                    return const Center(child: Text('No friends yet'));
                  }

                  return ListView.builder(
                    itemCount: friends.length,
                    itemBuilder: (context, index) {
                      String name = friends[index];
                      return ListTile(
                        title: Text(name),
                        onTap: () => onSelectFriend(name),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
