import 'package:flutter/foundation.dart';
import 'supabase_access.dart';

class SupportService {
  static Future<void> submitReceiptReport({
    required String description,
    String? receiptId,
    int? sequenceNumber,
  }) async {
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) throw Exception('Please sign in to submit a report.');

    final payload = <String, dynamic>{
      'user_id': uid,
      'description': description.trim(),
      'status': 'open',
    };
    if (receiptId != null) payload['receipt_id'] = receiptId;
    if (sequenceNumber != null) payload['sequence_number'] = sequenceNumber;

    try {
      await SupabaseAccess.client.from('receipt_reports').insert(payload);
    } catch (e, st) {
      debugPrint('[SupportService] submit failed: $e\n$st');
      rethrow;
    }
  }

  /// Existing report for this user + receipt sequence number, if any.
  static Future<Map<String, dynamic>?> fetchExistingReport({
    int? sequenceNumber,
    String? receiptId,
  }) async {
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) return null;
    try {
      if (sequenceNumber != null) {
        final rows = await SupabaseAccess.client
            .from('receipt_reports')
            .select('id, description, status, created_at, sequence_number, receipt_id')
            .eq('user_id', uid)
            .eq('sequence_number', sequenceNumber)
            .order('created_at', ascending: false)
            .limit(1);
        final list = rows as List;
        if (list.isNotEmpty) {
          return Map<String, dynamic>.from(list.first as Map);
        }
      }
      if (receiptId != null) {
        final rows = await SupabaseAccess.client
            .from('receipt_reports')
            .select('id, description, status, created_at, sequence_number, receipt_id')
            .eq('user_id', uid)
            .eq('receipt_id', receiptId)
            .order('created_at', ascending: false)
            .limit(1);
        final list = rows as List;
        if (list.isNotEmpty) {
          return Map<String, dynamic>.from(list.first as Map);
        }
      }
    } catch (e, st) {
      debugPrint('[SupportService] fetchExistingReport failed: $e\n$st');
    }
    return null;
  }

  /// Current user's support reports, newest first.
  static Future<List<Map<String, dynamic>>> fetchMyReports() async {
    final uid = SupabaseAccess.currentUserId;
    if (uid == null) return [];
    final rows = await SupabaseAccess.client
        .from('receipt_reports')
        .select('id, description, status, created_at, sequence_number, receipt_id')
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }
}
