import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_state.dart';

/// Safe Supabase access — never touches [Supabase.instance] before bootstrap.
class SupabaseAccess {
  static SupabaseClient? get clientOrNull =>
      supabaseReady ? Supabase.instance.client : null;

  static SupabaseClient get client {
    if (!supabaseReady) {
      throw StateError('Supabase is not initialized');
    }
    return Supabase.instance.client;
  }

  static String? get currentUserId => clientOrNull?.auth.currentUser?.id;
}
