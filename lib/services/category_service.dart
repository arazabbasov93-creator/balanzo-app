import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/category.dart';

class CategoryService {
  static final _db = Supabase.instance.client;
  static String? get _userId => _db.auth.currentUser?.id;

  /// In-memory catalog for UI when DB is unreachable (preview only).
  static List<Category> localFallback() {
    return defaultCategories.asMap().entries.map((e) {
      final dc = e.value;
      return Category(
        id: 'local_${dc['name']}',
        name: dc['name'] as String,
        icon: dc['icon'] as String,
        color: dc['color'] as int,
        isDefault: true,
      );
    }).toList();
  }

  static Future<List<Category>> fetchAll() async {
    try {
      var list = await _fetchFromDb();
      if (_userId != null) {
        list = await _ensureDefaultCategoriesPresent(list);
      }
      return list.isNotEmpty ? list : localFallback();
    } catch (_) {
      return localFallback();
    }
  }

  static Future<List<Category>> _fetchFromDb() async {
    final rows = await _db.from('categories').select().order('name');
    return (rows as List)
        .map((r) => Category.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Creates missing default-named categories for the signed-in user.
  /// Server defaults (is_default=true) are visible via RLS; if none exist,
  /// user-owned copies are created (RLS allows insert with user_id).
  static Future<List<Category>> _ensureDefaultCategoriesPresent(
    List<Category> existing,
  ) async {
    final names = existing.map((c) => c.name.toLowerCase()).toSet();
    var created = false;
    for (final dc in defaultCategories) {
      final name = dc['name'] as String;
      if (names.contains(name.toLowerCase())) continue;
      final cat = await create(
        name,
        dc['icon'] as String,
        dc['color'] as int,
      );
      if (cat != null) created = true;
    }
    if (created) return _fetchFromDb();
    return existing;
  }

  static Future<Category?> create(String name, String icon, int color) async {
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
            'is_default': false,
          })
          .select()
          .single();
      return Category.fromJson(row);
    } catch (_) {
      return null;
    }
  }

  static Future<void> delete(String id) async {
    try {
      await _db.from('categories').delete().eq('id', id);
    } catch (_) {}
  }
}
