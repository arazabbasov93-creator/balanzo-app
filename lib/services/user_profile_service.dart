import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_state.dart';
import 'auth_service.dart';

/// Keeps display name warm so Home greeting never flashes "User".
class UserProfileService {
  static final _db = Supabase.instance.client;

  static String? _nameFromAuth() {
    final user = AuthService.currentUser;
    if (user == null) return null;
    final meta = user.userMetadata?['full_name'] as String? ??
        user.userMetadata?['name'] as String?;
    if (meta != null && meta.trim().isNotEmpty) return meta.trim();
    if (user.email != null && user.email!.isNotEmpty) {
      return user.email!.split('@').first;
    }
    if (user.phone != null && user.phone!.isNotEmpty) return user.phone;
    return null;
  }

  static void warmCache() {
    final fromAuth = _nameFromAuth();
    if (fromAuth != null) cachedDisplayName.value = fromAuth;
  }

  static Future<String?> loadFullName({bool refreshCache = true}) async {
    warmCache();
    try {
      final userId = _db.auth.currentUser?.id;
      if (userId != null) {
        final row = await _db
            .from('users')
            .select('full_name')
            .eq('id', userId)
            .maybeSingle();
        final name = (row?['full_name'] as String?)?.trim();
        if (name != null && name.isNotEmpty) {
          if (refreshCache) cachedDisplayName.value = name;
          return name;
        }
      }
    } catch (_) {}
    final fallback = _nameFromAuth();
    if (fallback != null && refreshCache) cachedDisplayName.value = fallback;
    return fallback;
  }

  static String displayFirstName(String? fullName, String identityFallback) {
    final raw = (fullName?.trim().isNotEmpty == true)
        ? fullName!.trim()
        : identityFallback.trim();
    if (raw.isEmpty) return 'User';
    return raw.split(RegExp(r'\s+')).first;
  }
}
