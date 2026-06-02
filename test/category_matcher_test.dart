import 'package:flutter_test/flutter_test.dart';
import 'package:balanzo/models/category.dart';
import 'package:balanzo/services/category_matcher.dart';

void main() {
  test('suggests Grocery for dairy product names', () {
    const cats = [
      Category(id: 'g1', name: 'Grocery', icon: 'local_grocery_store', color: 0xFF4CAF50, isDefault: true),
      Category(id: 'o1', name: 'Other', icon: 'category', color: 0xFF9E9E9E, isDefault: true),
    ];
    expect(
      CategoryMatcher.suggestCategoryId('Süd 3.2% 1L', cats),
      'g1',
    );
    expect(
      CategoryMatcher.suggestCategoryId('Poşet S', cats),
      'g1',
    );
  });
}
