import '../l10n/app_strings.dart';
import '../models/category.dart';

/// Localized label for a category — defaults via [AppStrings.categoryName],
/// custom user categories shown as stored.
String displayCategoryName(Category category, String locale) {
  return AppStrings.categoryName(category.name, locale);
}

String displayCategoryNameById(
  String? categoryId,
  List<Category> categories,
  String locale,
) {
  if (categoryId == null) {
    return AppStrings.get('cat_other', locale);
  }
  final cat = categories.where((c) => c.id == categoryId).firstOrNull;
  if (cat == null) {
    return AppStrings.get('cat_other', locale);
  }
  return displayCategoryName(cat, locale);
}

String displayCategoryNameRaw(String? englishName, String locale) {
  if (englishName == null || englishName.trim().isEmpty) {
    return AppStrings.get('cat_other', locale);
  }
  return AppStrings.categoryName(englishName.trim(), locale);
}
