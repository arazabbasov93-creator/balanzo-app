import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/receipt.dart';
import '../models/fiscal_duplicate.dart';
import '../models/home_insights.dart';
import '../models/category.dart';
import 'analytics_service.dart';
import 'category_assignment_service.dart';
import 'category_matcher.dart';
import 'category_service.dart';
import 'ekassa_service.dart';

class ReceiptService {
  static final _db = Supabase.instance.client;

  static String? get _userId => _db.auth.currentUser?.id;

  /// Last known unit price for [productName] across the user's saved receipts.
  static Future<double?> findLastUnitPriceForProduct(String productName) async {
    final userId = _userId;
    if (userId == null) return null;
    final needle = productName.trim().toLowerCase();
    if (needle.isEmpty) return null;
    try {
      final receipts = await _db
          .from('receipts')
          .select('id, purchase_date')
          .eq('user_id', userId)
          .order('purchase_date', ascending: false)
          .limit(100);
      final rows = (receipts as List).cast<Map<String, dynamic>>();
      if (rows.isEmpty) return null;
      final dateById = {
        for (final r in rows)
          r['id'] as String: r['purchase_date']?.toString() ?? '',
      };
      final ids = dateById.keys.toList();
      final items = await fetchItemsForReceipts(ids);
      items.sort((a, b) {
        final da = dateById[a['purchase_id'] as String? ?? ''] ?? '';
        final db = dateById[b['purchase_id'] as String? ?? ''] ?? '';
        return db.compareTo(da);
      });
      for (final row in items) {
        final name = (row['product_name'] as String? ??
                row['name_raw'] as String? ??
                '')
            .trim()
            .toLowerCase();
        if (name != needle) continue;
        final price = (row['unit_price'] as num?)?.toDouble() ?? 0;
        if (price > 0) return price;
      }
    } catch (_) {}
    return null;
  }

  /// DB requires purchase_date — caller must supply it (user picks on save sheet).
  static String _purchaseDateString(DateTime? date) {
    if (date == null) {
      throw Exception('Please select the purchase date before saving.');
    }
    return DateTime(date.year, date.month, date.day)
        .toIso8601String()
        .split('T')
        .first;
  }

  /// Personal receipts only (never family-scoped rows).
  static Future<List<Map<String, dynamic>>> fetchPersonal() async {
    final userId = _userId;
    if (userId == null) return [];
    return _fetchPersonal(userId);
  }

  /// Family-shared receipts only. Empty if user has no family.
  static Future<List<Map<String, dynamic>>> fetchFamily() async {
    final userId = _userId;
    if (userId == null) return [];
    final familyId = await _currentFamilyId();
    if (familyId == null) return [];
    final rows = await _db
        .from('receipts')
        .select()
        .eq('family_id', familyId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// All receipts visible to the user (personal + family), deduped by id.
  static Future<List<Map<String, dynamic>>> fetchVisible() async {
    final personal = await fetchPersonal();
    final family = await fetchFamily();
    final seen = <String>{};
    final merged = <Map<String, dynamic>>[];
    for (final row in [...personal, ...family]) {
      final id = row['id'] as String?;
      if (id == null || !seen.add(id)) continue;
      merged.add(row);
    }
    merged.sort((a, b) {
      final ad = a['purchase_date'] as String? ?? '';
      final bd = b['purchase_date'] as String? ?? '';
      return bd.compareTo(ad);
    });
    return merged;
  }

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
    final corrected = await CategoryAssignmentService.assignReceipt(
      receipt.withCorrectedTotals(),
      cats,
    );
    final fiscalId = corrected.documentId?.trim();
    if (fiscalId != null && fiscalId.isNotEmpty) {
      final dup = await findDuplicateByFiscalId(fiscalId);
      if (dup != null) {
        throw FiscalDuplicateException(dup);
      }
    }
    final storeName = corrected.store?.trim();
    final data = <String, dynamic>{
      'user_id': userId,
      'store_name': (storeName != null && storeName.isNotEmpty)
          ? storeName
          : 'Unknown store',
      'purchase_date': _purchaseDateString(corrected.date),
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
        await _insertReceiptItems(
          corrected.items
              .map((item) => _itemPayload(
                    item,
                    receiptId,
                    cats,
                    storeName: corrected.store,
                  ))
              .toList(),
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
    List<Category> categories, {
    String? storeName,
  }) {
    final qty = item.quantity > 0 ? item.quantity : 1.0;
    final unitPrice = item.unitPrice >= 0 ? item.unitPrice : 0.0;
    final totalPrice = item.totalPrice > 0 ? item.totalPrice : qty * unitPrice;
    final name = item.name.trim().isNotEmpty ? item.name.trim() : 'Unknown';
    final catId = item.categoryId ??
        CategoryMatcher.suggestCategoryId(
          name,
          categories,
          storeName: storeName,
        );
    final catLabel = CategoryMatcher.categoryLabel(catId, categories);
    return {
      'purchase_id': receiptId,
      'product_name': name,
      'name_raw': name,
      'category': catLabel,
      if (_isPersistableCategoryId(catId)) 'category_id': catId,
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

    final cats = await CategoryService.fetchAll();
    final fetched = await EkassaService.fetchAndParse(fiscalId);
    final parsed = await CategoryAssignmentService.assignReceipt(fetched, cats);
    final oldItems =
        ((row['receipt_items'] as List?) ?? []).cast<Map<String, dynamic>>();

    final updateData = <String, dynamic>{
      'store_name': parsed.store?.trim().isNotEmpty == true
          ? parsed.store!.trim()
          : row['store_name'],
      'purchase_date':
          parsed.date?.toIso8601String().split('T').first ?? row['purchase_date'],
      'total_amount': parsed.total,
      'vat_amount': parsed.vat,
    };
    if (parsed.isGovernmentVerified) {
      updateData['is_government_verified'] = true;
    }
    await _updateReceipt(receiptId, updateData);

    await _db.from('receipt_items').delete().eq('purchase_id', receiptId);

    if (parsed.items.isNotEmpty) {
      await _insertReceiptItems(
        parsed.items.map((item) {
          final preserved = _matchOldCategory(oldItems, item);
          final withCat = preserved != null
              ? item.copyWith(categoryId: preserved)
              : item;
          return _itemPayload(
            withCat,
            receiptId,
            cats,
            storeName: parsed.store,
          );
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

  /// Inserts line items; drops [category_id] if the column is missing in DB.
  static Future<void> _insertReceiptItems(
    List<Map<String, dynamic>> payloads,
  ) async {
    if (payloads.isEmpty) return;
    try {
      await _db.from('receipt_items').insert(payloads);
    } catch (e) {
      if (isMissingColumnError(e, 'category_id')) {
        final fallback = payloads
            .map((p) => Map<String, dynamic>.from(p)..remove('category_id'))
            .toList();
        try {
          await _db.from('receipt_items').insert(fallback);
        } catch (e2) {
          if (isMissingColumnError(e2, 'category')) {
            final minimal = fallback
                .map((p) => Map<String, dynamic>.from(p)..remove('category'))
                .toList();
            await _db.from('receipt_items').insert(minimal);
            return;
          }
          rethrow;
        }
        return;
      }
      if (isMissingColumnError(e, 'category')) {
        final fallback = payloads
            .map((p) => Map<String, dynamic>.from(p)..remove('category'))
            .toList();
        await _db.from('receipt_items').insert(fallback);
        return;
      }
      rethrow;
    }
  }

  /// True for real Supabase UUID category ids (not in-memory fallbacks).
  static bool _isPersistableCategoryId(String? id) {
    if (id == null || id.isEmpty) return false;
    if (id.startsWith('local_')) return false;
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(id);
  }

  static bool isMissingColumnError(Object e, String column) {
    final msg = e.toString();
    return msg.contains('PGRST204') && msg.contains(column);
  }

  /// Updates item category; uses [category] text if [category_id] column missing.
  static Future<void> updateItemCategory({
    required String itemId,
    String? categoryId,
    required String categoryLabel,
  }) async {
    try {
      await _db.from('receipt_items').update({
        if (_isPersistableCategoryId(categoryId)) 'category_id': categoryId,
        'category': categoryLabel,
      }).eq('id', itemId);
    } catch (e) {
      if (isMissingColumnError(e, 'category_id')) {
        await _db.from('receipt_items').update({
          'category': categoryLabel,
        }).eq('id', itemId);
        return;
      }
      rethrow;
    }
  }

  /// Updates receipt row; omits optional columns missing from older DB schemas.
  static Future<void> _updateReceipt(
    String receiptId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _db.from('receipts').update(data).eq('id', receiptId);
    } catch (e) {
      if (data.containsKey('is_government_verified')) {
        final fallback = Map<String, dynamic>.from(data)
          ..remove('is_government_verified');
        await _db.from('receipts').update(fallback).eq('id', receiptId);
      } else {
        rethrow;
      }
    }
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

  static Future<List<Map<String, dynamic>>> fetchAll({
    bool familyMode = false,
  }) async {
    if (familyMode) return fetchFamily();
    return fetchPersonal();
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

  /// Visible duplicate for [fiscalId] across user + family members.
  static Future<FiscalDuplicateHit?> findDuplicateByFiscalId(String fiscalId) async {
    final normalized = fiscalId.trim();
    if (normalized.isEmpty) return null;
    final userId = _userId;
    if (userId == null) return null;

    try {
      final familyId = await _currentFamilyId();
      final memberIds = <String>{userId};
      if (familyId != null) {
        final members = await _db
            .from('family_members')
            .select('user_id')
            .eq('family_id', familyId);
        for (final m in members as List) {
          final id = m['user_id'] as String?;
          if (id != null) memberIds.add(id);
        }
      }

      final rows = await _db
          .from('receipts')
          .select('id, store_name, purchase_date, user_id, users(full_name, phone, email)')
          .eq('fiscal_id', normalized)
          .inFilter('user_id', memberIds.toList())
          .limit(1);

      if (rows.isEmpty) return null;
      final row = rows.first;
      final owner = row['users'] as Map<String, dynamic>?;
      final label = (owner?['full_name'] as String?)?.trim() ??
          (owner?['phone'] as String?) ??
          (owner?['email'] as String?) ??
          'Someone';
      return FiscalDuplicateHit(
        receiptId: row['id'] as String,
        storeName: row['store_name'] as String? ?? 'Unknown',
        purchaseDate: row['purchase_date'] as String?,
        scannerLabel: label,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchItemsEmbedded(
    List<String> receiptIds,
  ) async {
    if (receiptIds.isEmpty) return [];
    const chunkSize = 40;
    final all = <Map<String, dynamic>>[];
    for (var i = 0; i < receiptIds.length; i += chunkSize) {
      final end =
          (i + chunkSize < receiptIds.length) ? i + chunkSize : receiptIds.length;
      final chunk = receiptIds.sublist(i, end);
      try {
        final rows = await _db
            .from('receipts')
            .select('id, receipt_items(*)')
            .inFilter('id', chunk);
        for (final r in (rows as List).cast<Map<String, dynamic>>()) {
          final rid = r['id'] as String?;
          for (final item
              in ((r['receipt_items'] as List?) ?? []).cast<Map<String, dynamic>>()) {
            if (rid != null) {
              item.putIfAbsent('purchase_id', () => rid);
              item.putIfAbsent('receipt_id', () => rid);
            }
            all.add(item);
          }
        }
      } catch (_) {}
    }
    return all;
  }

  static Future<List<Map<String, dynamic>>> fetchItemsForReceipts(
    List<String> receiptIds, {
    String select =
        'category_id, category, total_price, quantity, unit_price, name_raw, product_name, purchase_id',
  }) async {
    if (receiptIds.isEmpty) return [];
    const chunkSize = 80;
    final all = <Map<String, dynamic>>[];
    for (var i = 0; i < receiptIds.length; i += chunkSize) {
      final end = (i + chunkSize < receiptIds.length) ? i + chunkSize : receiptIds.length;
      final chunk = receiptIds.sublist(i, end);
      all.addAll(await _fetchItemsChunk(chunk, select));
    }
    if (all.isNotEmpty) return all;
    return fetchItemsEmbedded(receiptIds);
  }

  static Future<List<Map<String, dynamic>>> _fetchItemsChunk(
    List<String> receiptIds,
    String select,
  ) async {
    const fallbacks = [
      'category_id, category, total_price, quantity, unit_price, name_raw, product_name, purchase_id',
      'category_id, total_price, quantity, unit_price, name_raw, product_name, purchase_id',
      'total_price, quantity, unit_price, name_raw, product_name, purchase_id',
    ];
    final tries = [select, ...fallbacks.where((s) => s != select)];

    Object? lastError;
    for (final sel in tries) {
      try {
        final rows = await _db
            .from('receipt_items')
            .select(sel)
            .inFilter('purchase_id', receiptIds);
        return (rows as List).cast<Map<String, dynamic>>();
      } catch (e) {
        lastError = e;
        if (!isMissingColumnError(e, 'category_id') &&
            !isMissingColumnError(e, 'category')) {
          break;
        }
      }
    }

    try {
      final rows = await _db
          .from('receipt_items')
          .select(tries.last)
          .inFilter('receipt_id', receiptIds);
      return (rows as List).cast<Map<String, dynamic>>();
    } catch (e) {
      lastError = e;
    }

    if (!isMissingColumnError(lastError, 'category_id') &&
        !isMissingColumnError(lastError, 'category') &&
        !lastError.toString().contains('receipt_id')) {
      // Embedded fetch handled by caller.
    }
    return [];
  }

  /// Sum of line-item totals grouped by category for the given receipt ids.
  static Future<Map<String, double>> categoryTotalsForReceiptIds(
    List<String> receiptIds, {
    List<Category>? categories,
    Map<String, String>? storeByReceiptId,
  }) async {
    if (receiptIds.isEmpty) return {};
    final cats = categories ?? await CategoryService.fetchAll();
    try {
      final items = await fetchItemsForReceipts(receiptIds);
      final totals = _aggregateCategoryTotals(
        items,
        cats,
        storeByReceiptId: storeByReceiptId,
      );
      if (totals.isNotEmpty) return totals;
    } catch (_) {}

    try {
      final items = await fetchItemsForReceipts(
        receiptIds,
        select:
            'total_price, quantity, unit_price, name_raw, product_name, purchase_id',
      );
      return _aggregateCategoryTotals(
        items,
        cats,
        storeByReceiptId: storeByReceiptId,
      );
    } catch (_) {
      return {};
    }
  }

  /// Line items grouped by category key for drill-down UI.
  static Map<String, List<CategoryItemDetail>> categoryItemsForReceiptIds(
    List<Map<String, dynamic>> items,
    List<Category> categories, {
    Map<String, String>? storeByReceiptId,
  }) {
    final grouped = <String, Map<String, CategoryItemDetail>>{};
    for (final item in items) {
      final name = (item['product_name'] as String? ??
              item['name_raw'] as String? ??
              '')
          .trim();
      if (name.isEmpty) continue;
      final price = _itemTotalPrice(item);
      final qty = (item['quantity'] as num?)?.toDouble() ?? 1;
      final store = _storeForItem(item, storeByReceiptId);
      final key =
          _categoryKeyForItem(item, categories, storeName: store);
      grouped.putIfAbsent(key, () => {});
      final bucket = grouped[key]!;
      final existing = bucket[name];
      if (existing == null) {
        bucket[name] = CategoryItemDetail(
          name: name,
          amount: price,
          quantity: qty,
        );
      } else {
        bucket[name] = CategoryItemDetail(
          name: name,
          amount: existing.amount + price,
          quantity: existing.quantity + qty,
        );
      }
    }
    return grouped.map(
      (key, items) => MapEntry(
        key,
        items.values.toList()..sort((a, b) => b.amount.compareTo(a.amount)),
      ),
    );
  }

  /// Line total from [total_price], or [unit_price] × [quantity] when missing.
  static double itemLineTotal(Map<String, dynamic> item) => _itemTotalPrice(item);

  static double _itemTotalPrice(Map<String, dynamic> item) {
    final total = (item['total_price'] as num?)?.toDouble();
    if (total != null && total > 0) return total;
    final qty = (item['quantity'] as num?)?.toDouble() ?? 1;
    final unit = (item['unit_price'] as num?)?.toDouble() ?? 0;
    if (unit > 0) return unit * qty;
    return 0;
  }

  static Map<String, double> _aggregateCategoryTotals(
    List<Map<String, dynamic>> items,
    List<Category> categories, {
    Map<String, String>? storeByReceiptId,
  }) {
    final totals = <String, double>{};
    for (final item in items) {
      final price = _itemTotalPrice(item);
      if (price <= 0) continue;
      final store = _storeForItem(item, storeByReceiptId);
      final key = _categoryKeyForItem(item, categories, storeName: store);
      totals[key] = (totals[key] ?? 0) + price;
    }
    return totals;
  }

  static String? _storeForItem(
    Map<String, dynamic> item,
    Map<String, String>? storeByReceiptId,
  ) {
    if (storeByReceiptId == null) return null;
    final purchaseId = item['purchase_id'] as String? ??
        item['receipt_id'] as String?;
    if (purchaseId == null) return null;
    return storeByReceiptId[purchaseId];
  }

  /// Resolves a stable category key (prefer DB uuid, else category name).
  static String categoryKeyForItem(
    Map<String, dynamic> item,
    List<Category> categories, {
    String? storeName,
  }) =>
      _categoryKeyForItem(item, categories, storeName: storeName);

  static String _categoryKeyForItem(
    Map<String, dynamic> item,
    List<Category> categories, {
    String? storeName,
  }) {
    final otherId = CategoryMatcher.otherCategoryId(categories);

    final productName =
        (item['product_name'] as String? ?? item['name_raw'] as String? ?? '')
            .trim();
    if (productName.isNotEmpty) {
      final productScore = CategoryMatcher.productMatchScore(productName);
      if (productScore > 0) {
        final suggested = CategoryMatcher.suggestCategoryId(
          productName,
          categories,
          allowStoreFallback: false,
        );
        if (suggested != null && suggested != otherId) return suggested;
      }
    }

    final catId = item['category_id'] as String?;
    if (catId != null && catId.isNotEmpty && catId != otherId) {
      final match = categories.where((c) => c.id == catId).firstOrNull;
      if (match != null) return match.id;
    }

    final label = (item['category'] as String?)?.trim();
    if (label != null &&
        label.isNotEmpty &&
        label.toLowerCase() != 'other') {
      final byName = categories
          .where((c) => c.name.toLowerCase() == label.toLowerCase())
          .firstOrNull;
      if (byName != null) return byName.id;
    }

    if (productName.isNotEmpty) {
      final suggested = CategoryMatcher.suggestCategoryId(
        productName,
        categories,
        storeName: storeName,
      );
      if (suggested != null && suggested != otherId) return suggested;
    }

    if (storeName != null && storeName.trim().isNotEmpty) {
      final fromStore = CategoryMatcher.suggestCategoryId(
        '',
        categories,
        storeName: storeName,
      );
      if (fromStore != null && fromStore != otherId) return fromStore;
    }

    if (catId != null && catId.isNotEmpty) return catId;
    if (label != null && label.isNotEmpty) {
      final byName = categories
          .where((c) => c.name.toLowerCase() == label.toLowerCase())
          .firstOrNull;
      if (byName != null) return byName.id;
    }

    return otherId ?? '_other';
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
    return categoryTotalsForReceiptIds(ids);
  }

  /// Deletes a receipt and cascades to its items (FK cascade expected in DB).
  static Future<void> delete(String id) async {
    await _db.from('receipts').delete().eq('id', id);
  }

  /// Move receipt between personal (family_id null) and family shared bucket.
  static Future<void> setFamilyScope(String receiptId, {required bool asFamily}) async {
    final userId = _userId;
    if (userId == null) throw Exception('Please sign in.');

    if (asFamily) {
      final familyId = await _currentFamilyId();
      if (familyId == null) {
        throw Exception('Join or create a family to share this receipt.');
      }
      await _db
          .from('receipts')
          .update({'family_id': familyId})
          .eq('id', receiptId)
          .eq('user_id', userId);
    } else {
      await _db
          .from('receipts')
          .update({'family_id': null})
          .eq('id', receiptId)
          .eq('user_id', userId);
    }
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
      final itemRows =
          await _db.from('receipt_items').select('purchase_id');
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

class FiscalDuplicateException implements Exception {
  final FiscalDuplicateHit hit;
  FiscalDuplicateException(this.hit);

  @override
  String toString() => 'Receipt already scanned by ${hit.scannerLabel}';
}
