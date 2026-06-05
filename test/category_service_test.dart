import 'package:flutter_test/flutter_test.dart';
import 'package:balanzo/models/category.dart';
import 'package:balanzo/services/category_service.dart';

void main() {
  test('localFallback never returns empty catalog', () {
    final cats = CategoryService.localFallback();
    expect(cats.length, defaultCategories.length);
    expect(cats.any((c) => c.name == 'Grocery'), isTrue);
    expect(cats.any((c) => c.name == 'Other'), isTrue);
  });
}
