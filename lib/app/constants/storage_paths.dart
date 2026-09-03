abstract final class StoragePaths {
  static String avatar(String uid) => 'users/$uid/avatar.jpg';
  static String activityCover(String id) => 'activities/$id/cover.jpg';
  static String chatImage(String activityId, String messageId) =>
      'chat/$activityId/$messageId.jpg';
}
