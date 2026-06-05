import '../app_state.dart';
import '../models/category.dart';
import '../models/home_insights.dart';
import 'category_service.dart';
import 'home_insights_service.dart';
import 'receipt_service.dart';

/// Keeps receipt rows + line items in memory so period switches recompute locally.
class HomeDataCache {
  static int _loadedRevision = -1;
  static List<Map<String, dynamic>>? _personalRows;
  static List<Map<String, dynamic>>? _familyRows;
  static List<Map<String, dynamic>>? _personalItems;
  static List<Map<String, dynamic>>? _familyItems;
  static List<Category>? _categories;

  static void invalidate() {
    _loadedRevision = -1;
    _personalRows = null;
    _familyRows = null;
    _personalItems = null;
    _familyItems = null;
    _categories = null;
  }

  static bool get isStale => _loadedRevision != receiptsRevision.value;

  static bool rowsReady(bool familyMode) {
    if (isStale) return false;
    return familyMode ? _familyRows != null : _personalRows != null;
  }

  static bool isScopeReady(bool familyMode) {
    if (isStale) return false;
    final rows = familyMode ? _familyRows : _personalRows;
    final items = familyMode ? _familyItems : _personalItems;
    return rows != null && items != null && _categories != null;
  }

  /// Fast path: receipt headers + categories only (no line items).
  static Future<void> ensureRows(bool familyMode, {bool force = false}) async {
    if (!force && !isStale && rowsReady(familyMode) && _categories != null) {
      return;
    }

    if (force || isStale) {
      invalidate();
      _loadedRevision = receiptsRevision.value;
    }

    _categories ??= await CategoryService.fetchAll();

    if (familyMode) {
      _familyRows ??= await ReceiptService.fetchFamily();
    } else {
      _personalRows ??= await ReceiptService.fetchPersonal();
    }
  }

  static Future<void> ensureItems(bool familyMode) async {
    await ensureRows(familyMode);
    if (familyMode) {
      _familyItems ??= await _loadItems(_familyRows!);
    } else {
      _personalItems ??= await _loadItems(_personalRows!);
    }
  }

  static Future<void> ensureScope(bool familyMode, {bool force = false}) async {
    await ensureRows(familyMode, force: force);
    await ensureItems(familyMode);
  }

  static Future<List<Map<String, dynamic>>> _loadItems(
    List<Map<String, dynamic>> rows,
  ) async {
    final ids = rows
        .map((r) => r['id'] as String?)
        .whereType<String>()
        .toList();
    if (ids.isEmpty) return [];

    var items = await ReceiptService.fetchItemsEmbedded(ids);
    if (items.isNotEmpty) return items;

    items = await ReceiptService.fetchItemsForReceipts(ids);
    if (items.isNotEmpty) return items;

    return ReceiptService.fetchItemsForReceipts(
      ids,
      select:
          'category_id, category, total_price, quantity, unit_price, name_raw, product_name, purchase_id',
    );
  }

  static HomeInsights? tryInstant({
    required int periodMonth,
    required int periodYear,
    required bool familyMode,
    required String locale,
    String? fullName,
    bool rowsOnly = false,
  }) {
    if (!rowsReady(familyMode) || _categories == null) return null;
    if (!rowsOnly && !isScopeReady(familyMode)) return null;
    final rows = familyMode ? _familyRows! : _personalRows!;
    final items = rowsOnly
        ? const <Map<String, dynamic>>[]
        : (familyMode ? _familyItems! : _personalItems!);
    return HomeInsightsService.buildFromCache(
      rows: rows,
      allItems: items,
      categories: _categories!,
      periodMonth: periodMonth,
      periodYear: periodYear,
      locale: locale,
      fullName: fullName,
      familyMode: familyMode,
      usingFallbackPeriod: _usingFallback(rows, periodMonth, periodYear),
    );
  }

  static bool _usingFallback(
    List<Map<String, dynamic>> rows,
    int periodMonth,
    int periodYear,
  ) {
    final resolved =
        HomeInsightsService.resolveAnalysisPeriod(rows, DateTime.now());
    return resolved.fallback &&
        periodMonth == resolved.month &&
        periodYear == resolved.year;
  }

  static Future<HomeInsights> loadInsights({
    required int periodMonth,
    required int periodYear,
    required bool familyMode,
    required String locale,
    String? fullName,
    bool force = false,
  }) async {
    await ensureScope(familyMode, force: force);
    final rows = familyMode ? _familyRows! : _personalRows!;
    final items = familyMode ? _familyItems! : _personalItems!;
    return HomeInsightsService.buildFromCache(
      rows: rows,
      allItems: items,
      categories: _categories!,
      periodMonth: periodMonth,
      periodYear: periodYear,
      locale: locale,
      fullName: fullName,
      familyMode: familyMode,
      usingFallbackPeriod: _usingFallback(rows, periodMonth, periodYear),
    );
  }

  static List<Map<String, dynamic>>? rowsFor(bool familyMode) =>
      familyMode ? _familyRows : _personalRows;
}
