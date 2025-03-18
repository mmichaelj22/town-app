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
      snapshot.docs.forEach((doc) {
        if (doc.id != userId &&
            doc['latitude'] != null &&
            doc['longitude'] != null) {
          double lat = doc['latitude'] as double;
          double lon = doc['longitude'] as double;
          double userLat =
              snapshot.docs.firstWhere((d) => d.id == userId)['latitude'];
          double userLon =
              snapshot.docs.firstWhere((d) => d.id == userId)['longitude'];
          double distance =
              Geolocator.distanceBetween(userLat, userLon, lat, lon) * 3.28084;
          if (distance <= radius) {
            nearby.add(doc['name']);
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
                  List<String> friends =
                      snapshot.data!.exists && snapshot.data!['friends'] != null
                          ? List<String>.from(snapshot.data!['friends'])
                          : []; // Default to empty list if 'friends' missing
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
