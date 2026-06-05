import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/budget.dart';
import 'receipt_service.dart';
import 'category_service.dart';

class BudgetService {
  static final _db = Supabase.instance.client;
  static String get _userId => _db.auth.currentUser!.id;

  static Future<List<Budget>> fetchForMonth(int month, int year, {String? familyId}) async {
    var query = _db
        .from('budgets')
        .select('*, categories(name, icon, color)')
        .eq('month', month)
        .eq('year', year);

    if (familyId != null) {
      query = query.eq('family_id', familyId);
    } else {
      query = query.eq('user_id', _userId);
    }

    final rows = await query.order('created_at');
    return (rows as List)
        .map((r) => Budget.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  static Future<Budget> upsert({
    required String? categoryId,
    required double amount,
    required int month,
    required int year,
    String? familyId,
  }) async {
    final data = <String, dynamic>{
      'amount': amount,
      'month': month,
      'year': year,
      'category_id': categoryId,
    };
    if (familyId != null) {
      data['family_id'] = familyId;
    } else {
      data['user_id'] = _userId;
    }
    final row = await _db
        .from('budgets')
        .upsert(data, onConflict: familyId != null
            ? 'family_id,category_id,month,year'
            : 'user_id,category_id,month,year')
        .select('*, categories(name, icon, color)')
        .single();
    return Budget.fromJson(row);
  }

  static Future<void> delete(String id) async {
    await _db.from('budgets').delete().eq('id', id);
  }

  /// Calculates spent amounts per category for the given month.
  static Future<Map<String, double>> spentByCategory(
      int month, int year, {String? familyId}) async {
    final pad = month.toString().padLeft(2, '0');
    final from = '$year-$pad-01';
    final to = '$year-$pad-31';

    // Fetch matching receipt IDs first
    var receiptQuery = _db
        .from('receipts')
        .select('id')
        .gte('purchase_date', from)
        .lte('purchase_date', to);
    receiptQuery = familyId != null
        ? receiptQuery.eq('family_id', familyId)
        : receiptQuery.eq('user_id', _userId);

    final receiptRows = await receiptQuery;
    final ids = (receiptRows as List).map((r) => r['id'] as String).toList();
    if (ids.isEmpty) return {};

    final items = await ReceiptService.fetchItemsForReceipts(
      ids,
      select: 'category_id, category, total_price',
    );

    final categories = await CategoryService.fetchAll();
    final Map<String, double> totals = {};
    for (final r in items) {
      final key = ReceiptService.categoryKeyForItem(r, categories);
      final price = (r['total_price'] as num?)?.toDouble() ?? 0;
      totals[key] = (totals[key] ?? 0) + price;
    }
    return totals;
  }
}
