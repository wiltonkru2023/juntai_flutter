class NotificationModel {
  final String id;
  final String type;
  final String title;
  final String body;
  final String? activityId;
  final String? actorId;
  final bool read;
  final DateTime createdAt;

  const NotificationModel({required this.id, required this.type, required this.title, required this.body, this.activityId, this.actorId, required this.read, required this.createdAt});
  NotificationModel copyWith({bool? read}) => NotificationModel(id: id, type: type, title: title, body: body, activityId: activityId, actorId: actorId, read: read ?? this.read, createdAt: createdAt);
}
