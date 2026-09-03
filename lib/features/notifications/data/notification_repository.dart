import '../../../shared/models/notification_model.dart';

abstract class NotificationRepository {
  Stream<List<NotificationModel>> watchNotifications(String uid);
  Future<void> markAllRead(String uid);
}
