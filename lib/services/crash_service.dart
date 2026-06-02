import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CrashService {
  // Call after successful login to identify user in crash reports
  static Future<void> setUser() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      await FirebaseCrashlytics.instance.setUserIdentifier(user.id);
    }
  }

  // Call on logout
  static Future<void> clearUser() async {
    await FirebaseCrashlytics.instance.setUserIdentifier('');
  }

  // Wrap non-fatal errors (network failures, parse errors etc)
  static Future<void> log(dynamic error, StackTrace stack, {String? context}) async {
    await FirebaseCrashlytics.instance.recordError(
      error,
      stack,
      reason: context,
      fatal: false,
    );
  }
}
