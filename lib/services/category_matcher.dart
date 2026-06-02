import '../models/category.dart';

/// Suggests a category for a product name using keyword rules (AZ + EN).
class CategoryMatcher {
  static const _rules = <String, List<String>>{
    'Grocery': [
      'süd', 'pendir', 'yumurta', 'çörək', 'corek', 'un ', 'düyü', 'duyu', 'düyü',
      'ət', 'et ', 'toyuq', 'balıq', 'balig', 'tərəvəz', 'terevez', 'meyvə', 'meyve',
      'pomidor', 'kartof', 'soğan', 'sogan', 'yag', 'yağ', 'şəkər', 'seker', 'çay', 'cay',
      'qəhvə', 'qehve', 'kolbasa', 'bravo', 'araz', 'bizim', 'poşet', 'poset', 'dəst',
      'dest', 'qida', 'market', 'mağaza', 'magaza', 'grocery', 'bread', 'milk', 'cheese',
      'meat', 'fruit', 'vegetable', 'rice', 'flour', 'oil', 'sugar', 'tea', 'coffee',
      'xama', 'qaymaq', 'qaymaqlı', 'vafl', 'trubka', 'cola', 'coca', 'paket', 'mehelle',
      'milla', 'findiq', 'kokos', 'cheesecake', 'xrup', 'pshen', 'şokolad', 'shok',
    ],
    'Restaurant': [
      'stolovaya', 'restoran', 'kafe', 'cafe', 'yemək', 'yemek', 'menu', 'qəlyanaltı',
      'qelyanalti', 'desert', 'dessert', 'restaurant', 'food', 'burger', 'pizza',
    ],
    'Health': [
      'aptek', 'pharmacy', 'dərman', 'derman', 'vitamin', 'health', 'medical', 'tablet',
      'paracetamol', 'məhlul', 'mehlul', 'bandaj',
    ],
    'Transport': [
      'benzin', 'dizel', 'nafta', 'yanacaq', 'fuel', 'petrol', 'taxi', 'metro', 'bus',
    ],
    'Clothing': [
      'geyim', 'ayaqqabı', 'ayaqqabi', 'paltar', 'clothing', 'shirt', 'shoe',
    ],
    'Utilities': [
      'elektrik', 'su ', 'qaz', 'internet', 'telefon', 'utility', 'azərişıq', 'azerisiq',
    ],
    'Education': [
      'məktəb', 'mekteb', 'kitab', 'book', 'school', 'university', 'təhsil', 'tehsil',
    ],
  };

  /// Returns category id whose name best matches [productName], or null.
  static String? suggestCategoryId(String productName, List<Category> categories) {
    if (productName.trim().isEmpty || categories.isEmpty) return null;
    final lower = productName.toLowerCase();

    String? bestCatName;
    var bestScore = 0;
    for (final entry in _rules.entries) {
      var score = 0;
      for (final kw in entry.value) {
        if (lower.contains(kw)) score++;
      }
      if (score > bestScore) {
        bestScore = score;
        bestCatName = entry.key;
      }
    }

    if (bestCatName == null || bestScore == 0) {
      return categories
          .where((c) => c.name.toLowerCase() == 'other')
          .map((c) => c.id)
          .firstOrNull;
    }

    return categories
        .where((c) => c.name.toLowerCase() == bestCatName!.toLowerCase())
        .map((c) => c.id)
        .firstOrNull;
  }

  static String categoryLabel(String? categoryId, List<Category> categories) {
    if (categoryId == null) return 'Other';
    return categories
            .where((c) => c.id == categoryId)
            .map((c) => c.name)
            .firstOrNull ??
        'Other';
  }
}
