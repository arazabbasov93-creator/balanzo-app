import 'package:flutter_test/flutter_test.dart';
import 'package:balanzo/services/category_service.dart';

void main() {
  test('cached starts empty before refresh', () {
    CategoryService.clearCache();
    expect(CategoryService.cached, isEmpty);
  });
}
