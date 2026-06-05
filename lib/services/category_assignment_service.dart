import '../models/category.dart';
import '../models/receipt.dart';
import 'category_matcher.dart';

/// Single entry point for assigning categories to parsed receipt items.
/// Used by save sheet, save/refresh services, and any future OCR pipeline output.
class CategoryAssignmentService {
  /// Ensures every item has a [categoryId] when possible.
  /// Preserves user-assigned or pre-set category ids.
  static List<ReceiptItem> assignItems(
    List<ReceiptItem> items,
    List<Category> categories, {
    String? storeName,
  }) {
    if (items.isEmpty || categories.isEmpty) return items;
    return items.map((item) {
      if (item.categoryId != null) return item;
      final id = CategoryMatcher.suggestCategoryId(
        item.name,
        categories,
        storeName: storeName,
      );
      if (id == null) return item;
      return item.copyWith(categoryId: id);
    }).toList();
  }

  static Receipt assignReceipt(Receipt receipt, List<Category> categories) {
    if (receipt.items.isEmpty || categories.isEmpty) return receipt;
    return Receipt(
      store: receipt.store,
      date: receipt.date,
      items: assignItems(
        receipt.items,
        categories,
        storeName: receipt.store,
      ),
      subtotal: receipt.subtotal,
      serviceCharge: receipt.serviceCharge,
      vat: receipt.vat,
      total: receipt.total,
      currency: receipt.currency,
      isGovernmentVerified: receipt.isGovernmentVerified,
      documentId: receipt.documentId,
    );
  }
}
