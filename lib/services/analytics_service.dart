import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final _fa = FirebaseAnalytics.instance;

  static Future<void> log(String event, [Map<String, Object>? params]) =>
      _fa.logEvent(name: event, parameters: params);
}
