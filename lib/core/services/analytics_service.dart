import 'package:firebase_analytics/firebase_analytics.dart';
class AnalyticsService {
  AnalyticsService(this.analytics); final FirebaseAnalytics analytics;
  Future<void> event(String name, [Map<String,Object>? parameters]) => analytics.logEvent(name: name, parameters: parameters);
}
