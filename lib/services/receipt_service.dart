import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/receipt.dart';
import '../models/category.dart';
import 'analytics_service.dart';
import 'category_matcher.dart';
import 'category_service.dart';
import 'ekassa_service.dart';

class ReceiptService {
  static final _db = Supabase.instance.client;

  static String? get _userId => _db.auth.currentUser?.id;

  /// Saves a parsed receipt + its items. Returns the new receipt row id.
  /// If item insert fails the receipt is rolled back to avoid orphans.
  static Future<String> save(
    Receipt receipt, {
    List<Category>? categories,
    bool saveAsFamily = false,
  }) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('Please sign in to save receipts.');
    }

    final cats = categories ?? await CategoryService.fetchAll();
    final corrected = receipt.withCorrectedTotals();
    final storeName = corrected.store?.trim();
    final data = <String, dynamic>{
      'user_id': userId,
      'store_name': (storeName != null && storeName.isNotEmpty)
          ? storeName
          : 'Unknown store',
      'purchase_date': corrected.date?.toIso8601String().split('T').first,
      'vat_amount': corrected.vat,
      'total_amount': corrected.total,
    };
    if (corrected.documentId != null) data['fiscal_id'] = corrected.documentId;
    if (corrected.isGovernmentVerified) data['is_government_verified'] = true;
    if (saveAsFamily) {
      final familyId = await _currentFamilyId();
      if (familyId != null) data['family_id'] = familyId;
    }

    Map<String, dynamic> receiptRow;
    try {
      receiptRow = await _db.from('receipts').insert(data).select('id').single();
    } catch (e) {
      data.remove('is_government_verified');
      try {
        receiptRow =
            await _db.from('receipts').insert(data).select('id').single();
      } catch (_) {
        data.remove('fiscal_id');
        data.remove('family_id');
        receiptRow =
            await _db.from('receipts').insert(data).select('id').single();
      }
    }
    final receiptId = receiptRow['id'] as String;

    if (corrected.items.isNotEmpty) {
      try {
        await _db.from('receipt_items').insert(
          corrected.items.map((item) => _itemPayload(item, receiptId, cats)).toList(),
        );
      } catch (e) {
        try {
          await _db.from('receipts').delete().eq('id', receiptId);
        } catch (_) {}
        rethrow;
      }
    }

    await AnalyticsService.log(
      'receipt_scanned',
      {'store': (corrected.store ?? 'unknown') as Object},
    );
    return receiptId;
  }

  static Map<String, dynamic> _itemPayload(
    ReceiptItem item,
    String receiptId,
    List<Category> categories,
  ) {
    final qty = item.quantity > 0 ? item.quantity : 1.0;
    final unitPrice = item.unitPrice >= 0 ? item.unitPrice : 0.0;
    final totalPrice = item.totalPrice > 0 ? item.totalPrice : qty * unitPrice;
    final name = item.name.trim().isNotEmpty ? item.name.trim() : 'Unknown';
    final catId = item.categoryId ??
        CategoryMatcher.suggestCategoryId(name, categories);
    final catLabel = CategoryMatcher.categoryLabel(catId, categories);
    return {
      'purchase_id': receiptId,
      'product_name': name,
      'name_raw': name,
      'category': catLabel,
      if (catId != null) 'category_id': catId,
      'quantity': qty,
      'unit_price': unitPrice,
      'total_price': totalPrice,
      'unit': 'pcs',
      'barcode': null,
      'product_id': null,
    };
  }

  /// Re-fetches e-kassa receipt by stored [fiscal_id] and replaces line items.
  /// Cost: free government HTTP + on-device OCR; AI only if structured parse fails.
  static Future<Receipt> refreshFromFiscalId(String receiptId) async {
    final row = await fetchById(receiptId);
    final fiscalId = row['fiscal_id'] as String?;
    if (fiscalId == null || fiscalId.trim().isEmpty) {
      throw Exception('This receipt has no fiscal ID — cannot refresh from e-kassa.');
    }

    final parsed = await EkassaService.fetchAndParse(fiscalId);
    final cats = await CategoryService.fetchAll();
    final oldItems =
        ((row['receipt_items'] as List?) ?? []).cast<Map<String, dynamic>>();

    await _db.from('receipts').update({
      'store_name': parsed.store?.trim().isNotEmpty == true
          ? parsed.store!.trim()
          : row['store_name'],
      'purchase_date':
          parsed.date?.toIso8601String().split('T').first ?? row['purchase_date'],
      'total_amount': parsed.total,
      'vat_amount': parsed.vat,
      'is_government_verified': true,
    }).eq('id', receiptId);

    await _db.from('receipt_items').delete().eq('purchase_id', receiptId);

    if (parsed.items.isNotEmpty) {
      await _db.from('receipt_items').insert(
        parsed.items.map((item) {
          final preserved = _matchOldCategory(oldItems, item);
          final withCat = preserved != null
              ? item.copyWith(categoryId: preserved)
              : item.copyWith(
                  categoryId: CategoryMatcher.suggestCategoryId(item.name, cats),
                );
          return _itemPayload(withCat, receiptId, cats);
        }).toList(),
      );
    }

    return parsed;
  }

  static String? _matchOldCategory(
    List<Map<String, dynamic>> oldItems,
    ReceiptItem newItem,
  ) {
    final newName = newItem.name.toLowerCase().trim();
    for (final old in oldItems) {
      final oldName = (old['product_name'] as String? ?? '').toLowerCase().trim();
      final oldCat = old['category_id'] as String?;
      if (oldCat == null) continue;
      if (oldName == newName) return oldCat;
      if (oldName.isNotEmpty &&
          newName.isNotEmpty &&
          (oldName.contains(newName) || newName.contains(oldName))) {
        return oldCat;
      }
      final oldPrice = (old['unit_price'] as num?)?.toDouble();
      if (oldPrice != null &&
          (oldPrice - newItem.unitPrice).abs() < 0.02 &&
          oldName.length > 3 &&
          newName.length > 3) {
        return oldCat;
      }
    }
    return null;
  }

  static Future<String?> _currentFamilyId() async {
    final userId = _userId;
    if (userId == null) return null;
    try {
      final row = await _db
          .from('family_members')
          .select('family_id')
          .eq('user_id', userId)
          .maybeSingle();
      return row?['family_id'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Fetches receipts for personal or family view.
  static Future<List<Map<String, dynamic>>> fetchAll({
    bool familyMode = false,
  }) async {
    final userId = _userId;
    if (userId == null) return [];

    if (familyMode) {
      final familyId = await _currentFamilyId();
      if (familyId == null) {
        return _fetchPersonal(userId);
      }
      final rows = await _db
          .from('receipts')
          .select()
          .eq('family_id', familyId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows as List);
    }
    return _fetchPersonal(userId);
  }

  static Future<List<Map<String, dynamic>>> _fetchPersonal(String userId) async {
    try {
      final rows = await _db
          .from('receipts')
          .select()
          .eq('user_id', userId)
          .isFilter('family_id', null)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (_) {
      final rows = await _db
          .from('receipts')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return (rows as List)
          .cast<Map<String, dynamic>>()
          .where((r) => r['family_id'] == null)
          .toList();
    }
  }

  /// Fetches a single receipt with its items.
  static Future<Map<String, dynamic>> fetchById(String id) async {
    final row = await _db
        .from('receipts')
        .select('*, receipt_items(*)')
        .eq('id', id)
        .single();
    return Map<String, dynamic>.from(row);
  }

  /// Sum of item totals by category_id for receipts in [month]/[year].
  static Future<Map<String, double>> categoryTotalsForMonth(
    int month,
    int year, {
    bool familyMode = false,
  }) async {
    final receipts = await fetchAll(familyMode: familyMode);
    final ids = <String>[];
    for (final r in receipts) {
      final dateStr = r['purchase_date'] as String?;
      final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
      if (date != null && date.year == year && date.month == month) {
        ids.add(r['id'] as String);
      }
    }
    if (ids.isEmpty) return {};

    try {
      final items = await _db
          .from('receipt_items')
          .select('category_id, total_price')
          .inFilter('purchase_id', ids);
      final totals = <String, double>{};
      for (final item in items as List) {
        final catId = item['category_id'] as String? ?? '_other';
        final price = (item['total_price'] as num?)?.toDouble() ?? 0;
        totals[catId] = (totals[catId] ?? 0) + price;
      }
      return totals;
    } catch (_) {
      return {};
    }
  }

  /// Deletes a receipt and cascades to its items (FK cascade expected in DB).
  static Future<void> delete(String id) async {
    await _db.from('receipts').delete().eq('id', id);
  }

  /// Monthly spending totals for the current user (last 6 months).
  static Future<List<Map<String, dynamic>>> monthlySummary() async {
    final userId = _userId;
    if (userId == null) return [];
    final rows = await _db
        .from('receipts')
        .select('purchase_date, total_amount')
        .eq('user_id', userId)
        .order('purchase_date', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// Deletes receipts that have no associated items (orphans).
  static Future<void> deleteOrphanReceipts() async {
    try {
      final userId = _db.auth.currentUser?.id;
      if (userId == null) return;
      final receipts = await _db
          .from('receipts')
          .select('id')
          .eq('user_id', userId);
      if ((receipts as List).isEmpty) return;
      final itemRows = await _db
          .from('receipt_items')
          .select('purchase_id');
      final receiptIds = (itemRows as List)
          .map((r) => r['purchase_id'] as String?)
          .whereType<String>()
          .toSet();
      for (final r in receipts) {
        final id = r['id'] as String;
        if (!receiptIds.contains(id)) {
          await _db.from('receipts').delete().eq('id', id);
        }
      }
    } catch (_) {}
  }
}
