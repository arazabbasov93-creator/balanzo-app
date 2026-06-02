import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/category.dart';

class CategoryService {
  static final _db = Supabase.instance.client;
  static String get _userId => _db.auth.currentUser!.id;

  static Future<List<Category>> fetchAll() async {
    try {
      var rows = await _db
          .from('categories')
          .select()
          .order('name');
      var list = (rows as List)
          .map((r) => Category.fromJson(r as Map<String, dynamic>))
          .toList();
      if (list.isEmpty) {
        await seedDefaults();
        rows = await _db.from('categories').select().order('name');
        list = (rows as List)
            .map((r) => Category.fromJson(r as Map<String, dynamic>))
            .toList();
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  static Future<Category?> create(String name, String icon, int color) async {
    try {
      final row = await _db
          .from('categories')
          .insert({
            'user_id': _userId,
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

  /// Seeds default categories. Safe to call multiple times.
  static Future<void> seedDefaults() async {
    try {
      final existing = await _db.from('categories').select('id').limit(1);
      if ((existing as List).isNotEmpty) return;
      await _db.from('categories').insert(
        defaultCategories
            .map((c) => {
                  'name': c['name'],
                  'icon': c['icon'],
                  'color': c['color'],
                  'is_default': true,
                })
            .toList(),
      );
    } catch (_) {}
  }
}
