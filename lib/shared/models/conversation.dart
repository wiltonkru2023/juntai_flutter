class Conversation {
  final String activityId;
  final String title;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;
  const Conversation({required this.activityId, required this.title, required this.lastMessage, required this.lastMessageAt, required this.unreadCount});
}
