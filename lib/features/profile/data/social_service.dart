import 'package:cloud_firestore/cloud_firestore.dart';

class SocialService {
  SocialService(this.db);
  final FirebaseFirestore db;

  Stream<bool> watchFollowing(String me, String other) => db
      .collection('users')
      .doc(me)
      .collection('following')
      .doc(other)
      .snapshots()
      .map((doc) => doc.exists);

  Future<void> setFollowing(String me, String other, bool follow) async {
    final following =
        db.collection('users').doc(me).collection('following').doc(other);
    final follower =
        db.collection('users').doc(other).collection('followers').doc(me);
    final batch = db.batch();
    if (follow) {
      final value = {'createdAt': FieldValue.serverTimestamp()};
      batch.set(following, {...value, 'userId': other});
      batch.set(follower, {...value, 'userId': me});
    } else {
      batch.delete(following);
      batch.delete(follower);
    }
    await batch.commit();
  }

  static String privateConversationId(String a, String b) {
    final ids = [a, b]..sort();
    return '${ids[0]}_${ids[1]}';
  }
}
