import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../domain/discovery.dart';

class DiscoveryService {
  DiscoveryService({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  Stream<List<Discovery>> watchPublished({int limit = 30}) => _db
          .collection('discoveries')
          .where('status', isEqualTo: 'published')
          .limit(limit)
          .snapshots()
          .map((s) {
        final items = s.docs.map(Discovery.fromFirestore).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
    final uid = _auth.currentUser!.uid;
    final ref = _db
        .collection('discoveries')
        .doc(discoveryId)
        .collection('interested')
        .doc(uid);
    if (interested) {
      await ref.set({'userId': uid, 'createdAt': FieldValue.serverTimestamp()});
    } else {
      await ref.delete();
    }
  }
}
