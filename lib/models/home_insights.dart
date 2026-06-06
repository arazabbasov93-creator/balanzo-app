import 'category.dart';

class CategorySpend {
  final String key;
  final String name;
  final String icon;
  final int color;
  final double amount;
  final double share; // 0–1 of monthly spend

  const CategorySpend({
    required this.key,
    required this.name,
    required this.icon,
    required this.color,
    required this.amount,
    required this.share,
  });
}

class StoreSpend {
  final String name;
  final double amount;
  final int visitCount;

  const StoreSpend({
    required this.name,
    required this.amount,
    required this.visitCount,
  });
}

class ProductSpend {
  final String name;
  final double amount;
  final int purchaseCount;
  final double totalQuantity;

  const ProductSpend({
    required this.name,
    required this.amount,
    required this.purchaseCount,
    this.totalQuantity = 0,
  });
}

class ProductPurchaseLine {
  final DateTime? date;
  final double quantity;
  final double amount;
  final String store;

  const ProductPurchaseLine({
    this.date,
    required this.quantity,
    required this.amount,
    this.store = '',
  });
}

class ProductPurchaseBreakdown {
  final String name;
  final List<ProductPurchaseLine> thisPeriod;
  final List<ProductPurchaseLine> lastMonth;
  final List<ProductPurchaseLine> lastYearSameMonth;

  const ProductPurchaseBreakdown({
    required this.name,
    required this.thisPeriod,
    required this.lastMonth,
    required this.lastYearSameMonth,
  });

  double get periodQuantity =>
      thisPeriod.fold(0.0, (s, l) => s + l.quantity);

  double get lastMonthQuantity =>
      lastMonth.fold(0.0, (s, l) => s + l.quantity);

  double get lastYearQuantity =>
      lastYearSameMonth.fold(0.0, (s, l) => s + l.quantity);
}

class CategoryItemDetail {
  final String name;
  final double amount;
  final double quantity;

  const CategoryItemDetail({
    required this.name,
    required this.amount,
    required this.quantity,
  });
}

class RecentReceiptSummary {
  final String id;
  final String store;
  final double total;
  final DateTime? date;
  final bool verified;
  final String? fiscalId;

  const RecentReceiptSummary({
    required this.id,
    required this.store,
    required this.total,
    this.date,
    this.verified = false,
    this.fiscalId,
  });
}

class HomeInsights {
  final double thisMonthTotal;
  final double lastMonthTotal;
  final double thisMonthVat;
  final int receiptsThisMonth;
  final int receiptsThisWeek;
  final int itemsThisMonth;
  final int uniqueStoresThisMonth;
  final double avgReceiptAmount;
  final double thisWeekSpend;
  final double lastWeekSpend;
  final double lastYearSameMonthTotal;
  final Map<String, double> categoryTotals;
  final List<CategorySpend> categoryBreakdown;
  final List<Category> categories;
  final List<StoreSpend> topStores;
  final List<StoreSpend> allStores;
  final List<ProductSpend> topProductsByQuantity;
  final List<ProductSpend> topProductsByValue;
  final Map<String, List<CategoryItemDetail>> categoryItems;
  final Map<String, ProductPurchaseBreakdown> productPurchases;
  final ProductSpend? mostFrequentProduct;
  final ProductSpend? topSpendProduct;
  final double? inflationPct;
  final String? fullName;
  final int periodMonth;
  final int periodYear;
  final int totalReceiptsInScope;
  final bool usingFallbackPeriod;
  final bool showWeekComparison;
  final int receiptsLastMonth;
  final bool familyMode;
  final String? periodCurrency;

  const HomeInsights({
    required this.thisMonthTotal,
    required this.lastMonthTotal,
    required this.thisMonthVat,
    required this.receiptsThisMonth,
    required this.receiptsThisWeek,
    required this.itemsThisMonth,
    required this.uniqueStoresThisMonth,
    required this.avgReceiptAmount,
    required this.thisWeekSpend,
    required this.lastWeekSpend,
    this.lastYearSameMonthTotal = 0,
    required this.categoryTotals,
    required this.categoryBreakdown,
    required this.categories,
    required this.topStores,
    this.allStores = const [],
    this.topProductsByQuantity = const [],
    this.topProductsByValue = const [],
    this.categoryItems = const {},
    this.productPurchases = const {},
    this.mostFrequentProduct,
    this.topSpendProduct,
    this.inflationPct,
    this.fullName,
    required this.periodMonth,
    required this.periodYear,
    required this.totalReceiptsInScope,
    this.usingFallbackPeriod = false,
    this.showWeekComparison = true,
    this.receiptsLastMonth = 0,
    this.familyMode = false,
    this.periodCurrency,
  });

  CategorySpend? get topCategory =>
      categoryBreakdown.isEmpty ? null : categoryBreakdown.first;

  bool get hasData => totalReceiptsInScope > 0;

  bool get hasPeriodSpend =>
      receiptsThisMonth > 0 ||
      categoryBreakdown.isNotEmpty ||
      thisMonthTotal > 0;

  /// Resolves drill-down items even when aggregation keys differ slightly.
  List<CategoryItemDetail> itemsForCategory(CategorySpend spend) {
    if (categoryItems.containsKey(spend.key)) {
      return categoryItems[spend.key]!;
    }
    for (final c in categories) {
      if (c.id == spend.key || c.name == spend.name) {
        if (categoryItems.containsKey(c.id)) return categoryItems[c.id]!;
      }
    }
    for (final entry in categoryItems.entries) {
      final cat = categories.where((c) => c.id == entry.key).firstOrNull;
      if (cat != null && cat.name == spend.name) return entry.value;
    }
    return const [];
  }

  ProductPurchaseBreakdown? purchaseBreakdownFor(String productName) {
    if (productPurchases.containsKey(productName)) {
      return productPurchases[productName];
    }
    final lower = productName.toLowerCase();
    for (final e in productPurchases.entries) {
      if (e.key.toLowerCase() == lower) return e.value;
    }
    return null;
  }
}
