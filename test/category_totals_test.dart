import 'package:flutter_test/flutter_test.dart';
import 'package:balanzo/models/category.dart';
import 'package:balanzo/services/receipt_service.dart';

void main() {
  final categories = [
    Category(id: 'g1', name: 'Grocery', icon: 'cart', color: 0xFF4CAF50),
    Category(id: 'h1', name: 'Health', icon: 'med', color: 0xFF2196F3),
    Category(id: 'o1', name: 'Other', icon: 'category', color: 0xFF9E9E9E),
  ];

  test('categoryKeyForItem uses category text label', () {
    final key = ReceiptService.categoryKeyForItem({
      'category': 'Grocery',
      'name_raw': 'YUMURTA',
    }, categories);
    expect(key, 'g1');
  });

  test('categoryKeyForItem infers from product name when label missing', () {
    final key = ReceiptService.categoryKeyForItem({
      'name_raw': 'MILLA PENDIR QAYMAQLI',
    }, categories);
    expect(key, 'g1');
  });

  test('categoryKeyForItem re-infers when stored as Other', () {
    final key = ReceiptService.categoryKeyForItem({
      'category': 'Other',
      'category_id': 'o1',
      'name_raw': 'MILLA PENDIR QAYMAQLI',
    }, categories);
    expect(key, 'g1');
  });

  test('categoryKeyForItem uses store when product ambiguous', () {
    final key = ReceiptService.categoryKeyForItem({
      'category': 'Other',
      'name_raw': 'XYZ123',
    }, categories, storeName: 'Bravo Market');
    expect(key, 'g1');
  });

  test('itemLineTotal uses unit_price × quantity when total_price missing', () {
    expect(
      ReceiptService.itemLineTotal({
        'quantity': 2,
        'unit_price': 1.5,
      }),
      3.0,
    );
  });
}
