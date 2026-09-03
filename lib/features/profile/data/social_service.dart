import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/api_service.dart';

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
    if (me == other) return;
    await ApiService.instance.followUser(other, follow: follow);
  }

  static String privateConversationId(String a, String b) {
    final ids = [a, b]..sort();
    return '${ids[0]}_${ids[1]}';
  }
}
