import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// JWT clock skew — device time ahead of server; safe to ignore during auth.
bool isIgnorablePostgrestAuthError(Object error) {
  if (error is PostgrestException) {
    return error.code == 'PGRST303';
  }
  return false;
}

void logIgnorablePostgrestAuthError(Object error) {
  debugPrint('[Auth] Ignored PGRST303 (JWT clock skew): $error');
}
