import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/models/notification_model.dart';
import 'notification_repository.dart';

class FirebaseNotificationRepository
    implements NotificationRepository {
  FirebaseNotificationRepository(this.db);

  final FirebaseFirestore db;

  @override
  Stream<List<NotificationModel>> watchNotifications(
    String uid,
  ) {
    return db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy(
          'createdAt',
          descending: true,
        )
        .limit(60)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(
            (document) {
              final data = document.data();

              return NotificationModel(
                id: document.id,
                type:
                    (data['type'] ?? 'generic')
                        .toString(),
                title:
                    (data['title'] ?? '')
                        .toString(),
                body:
                    (data['body'] ?? '')
                        .toString(),
                activityId:
                    data['activityId']
                        ?.toString(),
                actorId:
                    data['actorId']
                        ?.toString(),
                read:
                    data['read'] == true,
                createdAt:
                    (data['createdAt']
                                as Timestamp?)
                            ?.toDate() ??
                        DateTime.now(),
              );
            },
          ).toList(),
        );
  }

  @override
  Future<void> markAllRead(
    String uid,
  ) async {
    final snapshot = await db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where(
          'read',
          isEqualTo: false,
        )
        .get();

    final batch = db.batch();

    for (final document in snapshot.docs) {
      batch.update(
        document.reference,
        {
          'read': true,
        },
      );
    }

    await batch.commit();
  }
}