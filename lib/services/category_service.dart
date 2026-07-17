import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/category.dart';
import 'supabase_access.dart';
import '../utils/postgrest_errors.dart';

class CategoryService {
  static SupabaseClient get _db => SupabaseAccess.client;
  static String? get _userId => SupabaseAccess.currentUserId;

  static List<Category> _cache = [];

  static List<Category> get cached => List.unmodifiable(_cache);

  static void clearCache() => _cache = [];

  static Future<List<Category>> refreshCache() async {
    try {
      _cache = await _fetchFromDb();
      if (_cache.isEmpty && _userId != null) {
        _cache = await _fetchGlobals();
      }
    } catch (e, st) {
      if (isIgnorablePostgrestAuthError(e)) {
        logIgnorablePostgrestAuthError(e);
      } else {
        debugPrint('[CategoryService] refreshCache failed: $e\n$st');
      }
      _cache = [];
    }
    return cached;
  }

  static Future<List<Category>> fetchAll() async {
    if (_cache.isNotEmpty) return cached;
    return refreshCache();
  }

  /// Fresh fetch for settings UI (always reloads cache).
  static Future<List<Category>> fetchForSettings() => refreshCache();

  static Future<List<Category>> _fetchFromDb() async {
    final userId = _userId;
    if (userId == null) {
      return _fetchGlobals();
    }
    final rows = await _db
        .from('categories')
        .select()
        .or('user_id.eq.$userId,user_id.is.null')
        .order('name');
    return (rows as List)
        .map((r) => Category.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  static Future<List<Category>> _fetchGlobals() async {
    final rows = await _db
        .from('categories')
        .select()
        .isFilter('user_id', null)
        .order('name');
    return (rows as List)
        .map((r) => Category.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  static Future<Category?> findGlobalByName(String name) async {
    try {
      final row = await _db
          .from('categories')
          .select()
          .isFilter('user_id', null)
          .ilike('name', name)
          .maybeSingle();
      if (row == null) return null;
      return Category.fromJson(row);
    } catch (e, st) {
      debugPrint('[CategoryService] findGlobalByName failed: $e\n$st');
      return null;
    }
  }

  static Future<Category?> create(
    String name,
    String icon,
    int color, {
    bool isDefault = false,
  }) async {
    final userId = _userId;
    if (userId == null) return null;
    try {
      final row = await _db
          .from('categories')
          .insert({
            'user_id': userId,
            'name': name,
            'icon': icon,
            'color': color,
            'is_default': isDefault,
          })
          .select()
          .single();
      final cat = Category.fromJson(row);
      _cache = [..._cache, cat]..sort((a, b) => a.name.compareTo(b.name));
      return cat;
    } catch (e, st) {
      debugPrint('[CategoryService] create failed: $e\n$st');
      return null;
    }
  }

  static Future<void> delete(String id) async {
    try {
      await _db.from('categories').delete().eq('id', id);
      _cache = _cache.where((c) => c.id != id).toList();
    } catch (e, st) {
      debugPrint('[CategoryService] delete failed: $e\n$st');
    }
  }

  static Future<bool> update(
    String id,
    String name,
    String icon,
    int color,
  ) async {
    try {
      await _db.from('categories').update({
        'name': name,
        'icon': icon,
        'color': color,
      }).eq('id', id);
      await refreshCache();
      return true;
    } catch (e, st) {
      debugPrint('[CategoryService.update] $e\n$st');
      return false;
    }
  }
}
