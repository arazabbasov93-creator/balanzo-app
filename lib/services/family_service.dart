import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/family.dart';

class FamilyService {
  static final _db = Supabase.instance.client;
  static String get _userId => _db.auth.currentUser!.id;

  /// Returns the family the current user belongs to, or null.
  static Future<Family?> fetchMyFamily() async {
    final memberRows = await _db
        .from('family_members')
        .select('family_id')
        .eq('user_id', _userId)
        .limit(1);
    if ((memberRows as List).isEmpty) return null;
    final familyId = memberRows.first['family_id'] as String;
    final row = await _db.from('families').select().eq('id', familyId).single();
    return Family.fromJson(row);
  }

  /// Creates a new family and makes current user admin.
  static Future<Family> createFamily(String name) async {
    final row = await _db
        .from('families')
        .insert({'name': name, 'created_by': _userId})
        .select()
        .single();
    final family = Family.fromJson(row);
    await _db.from('family_members').insert({
      'family_id': family.id,
      'user_id': _userId,
      'role': 'admin',
    });
    return family;
  }

  static Future<List<FamilyMember>> fetchMembers(String familyId) async {
    final rows = await _db
        .from('family_members')
        .select('*, users(phone, email, full_name, avatar_url)')
        .eq('family_id', familyId);
    return (rows as List)
        .map((r) => FamilyMember.fromJson(r as Map<String, dynamic>))
        .toList();
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
    await _db
        .from('family_members')
        .delete()
        .eq('family_id', familyId)
        .eq('user_id', _userId);
  }

  static Future<void> updateFamilyName(String familyId, String name) async {
    await _db.from('families').update({'name': name}).eq('id', familyId);
  }
}
