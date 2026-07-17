import 'package:flutter/foundation.dart';
import 'supabase_access.dart';

/// Allocates per-user monotonic receipt sequence numbers.
class ReceiptSequenceService {
  static Future<int?> allocateForUser(String userId) async {
    try {
      final db = SupabaseAccess.client;
      final existing = await db
          .from('receipt_sequence_counters')
          .select('last_value')
          .eq('user_id', userId)
          .maybeSingle();
      final next = ((existing?['last_value'] as num?)?.toInt() ?? 0) + 1;
      await db.from('receipt_sequence_counters').upsert({
        'user_id': userId,
        'last_value': next,
      });
      return next;
    } catch (e, st) {
      debugPrint('[ReceiptSequence] allocate failed: $e\n$st');
      return null;
    }
  }
}
