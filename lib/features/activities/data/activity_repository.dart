import '../../../shared/models/activity.dart';
import '../../../shared/models/user_profile.dart';
abstract class ActivityRepository {
  Future<String> createActivity(Activity activity);
  Future<void> updateActivity(Activity activity);
  Future<void> cancelActivity(String activityId);
  Future<void> joinActivity(String activityId);
  Future<void> leaveActivity(String activityId);
  Stream<Activity?> watchActivity(String activityId);
  Stream<List<Activity>> watchNearbyActivities({String? category, DateTime? startsAfter, int limit = 30});
  Future<List<Activity>> searchActivities(String query);
  Stream<List<UserProfile>> watchParticipants(String activityId);
}
