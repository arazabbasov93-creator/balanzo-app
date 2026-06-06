import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'supabase_access.dart';

class CrashService {
  static bool get _ready => Firebase.apps.isNotEmpty;

  static Future<void> setUser() async {
    if (!_ready) return;
    try {
      final user = SupabaseAccess.clientOrNull?.auth.currentUser;
      if (user != null) {
        await FirebaseCrashlytics.instance.setUserIdentifier(user.id);
      }
    } catch (_) {}
  }

  static Future<void> clearUser() async {
    if (!_ready) return;
    try {
      await FirebaseCrashlytics.instance.setUserIdentifier('');
    } catch (_) {}
  }

  static Future<void> log(dynamic error, StackTrace stack, {String? context}) async {
    if (!_ready) return;
    try {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: context,
        fatal: false,
      );
    } catch (_) {}
  }
}
