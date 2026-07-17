import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/family.dart';
import '../models/family_period_summary.dart';
import 'budget_service.dart';
import 'receipt_service.dart';
import 'supabase_access.dart';

class FamilyService {
  static SupabaseClient get _db => SupabaseAccess.client;
  static String? get _userId => SupabaseAccess.currentUserId;

  /// Returns the family the current user belongs to, or null.
  static Future<Family?> fetchMyFamily() async {
    final uid = _userId;
    if (uid == null) return null;
    final memberRows = await _db
        .from('family_members')
        .select('family_id')
        .eq('user_id', uid)
        .limit(1);
    if ((memberRows as List).isEmpty) return null;
    final familyId = memberRows.first['family_id'] as String;
    final row = await _db.from('families').select().eq('id', familyId).single();
    return Family.fromJson(row);
  }

  /// Creates a new family and makes current user admin.
  static Future<Family> createFamily(String name) async {
    final uid = _userId;
    if (uid == null) throw Exception('Please sign in.');
    final row = await _db
        .from('families')
        .insert({'name': name, 'created_by': uid})
        .select()
        .single();
    final family = Family.fromJson(row);
    await _db.from('family_members').insert({
      'family_id': family.id,
      'user_id': uid,
      'role': 'admin',
    });
    return family;
  }

  static Future<List<FamilyMember>> fetchMembers(String familyId) async {
    final rows = await _db
        .from('family_members')
        .select(
          'id, family_id, user_id, role, relationship, spend_limit, '
          'pending_spend_limit, spend_limit_proposed_by, '
          'spend_limit_effective_month, spend_limit_effective_year, '
          'users(phone, email, full_name, avatar_url)',
        )
        .eq('family_id', familyId);
    return (rows as List)
        .map((r) => FamilyMember.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  static Future<void> updateMemberRelationship(
    String memberId,
    String? relationship,
  ) async {
    await _db
        .from('family_members')
        .update({'relationship': relationship})
        .eq('id', memberId);
  }

  /// Budget + spend snapshot for Profile and Home family tab (same source).
  static Future<FamilyPeriodSummary> fetchFamilyPeriodSummary({
    required String familyId,
    required String familyName,
    required int month,
    required int year,
  }) async {
    final spent = await fetchCombinedSpendForPeriod(month, year);
    final budget = await BudgetService.fetchFamilyAvailableBudget(
      familyId,
      month,
      year,
    );
    return FamilyPeriodSummary(
      familyId: familyId,
      familyName: familyName,
      month: month,
      year: year,
      availableBudget: budget ?? 0,
      hasBudget: budget != null,
      spent: spent,
    );
  }

  /// Sum of family-shared receipt totals for the given calendar month.
  static Future<double> fetchCombinedSpendForPeriod(int month, int year) async {
    final rows = await ReceiptService.fetchFamily();
    var total = 0.0;
    for (final row in rows) {
      final pd = row['purchase_date'] as String?;
      if (pd == null) continue;
      final d = DateTime.tryParse(pd);
      if (d == null) continue;
      if (d.month == month && d.year == year) {
        total += (row['total_amount'] as num?)?.toDouble() ?? 0;
      }
    }
    return total;
  }

  /// Spend limit changes: increases/top-ups apply immediately; initial set and
  /// reductions require the affected member to confirm (pending_spend_limit).
  static Future<void> proposeSpendLimit(String memberId, double amount) async {
    final uid = _userId;
    if (uid == null) throw Exception('Please sign in.');
    final row = await _db
        .from('family_members')
        .select('spend_limit, user_id')
        .eq('id', memberId)
        .single();
    final current = (row['spend_limit'] as num?)?.toDouble();
    final targetUserId = row['user_id'] as String;

    // Member editing their own confirmed limit applies immediately.
    if (uid == targetUserId) {
      final now = DateTime.now();
      await _db.from('family_members').update({
        'spend_limit': amount,
        'pending_spend_limit': null,
        'spend_limit_proposed_by': null,
        'spend_limit_effective_month': now.month,
        'spend_limit_effective_year': now.year,
      }).eq('id', memberId);
      return;
    }

    // Admin/co-admin: increases apply immediately; reductions need confirmation.
    if (current != null && amount > current) {
      final now = DateTime.now();
      await _db.from('family_members').update({
        'spend_limit': amount,
        'pending_spend_limit': null,
        'spend_limit_proposed_by': null,
        'spend_limit_effective_month': now.month,
        'spend_limit_effective_year': now.year,
      }).eq('id', memberId);
      return;
    }

    await _db.from('family_members').update({
      'pending_spend_limit': amount,
      'spend_limit_proposed_by': uid,
    }).eq('id', memberId);
  }

  /// Member accepts a pending limit proposed by an admin.
  static Future<void> confirmSpendLimit(String memberId) async {
    final uid = _userId;
    if (uid == null) throw Exception('Please sign in.');
    final row = await _db
        .from('family_members')
        .select('pending_spend_limit')
        .eq('id', memberId)
        .eq('user_id', uid)
        .single();
    final pending = (row['pending_spend_limit'] as num?)?.toDouble();
    if (pending == null) return;
    final now = DateTime.now();
    await _db.from('family_members').update({
      'spend_limit': pending,
      'pending_spend_limit': null,
      'spend_limit_proposed_by': null,
      'spend_limit_effective_month': now.month,
      'spend_limit_effective_year': now.year,
    }).eq('id', memberId);
  }

  /// Immediate increase without member confirmation.
  static Future<void> applySpendLimitTopUp(String memberId, double amount) async {
    final row = await _db
        .from('family_members')
        .select('spend_limit')
        .eq('id', memberId)
        .single();
    final current = (row['spend_limit'] as num?)?.toDouble() ?? 0;
    await _db.from('family_members').update({
      'spend_limit': current + amount,
    }).eq('id', memberId);
  }

  /// Adds a member by phone number.
  static Future<void> addMemberByPhone(String familyId, String phone) async {
    final userRows = await _db
        .from('users')
        .select('id')
        .eq('phone', phone)
        .limit(1);
    if ((userRows as List).isEmpty) throw Exception('User with this phone not found');
    final memberId = userRows.first['id'] as String;
    await _db.from('family_members').upsert({
      'family_id': familyId,
      'user_id': memberId,
      'role': 'member',
    }, onConflict: 'family_id,user_id');
  }

  static Future<void> removeMember(String memberId) async {
    await _db.from('family_members').delete().eq('id', memberId);
  }

  static Future<void> leaveFamily(String familyId) async {
    final uid = _userId;
    if (uid == null) return;
    await _db
        .from('family_members')
        .delete()
        .eq('family_id', familyId)
        .eq('user_id', uid);
  }

  static Future<void> updateFamilyName(String familyId, String name) async {
    await _db.from('families').update({'name': name}).eq('id', familyId);
  }

  /// Creates a shareable invite row; returns the new invite UUID.
  static Future<String> createInvite(String familyId) async {
    final uid = _userId;
    if (uid == null) throw Exception('Please sign in.');
    final row = await _db
        .from('family_invites')
        .insert({
          'family_id': familyId,
          'invited_by': uid,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  /// Accepts an invite via SECURITY DEFINER RPC; returns joined family id.
  static Future<String> acceptInvite(String inviteId) async {
    if (_userId == null) throw Exception('Please sign in.');
    try {
      final result = await _db.rpc(
        'accept_family_invite',
        params: {'invite_id': inviteId},
      );
      return result as String;
    } on PostgrestException catch (e) {
      final msg = e.message;
      if (msg.contains('Invalid invite')) {
        throw const FamilyInviteException(FamilyInviteFailure.invalid);
      }
      if (msg.contains('Invite expired')) {
        throw const FamilyInviteException(FamilyInviteFailure.expired);
      }
      throw FamilyInviteException(FamilyInviteFailure.other, msg);
    }
  }

  static Future<Family?> fetchFamilyById(String familyId) async {
    try {
      final row = await _db.from('families').select().eq('id', familyId).single();
      return Family.fromJson(row);
    } catch (_) {
      return null;
    }
  }
}

/// Thrown when [FamilyService.acceptInvite] fails with a known server message.
class FamilyInviteException implements Exception {
  final FamilyInviteFailure reason;
  final String? rawMessage;

  const FamilyInviteException(this.reason, [this.rawMessage]);

  @override
  String toString() => rawMessage ?? reason.name;
}

enum FamilyInviteFailure { invalid, expired, other }
