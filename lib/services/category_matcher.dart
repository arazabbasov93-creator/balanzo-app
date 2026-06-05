import '../models/category.dart';

// FALLBACK ONLY: This keyword matcher runs when AI
// is unavailable or API key is not configured.
// AI is the primary category assignment path and
// handles all languages and formats globally.
// Do not extend these keywords per market or
// language — AI handles global categorization.
// Do not remove this file.

/// Suggests a category for a product name using keyword rules (AZ + EN + RU).
/// Store name is only used when the product name has no keyword match.
class CategoryMatcher {
  static const _rules = <String, List<String>>{
    'Tobacco': [
      'siqaret', 'cigarette', 'tobacco', 'winston', 'wincestr', 'winchester',
      'marlboro', 'camel', 'kent', 'parliament', 'pall mall', 'l&m',
      'kss silver', 'kss gold', 'kss blue', ' kss', 'kss ',
      'chesterfield', 'bond street', 'manchester', 'philip morris',
      'сигарет', 'табак', 'tütün', 'tutun',
    ],
    'Restaurant': [
      'katlet', 'cutlet', 'durum', 'dönər', 'doner', 'shawarma', 'shaurma',
      'burger', 'pizza', 'hot dog', 'hotdog', 'lavaş', 'lavas', 'lavash',
      'qutab', 'kutab', 'plov', 'dolma', 'soup', 'corba', 'çorba',
      'stolovaya', 'restoran', 'kafe', 'cafe', 'yemək', 'yemek', 'menu',
      'qəlyanaltı', 'qelyanalti', 'desert', 'dessert', 'restaurant', 'food',
      'sandwich', 'combo', 'nuggets', 'fries', 'kebab', 'qəbab', 'qabab',
      'ресторан', 'кафе', 'обед', 'завтрак',
    ],
    'Grocery': [
      'süd', 'pendir', 'yumurta', 'çörək', 'corek', 'un ', 'düyü', 'duyu',
      'ət', 'et ', 'toyuq', 'balıq', 'balig', 'tərəvəz', 'terevez', 'meyvə', 'meyve',
      'pomidor', 'kartof', 'soğan', 'sogan', 'yag', 'yağ', 'şəkər', 'seker', 'çay', 'cay',
      'qəhvə', 'qehve', 'kolbasa', 'bravo', 'araz', 'bizim', 'poşet', 'poset', 'dəst',
      'dest', 'qida', 'grocery', 'bread', 'milk', 'cheese',
      'meat', 'fruit', 'vegetable', 'rice', 'flour', 'oil', 'sugar', 'tea', 'coffee',
      'xama', 'qaymaq', 'qaymaqlı', 'vafl', 'trubka', 'cola', 'coca', 'paket', 'mehelle',
      'milla', 'findiq', 'kokos', 'cheesecake', 'xrup', 'pshen', 'şokolad', 'shok',
      'tort', 'assorti', 'qozlu', 'krupa', 'vafli', 'продукт', 'молоко', 'хлеб',
    ],
    'Health': [
      'aptek', 'pharmacy', 'dərman', 'derman', 'vitamin', 'health', 'medical', 'tablet',
      'paracetamol', 'məhlul', 'mehlul', 'bandaj', 'meksun', 'otrivin', 'loratadin',
      'ambroksol', 'nurofen', 'ibuprofen', 'aspirin', 'kapsul', 'capsule', 'syrop',
      'syrup', 'mg ', ' n10', ' n20', ' n30', 'аптека', 'лекарств', 'таблет',
    ],
    'Transport': [
      'benzin', 'dizel', 'nafta', 'yanacaq', 'fuel', 'petrol', 'taxi', 'metro', 'bus',
      'бензин', 'транспорт',
    ],
    'Clothing': [
      'geyim', 'ayaqqabı', 'ayaqqabi', 'paltar', 'clothing', 'shirt', 'shoe',
      'одежда', 'обувь',
    ],
    'Utilities': [
      'elektrik', 'su ', 'qaz', 'internet', 'telefon', 'utility', 'azərişıq', 'azerisiq',
      'коммунал', 'электри',
    ],
    'Education': [
      'məktəb', 'mekteb', 'kitab', 'book', 'school', 'university', 'təhsil', 'tehsil',
      'книга', 'школа',
    ],
  };

  static const _storeRules = <String, List<String>>{
    'Health': ['aptek', 'pharmacy', 'dərmanxana', 'dermanxana', 'аптека'],
    'Grocery': [
      'market', 'mağaza', 'magaza', 'bravo', 'məhlə', 'mehlle', 'carrefour', 'a-market',
      'grand mart', 'qida',
    ],
    'Restaurant': ['restoran', 'kafe', 'cafe', 'stolovaya', 'ресторан', 'кафе'],
    'Tobacco': ['tütün', 'tutun', 'tobacco', 'siqaret'],
  };

  /// Score for product-name keyword hits (0 = none).
  static int productMatchScore(String productName) {
    if (productName.trim().isEmpty) return 0;
    final lower = productName.toLowerCase();
    var best = 0;
    for (final keywords in _rules.values) {
      var score = 0;
      for (final kw in keywords) {
        if (_containsKeyword(lower, kw)) score++;
      }
      if (score > best) best = score;
    }
    return best;
  }

  static bool _containsKeyword(String lower, String kw) {
    final k = kw.toLowerCase();
    if (k.trim().isEmpty) return false;
    if (k.endsWith(' ') || k.startsWith(' ')) return lower.contains(k);
    if (k.length <= 3) {
      final re = RegExp(r'(?:^|\s)' + RegExp.escape(k) + r'(?:\s|$|\d)');
      return re.hasMatch(lower);
    }
    return lower.contains(k);
  }

  /// Returns category id whose name best matches [productName], or Other id.
  static String? suggestCategoryId(
    String productName,
    List<Category> categories, {
    String? storeName,
    bool allowStoreFallback = true,
  }) {
    if (categories.isEmpty) return null;

    final trimmed = productName.trim();
    if (trimmed.isEmpty) {
      if (!allowStoreFallback) return otherCategoryId(categories);
      final storeCat = _categoryNameFromStore(storeName);
      if (storeCat != null) {
        return _idForCategoryName(storeCat, categories) ??
            otherCategoryId(categories);
      }
      return otherCategoryId(categories);
    }

    final lower = trimmed.toLowerCase();
    String? bestCatName;
    var bestScore = 0;
    for (final entry in _rules.entries) {
      var score = 0;
      for (final kw in entry.value) {
        if (_containsKeyword(lower, kw)) score++;
      }
      if (score > bestScore) {
        bestScore = score;
        bestCatName = entry.key;
      }
    }

    if (bestCatName != null && bestScore > 0) {
      return _idForCategoryName(bestCatName, categories) ??
          otherCategoryId(categories);
    }

    if (allowStoreFallback) {
      final storeCat = _categoryNameFromStore(storeName);
      if (storeCat != null) {
        return _idForCategoryName(storeCat, categories) ??
            otherCategoryId(categories);
      }
    }

    return otherCategoryId(categories);
  }

  static String? _categoryNameFromStore(String? storeName) {
    if (storeName == null || storeName.trim().isEmpty) return null;
    final lower = storeName.toLowerCase();
    String? best;
    var bestScore = 0;
    for (final entry in _storeRules.entries) {
      var score = 0;
      for (final kw in entry.value) {
        if (lower.contains(kw)) score++;
      }
      if (score > bestScore) {
        bestScore = score;
        best = entry.key;
      }
    }
    return best;
  }

  static String? _idForCategoryName(String name, List<Category> categories) {
    return categories
        .where((c) => c.name.toLowerCase() == name.toLowerCase())
        .map((c) => c.id)
        .firstOrNull;
  }

  static String? otherCategoryId(List<Category> categories) {
    return _idForCategoryName('Other', categories) ??
        categories
            .where((c) => c.name.toLowerCase() == 'other')
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
