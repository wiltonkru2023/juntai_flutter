import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/discovery.dart';

class DiscoveryService {
  DiscoveryService({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  Stream<List<Discovery>> watchPublished({
    int limit = 60,
    double? latitude,
    double? longitude,
  }) =>
      _db
          .collection('discoveries')
          .where('status', isEqualTo: 'published')
          .limit(limit)
          .snapshots()
          .map((snapshot) {
        final items = snapshot.docs.map(Discovery.fromFirestore).map((item) {
          if (latitude == null ||
              longitude == null ||
              (item.latitude == 0 && item.longitude == 0)) {
            return item;
          }

          final meters = Geolocator.distanceBetween(
            latitude,
            longitude,
            item.latitude,
            item.longitude,
          );
          return item.copyWith(distanceKm: meters / 1000);
        }).toList();

        items.sort((a, b) {
          final aDistance = a.distanceKm;
          final bDistance = b.distanceKm;

          if (aDistance != null && bDistance != null) {
            final byDistance = aDistance.compareTo(bDistance);
            if (byDistance != 0) return byDistance;
          } else if (aDistance != null) {
            return -1;
          } else if (bDistance != null) {
            return 1;
          }

          if (a.sponsored != b.sponsored) return a.sponsored ? -1 : 1;
          return b.createdAt.compareTo(a.createdAt);
        });

        return items;
      });

  Stream<bool> watchInterested(String discoveryId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(false);

    return _db
        .collection('discoveries')
        .doc(discoveryId)
        .collection('interested')
        .doc(uid)
        .snapshots()
        .map((d) => d.exists);
  }

  Future<void> setInterested(String discoveryId, bool interested) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final ref = _db
        .collection('discoveries')
        .doc(discoveryId)
        .collection('interested')
        .doc(uid);

    if (interested) {
      await ref.set({
        'userId': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.delete();
    }
  }
}
