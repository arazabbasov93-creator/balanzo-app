import '../models/category.dart';
import '../models/home_insights.dart';
import 'category_service.dart';
import 'receipt_service.dart';
import 'user_profile_service.dart';
import '../l10n/app_strings.dart';

class HomeInsightsService {
  static ({int month, int year, bool fallback}) resolveAnalysisPeriod(
    List<Map<String, dynamic>> rows,
    DateTime asOf,
  ) {
    bool hasInMonth(int m, int y) {
      for (final r in rows) {
        final date = _parseDate(r['purchase_date']);
        if (date != null && date.year == y && date.month == m) return true;
      }
      return false;
    }

    if (hasInMonth(asOf.month, asOf.year)) {
      return (month: asOf.month, year: asOf.year, fallback: false);
    }

    DateTime? latest;
    for (final r in rows) {
      final date = _parseDate(r['purchase_date']);
      if (date == null) continue;
      final monthStart = DateTime(date.year, date.month);
      if (latest == null || monthStart.isAfter(latest)) latest = monthStart;
    }
    if (latest != null) {
      return (
        month: latest.month,
        year: latest.year,
        fallback: latest.month != asOf.month || latest.year != asOf.year,
      );
    }
    return (month: asOf.month, year: asOf.year, fallback: false);
  }

  static DateTime? _parseDate(Object? raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

  static Future<HomeInsights> load({
    required int periodMonth,
    required int periodYear,
    bool familyMode = false,
    String locale = 'en',
  }) async {
    final rows = familyMode
        ? await ReceiptService.fetchFamily()
        : await ReceiptService.fetchPersonal();
    final categories = await CategoryService.fetchAll();
    final resolved = resolveAnalysisPeriod(
      rows,
      DateTime(periodYear, periodMonth),
    );
    final usingFallback = resolved.fallback;
    final periodReceiptIds = _periodReceiptIds(rows, periodMonth, periodYear);
    final periodItems = await _fetchPeriodItems(periodReceiptIds);
    final fullName = await UserProfileService.loadFullName(refreshCache: false);
    return buildFromCache(
      rows: rows,
      allItems: periodItems,
      categories: categories,
      periodMonth: periodMonth,
      periodYear: periodYear,
      locale: locale,
      fullName: fullName,
      itemsScopedToPeriod: true,
      familyMode: familyMode,
      usingFallbackPeriod: usingFallback,
    );
  }

  static List<String> _periodReceiptIds(
    List<Map<String, dynamic>> rows,
    int periodMonth,
    int periodYear,
  ) {
    final ids = <String>[];
    for (final r in rows) {
      final date = _parseDate(r['purchase_date']);
      if (date == null) continue;
      if (date.year == periodYear && date.month == periodMonth) {
        final id = r['id'] as String?;
        if (id != null) ids.add(id);
      }
    }
    return ids;
  }

  /// Builds insights from data already in memory (no network).
  static HomeInsights buildFromCache({
    required List<Map<String, dynamic>> rows,
    required List<Map<String, dynamic>> allItems,
    required List<Category> categories,
    required int periodMonth,
    required int periodYear,
    required String locale,
    String? fullName,
    bool itemsScopedToPeriod = false,
    bool familyMode = false,
    bool usingFallbackPeriod = false,
  }) {
    final now = DateTime.now();
    final showWeekComparison =
        periodYear == now.year && periodMonth == now.month;

    double periodTotal = 0;
    double prevPeriodTotal = 0;
    double periodVat = 0;
    int receiptsInPeriod = 0;
    int receiptsLastMonth = 0;
    int receiptsThisWeek = 0;
    final storeTotals = <String, double>{};
    final storeVisits = <String, int>{};
    final periodReceiptIds = <String>[];
    final storeByReceiptId = <String, String>{};

    final prevMonth = periodMonth == 1 ? 12 : periodMonth - 1;
    final prevYear = periodMonth == 1 ? periodYear - 1 : periodYear;
    final lastYearMonth = periodYear - 1;

    final weekAnchor = showWeekComparison
        ? now
        : DateTime(periodYear, periodMonth, 1);
    final thisWeekStart = weekAnchor.subtract(
      Duration(days: weekAnchor.weekday - 1),
    );
    final thisWeekStartDate =
        DateTime(thisWeekStart.year, thisWeekStart.month, thisWeekStart.day);
    final lastWeekStartDate = thisWeekStartDate.subtract(const Duration(days: 7));
    final lastWeekEndDate = thisWeekStartDate.subtract(const Duration(days: 1));
    double thisWeekSpend = 0;
    double lastWeekSpend = 0;
    double lastYearSameMonthTotal = 0;
    final receiptDates = <String, DateTime>{};
    final receiptStores = <String, String>{};

    for (final r in rows) {
      final date = _parseDate(r['purchase_date']);
      final total = (r['total_amount'] as num?)?.toDouble() ?? 0.0;
      final vat = (r['vat_amount'] as num?)?.toDouble() ?? 0.0;
      final store = (r['store_name'] as String? ?? 'Unknown').trim();
      final id = r['id'] as String?;

      if (date != null) {
        if (id != null) {
          receiptDates[id] = date;
          receiptStores[id] = store;
        }
        final inPeriod =
            date.year == periodYear && date.month == periodMonth;
        final inPrevPeriod =
            date.year == prevYear && date.month == prevMonth;
        final inLastYearSameMonth =
            date.year == lastYearMonth && date.month == periodMonth;
        final day = DateTime(date.year, date.month, date.day);

        if (inPeriod) {
          periodTotal += total;
          periodVat += vat;
          receiptsInPeriod++;
          storeTotals[store] = (storeTotals[store] ?? 0) + total;
          storeVisits[store] = (storeVisits[store] ?? 0) + 1;
          if (id != null) {
            periodReceiptIds.add(id);
            storeByReceiptId[id] = store;
          }
        } else if (inPrevPeriod) {
          prevPeriodTotal += total;
          receiptsLastMonth++;
        }

        if (inLastYearSameMonth) {
          lastYearSameMonthTotal += total;
        }

        if (showWeekComparison && inPeriod) {
          if (!day.isBefore(thisWeekStartDate)) {
            receiptsThisWeek++;
            thisWeekSpend += total;
          } else if (!day.isBefore(lastWeekStartDate) &&
              !day.isAfter(lastWeekEndDate)) {
            lastWeekSpend += total;
          }
        }
      }
    }

    final periodIdSet = periodReceiptIds.toSet();
    final periodItems = itemsScopedToPeriod
        ? allItems
        : allItems
            .where((item) {
              final purchaseId = item['purchase_id'] as String?;
              return purchaseId != null && periodIdSet.contains(purchaseId);
            })
            .toList();

    var categoryTotals = _aggregateCategoryTotalsFromItems(
      periodItems,
      categories,
      storeByReceiptId,
    );
    final categoryItems = ReceiptService.categoryItemsForReceiptIds(
      periodItems,
      categories,
      storeByReceiptId: storeByReceiptId,
    );

    final topStores = storeTotals.entries
        .map((e) => StoreSpend(
              name: e.key,
              amount: e.value,
              visitCount: storeVisits[e.key] ?? 0,
            ))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    final productStats = _aggregateProductStats(periodItems);
    final productPurchases = allItems.isEmpty
        ? const <String, ProductPurchaseBreakdown>{}
        : _aggregateProductPurchases(
            allItems,
            receiptDates,
            receiptStores,
            periodMonth: periodMonth,
            periodYear: periodYear,
            prevMonth: prevMonth,
            prevYear: prevYear,
            lastYearMonth: lastYearMonth,
          );
    final inflationPct = _inflationFromCache(
      rows,
      allItems,
      DateTime(periodYear, periodMonth),
    );

    final breakdown = _buildCategoryBreakdown(
      categoryTotals,
      categories,
      periodTotal,
      locale,
    );

    return HomeInsights(
      thisMonthTotal: periodTotal,
      lastMonthTotal: prevPeriodTotal,
      thisMonthVat: periodVat,
      receiptsThisMonth: receiptsInPeriod,
      receiptsThisWeek: receiptsThisWeek,
      itemsThisMonth: periodItems.length,
      uniqueStoresThisMonth: storeTotals.length,
      avgReceiptAmount:
          receiptsInPeriod > 0 ? periodTotal / receiptsInPeriod : 0,
      thisWeekSpend: thisWeekSpend,
      lastWeekSpend: lastWeekSpend,
      lastYearSameMonthTotal: lastYearSameMonthTotal,
      categoryTotals: categoryTotals,
      categoryBreakdown: breakdown,
      categories: categories,
      topStores: topStores.take(5).toList(),
      allStores: topStores,
      topProductsByQuantity: productStats.byQuantity,
      topProductsByValue: productStats.byValue,
      categoryItems: categoryItems,
      productPurchases: productPurchases,
      mostFrequentProduct: productStats.byQuantity.isNotEmpty
          ? productStats.byQuantity.first
          : null,
      topSpendProduct: productStats.byValue.isNotEmpty
          ? productStats.byValue.first
          : null,
      inflationPct: inflationPct,
      fullName: fullName,
      periodMonth: periodMonth,
      periodYear: periodYear,
      totalReceiptsInScope: rows.length,
      usingFallbackPeriod: usingFallbackPeriod,
      showWeekComparison: showWeekComparison,
      receiptsLastMonth: receiptsLastMonth,
      familyMode: familyMode,
    );
  }

  static double? _inflationFromCache(
    List<Map<String, dynamic>> rows,
    List<Map<String, dynamic>> items,
    DateTime period,
  ) {
    try {
      if (rows.isEmpty) return null;

      final receiptDates = <String, DateTime>{};
      for (final r in rows) {
        final id = r['id'] as String?;
        final date = _parseDate(r['purchase_date']);
        if (id != null && date != null) receiptDates[id] = date;
      }

      final thisPrices = <String, List<double>>{};
      final lastPrices = <String, List<double>>{};

      for (final item in items) {
        final name = item['name_raw'] as String? ?? '';
        final price = (item['unit_price'] as num?)?.toDouble() ?? 0;
        final purchaseId = item['purchase_id'] as String?;
        final date = purchaseId != null ? receiptDates[purchaseId] : null;
        if (date == null || name.isEmpty || price <= 0) continue;

        final isThisMonth =
            date.year == period.year && date.month == period.month;
        final isLastMonth =
            (date.year == period.year && date.month == period.month - 1) ||
                (period.month == 1 &&
                    date.year == period.year - 1 &&
                    date.month == 12);
        if (isThisMonth) thisPrices.putIfAbsent(name, () => []).add(price);
        if (isLastMonth) lastPrices.putIfAbsent(name, () => []).add(price);
      }

      double inflationPct = 0;
      var count = 0;
      for (final name in thisPrices.keys) {
        if (!lastPrices.containsKey(name)) continue;
        final thisAvg =
            thisPrices[name]!.reduce((a, b) => a + b) / thisPrices[name]!.length;
        final lastAvg =
            lastPrices[name]!.reduce((a, b) => a + b) / lastPrices[name]!.length;
        if (lastAvg > 0) {
          inflationPct += (thisAvg - lastAvg) / lastAvg * 100;
          count++;
        }
      }
      return count > 0 ? inflationPct / count : null;
    } catch (_) {
      return null;
    }
  }

  static List<CategorySpend> _buildCategoryBreakdown(
    Map<String, double> totals,
    List<Category> categories,
    double monthTotal,
    String locale,
  ) {
    Category? cat(String key) {
      if (key == '_other') {
        return categories
            .where((c) => c.name.toLowerCase() == 'other')
            .firstOrNull;
      }
      final byId = categories.where((c) => c.id == key).firstOrNull;
      if (byId != null) return byId;
      return categories
          .where((c) => c.name.toLowerCase() == key.toLowerCase())
          .firstOrNull;
    }

    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final itemSum = entries.fold(0.0, (s, e) => s + e.value);
    final denom = itemSum > 0 ? itemSum : monthTotal;

    return entries.map((e) {
      final c = cat(e.key);
      final rawName = c?.name ?? (e.key == '_other' ? 'Other' : e.key);
      return CategorySpend(
        key: e.key,
        name: AppStrings.categoryName(rawName, locale),
        icon: c?.icon ?? 'category',
        color: c?.color ?? 0xFF9E9E9E,
        amount: e.value,
        share: denom > 0 ? e.value / denom : 0,
      );
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> _fetchPeriodItems(
    List<String> receiptIds,
  ) async {
    if (receiptIds.isEmpty) return [];
    try {
      final embedded = await ReceiptService.fetchItemsEmbedded(receiptIds);
      if (embedded.isNotEmpty) return embedded;

      var items = await ReceiptService.fetchItemsForReceipts(receiptIds);
      if (items.isNotEmpty) return items;
      items = await ReceiptService.fetchItemsForReceipts(
        receiptIds,
        select:
            'category_id, category, total_price, quantity, unit_price, name_raw, product_name, purchase_id',
      );
      return items;
    } catch (_) {
      return [];
    }
  }

  static Map<String, double> _aggregateCategoryTotalsFromItems(
    List<Map<String, dynamic>> items,
    List<Category> categories,
    Map<String, String> storeByReceiptId,
  ) {
    final totals = <String, double>{};
    for (final item in items) {
      final price = ReceiptService.itemLineTotal(item);
      if (price <= 0) continue;
      final purchaseId = item['purchase_id'] as String?;
      final store =
          purchaseId != null ? storeByReceiptId[purchaseId] : null;
      final key = ReceiptService.categoryKeyForItem(
        item,
        categories,
        storeName: store,
      );
      totals[key] = (totals[key] ?? 0) + price;
    }
    return totals;
  }

  static ({List<ProductSpend> byQuantity, List<ProductSpend> byValue})
      _aggregateProductStats(List<Map<String, dynamic>> items) {
    final totals = <String, double>{};
    final counts = <String, int>{};
    final qtySums = <String, double>{};
    for (final item in items) {
      final name = (item['product_name'] as String? ??
              item['name_raw'] as String? ??
              '')
          .trim();
      if (name.isEmpty) continue;
      final qty = (item['quantity'] as num?)?.toDouble() ?? 1;
      final price = ReceiptService.itemLineTotal(item);
      qtySums[name] = (qtySums[name] ?? 0) + qty;
      counts[name] = (counts[name] ?? 0) + 1;
      if (price > 0) totals[name] = (totals[name] ?? 0) + price;
    }
    if (qtySums.isEmpty) {
      return (byQuantity: <ProductSpend>[], byValue: <ProductSpend>[]);
    }

    ProductSpend build(String name) => ProductSpend(
          name: name,
          amount: totals[name] ?? 0,
          purchaseCount: counts[name] ?? 0,
          totalQuantity: qtySums[name] ?? 0,
        );

    final byQuantity = qtySums.keys.map(build).toList()
      ..sort((a, b) {
        final q = b.totalQuantity.compareTo(a.totalQuantity);
        if (q != 0) return q;
        return b.purchaseCount.compareTo(a.purchaseCount);
      });

    final byValue = totals.entries
        .map((e) => build(e.key))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    return (
      byQuantity: byQuantity.take(10).toList(),
      byValue: byValue.take(10).toList(),
    );
  }

  static Map<String, ProductPurchaseBreakdown> _aggregateProductPurchases(
    List<Map<String, dynamic>> items,
    Map<String, DateTime> receiptDates,
    Map<String, String> receiptStores, {
    required int periodMonth,
    required int periodYear,
    required int prevMonth,
    required int prevYear,
    required int lastYearMonth,
  }) {
    bool inPeriod(DateTime d) =>
        d.year == periodYear && d.month == periodMonth;
    bool inPrev(DateTime d) => d.year == prevYear && d.month == prevMonth;
    bool inLastYear(DateTime d) =>
        d.year == lastYearMonth && d.month == periodMonth;

    final thisPeriod = <String, List<ProductPurchaseLine>>{};
    final lastMonth = <String, List<ProductPurchaseLine>>{};
    final lastYear = <String, List<ProductPurchaseLine>>{};

    void addLine(
      Map<String, List<ProductPurchaseLine>> bucket,
      String name,
      ProductPurchaseLine line,
    ) {
      bucket.putIfAbsent(name, () => []).add(line);
    }

    for (final item in items) {
      final name = (item['product_name'] as String? ??
              item['name_raw'] as String? ??
              '')
          .trim();
      if (name.isEmpty) continue;
      final purchaseId = item['purchase_id'] as String?;
      final date = purchaseId != null ? receiptDates[purchaseId] : null;
      if (date == null) continue;
      final qty = (item['quantity'] as num?)?.toDouble() ?? 1;
      final amount = ReceiptService.itemLineTotal(item);
      final store = purchaseId != null
          ? (receiptStores[purchaseId] ?? '')
          : '';
      final line = ProductPurchaseLine(
        date: date,
        quantity: qty,
        amount: amount,
        store: store,
      );
      if (inPeriod(date)) {
        addLine(thisPeriod, name, line);
      } else if (inPrev(date)) {
        addLine(lastMonth, name, line);
      } else if (inLastYear(date)) {
        addLine(lastYear, name, line);
      }
    }

    final names = {
      ...thisPeriod.keys,
      ...lastMonth.keys,
      ...lastYear.keys,
    };
    return {
      for (final name in names)
        name: ProductPurchaseBreakdown(
          name: name,
          thisPeriod: thisPeriod[name] ?? const [],
          lastMonth: lastMonth[name] ?? const [],
          lastYearSameMonth: lastYear[name] ?? const [],
        ),
    };
  }
}
