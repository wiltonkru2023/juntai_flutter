import '../../../shared/models/activity.dart';

abstract class SearchRepository {
  Future<List<Activity>> searchActivities(String query);
}
