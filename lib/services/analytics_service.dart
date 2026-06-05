import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';

class AnalyticsService {
  static Future<void> log(String event, [Map<String, Object>? params]) async {
    try {
      if (Firebase.apps.isEmpty) return;
      await FirebaseAnalytics.instance.logEvent(name: event, parameters: params);
    } catch (_) {}
  }
}
