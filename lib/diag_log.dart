import 'package:flutter/foundation.dart';

/// Startup diagnosis only — remove after root cause is confirmed.
void diag(String stage, [Object? detail]) {
  final ts = DateTime.now().toIso8601String();
  debugPrint('[DIAG $ts] $stage${detail != null ? ' | $detail' : ''}');
}
