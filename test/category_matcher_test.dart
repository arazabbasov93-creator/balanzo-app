import 'package:flutter_test/flutter_test.dart';
import 'package:balanzo/models/category.dart';
import 'package:balanzo/models/receipt.dart';
import 'package:balanzo/services/category_assignment_service.dart';
import 'package:balanzo/services/category_matcher.dart';

const _cats = [
  Category(id: 'g1', name: 'Grocery', icon: 'local_grocery_store', color: 0xFF4CAF50, isDefault: true),
  Category(id: 'r1', name: 'Restaurant', icon: 'restaurant', color: 0xFFFF9800, isDefault: true),
  Category(id: 't1', name: 'Tobacco', icon: 'smoking_rooms', color: 0xFF795548, isDefault: true),
  Category(id: 'h1', name: 'Health', icon: 'local_pharmacy', color: 0xFFF44336, isDefault: true),
  Category(id: 'o1', name: 'Other', icon: 'category', color: 0xFF9E9E9E, isDefault: true),
];

void main() {
  group('CategoryMatcher', () {
    test('suggests Grocery for dairy and market product names', () {
      expect(CategoryMatcher.suggestCategoryId('Süd 3.2% 1L', _cats), 'g1');
      expect(CategoryMatcher.suggestCategoryId('Poşet S', _cats), 'g1');
      expect(CategoryMatcher.suggestCategoryId('ASSORTI TORT M.R', _cats), 'g1');
      expect(CategoryMatcher.suggestCategoryId('MEHELLE PAKET', _cats), 'g1');
    });

    test('suggests Health for pharmacy products and store', () {
      expect(
        CategoryMatcher.suggestCategoryId('18% MEKSUN 7.5mg N10', _cats),
        'h1',
      );
      expect(
        CategoryMatcher.suggestCategoryId('LORATADIN 10MG N10', _cats),
        'h1',
      );
      expect(
        CategoryMatcher.suggestCategoryId('Random item', _cats, storeName: 'APTEK'),
        'h1',
      );
    });

    test('suggests Restaurant for prepared food names', () {
      expect(CategoryMatcher.suggestCategoryId('Katlet durum', _cats), 'r1');
      expect(CategoryMatcher.suggestCategoryId('DONER KEBAB', _cats), 'r1');
    });

    test('suggests Tobacco for cigarette product names', () {
      expect(
        CategoryMatcher.suggestCategoryId('WINCESTR KSS SILVER', _cats),
        't1',
      );
      expect(CategoryMatcher.suggestCategoryId('Marlboro gold', _cats), 't1');
    });

    test('product name beats grocery store fallback', () {
      expect(
        CategoryMatcher.suggestCategoryId('Katlet durum', _cats, storeName: 'BRAVO MARKET'),
        'r1',
      );
    });

    test('falls back to Other when no match', () {
      expect(
        CategoryMatcher.suggestCategoryId('Unknown SKU 999', _cats),
        'o1',
      );
    });
  });

  group('CategoryAssignmentService', () {
    test('assigns categories to all items from store and product names', () async {
      const receipt = Receipt(
        store: 'MƏHƏLLƏ MARKET',
        items: [
          ReceiptItem(name: 'ASSORTI TORT M.R', quantity: 1, unitPrice: 2.25, totalPrice: 2.25),
          ReceiptItem(name: 'MEHELLE PAKET', quantity: 1, unitPrice: 0.04, totalPrice: 0.04),
        ],
        subtotal: 2.29,
        vat: 0,
        total: 2.29,
      );
      final assigned = await CategoryAssignmentService.assignReceipt(receipt, _cats);
      expect(assigned.items.every((i) => i.categoryId != null), isTrue);
      expect(assigned.items.first.categoryId, 'g1');
    });

    test('preserves existing category ids', () async {
      const receipt = Receipt(
        items: [
          ReceiptItem(
            name: 'X',
            quantity: 1,
            unitPrice: 1,
            totalPrice: 1,
            categoryId: 'h1',
          ),
        ],
        subtotal: 1,
        vat: 0,
        total: 1,
      );
      final assigned = await CategoryAssignmentService.assignReceipt(receipt, _cats);
      expect(assigned.items.first.categoryId, 'h1');
    });
  });
}
