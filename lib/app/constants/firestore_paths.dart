abstract final class FirestorePaths {
  static String user(String id) => 'users/$id';
  static String activity(String id) => 'activities/$id';
  static String participants(String id) => 'activities/$id/participants';
  static String chat(String id) => 'activities/$id/chat';
  static String notifications(String uid) => 'users/$uid/notifications';
}
