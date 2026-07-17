import '../models/category.dart';
import '../models/receipt.dart';
import 'category_matcher.dart';
import 'category_service.dart';

/// Single entry point for assigning categories to parsed receipt items.
/// Used by save sheet, save/refresh services, and any future OCR pipeline output.
class CategoryAssignmentService {
  /// Ensures every item has a [categoryId] when possible.
  /// Preserves user-assigned or pre-set category ids.
  static Future<List<ReceiptItem>> assignItems(
    List<ReceiptItem> items,
    List<Category> categories, {
    String? storeName,
  }) async {
    if (items.isEmpty || categories.isEmpty) return items;
    final cats = CategoryService.cached.isNotEmpty ? CategoryService.cached : categories;
    final results = <ReceiptItem>[];
    for (final item in items) {
      if (item.categoryId != null) {
        results.add(item);
        continue;
      }
      final aiName = item.categoryName?.trim();
      if (aiName != null && aiName.isNotEmpty) {
        results.add(await _selfHealCategoryName(item, aiName, cats));
        continue;
      }
      final id = CategoryMatcher.suggestCategoryId(
        item.name,
        cats,
        storeName: storeName,
      );
      if (id == null) {
        results.add(item);
      } else {
        results.add(item.copyWith(categoryId: id));
      }
    }
    return results;
  }

  static Future<Receipt> assignReceipt(
    Receipt receipt,
    List<Category> categories,
  ) async {
    if (receipt.items.isEmpty || categories.isEmpty) return receipt;
    return Receipt(
      store: receipt.store,
      date: receipt.date,
      items: await assignItems(
        receipt.items,
        categories,
        storeName: receipt.store,
      ),
      subtotal: receipt.subtotal,
      serviceCharge: receipt.serviceCharge,
      discountTotal: receipt.discountTotal,
      vat: receipt.vat,
      total: receipt.total,
      currency: receipt.currency,
      isGovernmentVerified: receipt.isGovernmentVerified,
      documentId: receipt.documentId,
      sequenceNumber: receipt.sequenceNumber,
    );
  }

  static Future<ReceiptItem> _selfHealCategoryName(
    ReceiptItem item,
    String name,
    List<Category> cats,
  ) async {
    final cached = cats
        .where((c) => c.name.toLowerCase() == name.toLowerCase())
        .firstOrNull;
    if (cached != null) {
      return item.copyWith(categoryId: cached.id, categoryName: cached.name);
    }

    final global = await CategoryService.findGlobalByName(name);
    if (global != null) {
      final copy = await CategoryService.create(
        global.name,
        global.icon,
        global.color,
        isDefault: true,
      );
      if (copy != null) {
        return item.copyWith(categoryId: copy.id, categoryName: copy.name);
      }
    }

    final otherId = CategoryMatcher.otherCategoryId(
      CategoryService.cached.isNotEmpty ? CategoryService.cached : cats,
    );
    return item.copyWith(categoryId: otherId, categoryName: 'Other');
  }
}
