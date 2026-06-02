import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_state.dart';
import '../l10n/app_strings.dart';
import '../services/receipt_service.dart';
import '../services/auth_service.dart';
import '../services/budget_service.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../services/category_service.dart';
import '../utils/icon_mapper.dart';
import '../widgets/add_receipt_sheet.dart';
import 'receipts_screen.dart';
import 'restock_screen.dart';
import 'ai_chat_screen.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _tab = 0;
  late final List<Widget> _tabs;
  final _homeTabKey = GlobalKey<_HomeTabState>();

  @override
  void initState() {
    super.initState();
    _tabs = [
      _HomeTab(key: _homeTabKey),
      const ReceiptsScreen(),
      const RestockScreen(),
      const AiChatScreen(),
      const ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: _tabs),
      bottomNavigationBar: ValueListenableBuilder<String>(
        valueListenable: currentLanguage,
        builder: (context2, lang, child2) => NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          backgroundColor: Theme.of(context2).colorScheme.surfaceContainerHighest,
          indicatorColor: const Color(0xFF1B5E20),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined, color: Color(0xFF8888A0)),
              selectedIcon: const Icon(Icons.home, color: Colors.white),
              label: AppStrings.get('nav_home', lang),
            ),
            NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined, color: Color(0xFF8888A0)),
              selectedIcon: const Icon(Icons.receipt_long, color: Colors.white),
              label: AppStrings.get('nav_receipts', lang),
            ),
            NavigationDestination(
              icon: const Icon(Icons.shopping_cart_outlined, color: Color(0xFF8888A0)),
              selectedIcon: const Icon(Icons.shopping_cart, color: Colors.white),
              label: AppStrings.get('nav_restock', lang),
            ),
            NavigationDestination(
              icon: const Icon(Icons.smart_toy_outlined, color: Color(0xFF8888A0)),
              selectedIcon: const Icon(Icons.smart_toy, color: Colors.white),
              label: AppStrings.get('nav_ai', lang),
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline, color: Color(0xFF8888A0)),
              selectedIcon: const Icon(Icons.person, color: Colors.white),
              label: AppStrings.get('nav_profile', lang),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Home Tab ─────────────────────────────────────────────────────────────────

class _HomeTab extends StatefulWidget {
  const _HomeTab({super.key});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  late Future<_HomeData> _future;
  final _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    currentLanguage.addListener(_onLangChange);
    _future = _loadData();
    ReceiptService.deleteOrphanReceipts();
  }

  void _onLangChange() => refresh();

  Future<_HomeData> _loadData() async {
    final personal = await ReceiptService.fetchAll(familyMode: false);
    final family = await ReceiptService.fetchAll(familyMode: true);
    final rows = [...personal, ...family];
    final personalCats =
        await ReceiptService.categoryTotalsForMonth(_now.month, _now.year, familyMode: false);
    final familyCats =
        await ReceiptService.categoryTotalsForMonth(_now.month, _now.year, familyMode: true);
    final categoryTotals = <String, double>{...personalCats};
    familyCats.forEach((k, v) => categoryTotals[k] = (categoryTotals[k] ?? 0) + v);
    final categories = await CategoryService.fetchAll();
    double thisMonth = 0;
    double lastMonth = 0;
    double thisMonthVat = 0;
    int thisMonthCount = 0;

    final Map<String, List<double>> thisPrices = {};
    final Map<String, List<double>> lastPrices = {};

    for (final r in rows) {
      final dateStr = r['purchase_date'] as String?;
      final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
      final total = (r['total_amount'] as num?)?.toDouble() ?? 0.0;
      final vat = (r['vat_amount'] as num?)?.toDouble() ?? 0.0;

      if (date != null) {
        final isThisMonth = date.year == _now.year && date.month == _now.month;
        final isLastMonth = (date.year == _now.year && date.month == _now.month - 1) ||
            (_now.month == 1 && date.year == _now.year - 1 && date.month == 12);

        if (isThisMonth) {
          thisMonth += total;
          thisMonthVat += vat;
          thisMonthCount++;
        } else if (isLastMonth) {
          lastMonth += total;
        }
      }
    }

    // Fetch items for inflation calculation
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        final items = await supabase
            .from('receipt_items')
            .select('name_raw, unit_price, receipts!inner(purchase_date, user_id)')
            .eq('receipts.user_id', userId);
        for (final item in items as List) {
          final name = item['name_raw'] as String? ?? '';
          final price = (item['unit_price'] as num?)?.toDouble() ?? 0;
          final dateStr2 = (item['receipts'] as Map?)?['purchase_date'] as String?;
          final date2 = dateStr2 != null ? DateTime.tryParse(dateStr2) : null;
          if (date2 == null || name.isEmpty) continue;
          final isThisMonth = date2.year == _now.year && date2.month == _now.month;
          final isLastMonth = (date2.year == _now.year && date2.month == _now.month - 1) ||
              (_now.month == 1 && date2.year == _now.year - 1 && date2.month == 12);
          if (isThisMonth) thisPrices.putIfAbsent(name, () => []).add(price);
          if (isLastMonth) lastPrices.putIfAbsent(name, () => []).add(price);
        }
      }
    } catch (_) {}

    // Compute personal inflation %
    double inflationPct = 0;
    int inflationItems = 0;
    for (final name in thisPrices.keys) {
      if (!lastPrices.containsKey(name)) continue;
      final thisAvg = thisPrices[name]!.reduce((a, b) => a + b) / thisPrices[name]!.length;
      final lastAvg = lastPrices[name]!.reduce((a, b) => a + b) / lastPrices[name]!.length;
      if (lastAvg > 0) {
        inflationPct += (thisAvg - lastAvg) / lastAvg * 100;
        inflationItems++;
      }
    }
    if (inflationItems > 0) inflationPct /= inflationItems;

    // Fetch user full_name from users table, fallback to auth metadata
    String? fullName;
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        final userData = await supabase
            .from('users')
            .select('full_name')
            .eq('id', userId)
            .maybeSingle();
        fullName = userData?['full_name'] as String?;
        if (fullName != null && fullName.isEmpty) fullName = null;
      }
    } catch (_) {}
    if (fullName == null) {
      final user = Supabase.instance.client.auth.currentUser;
      fullName = user?.userMetadata?['full_name'] as String? ?? user?.userMetadata?['name'] as String?;
      if (fullName != null && fullName.isEmpty) fullName = null;
    }

    // Load budgets for alerts
    List<Budget> budgets = [];
    try {
      budgets = await BudgetService.fetchForMonth(_now.month, _now.year);
      final spent = await BudgetService.spentByCategory(_now.month, _now.year);
      for (final b in budgets) {
        b.spent = spent[b.categoryId ?? 'uncategorized'] ?? 0;
      }
    } catch (_) {}

    return _HomeData(
      thisMonthTotal: thisMonth,
      lastMonthTotal: lastMonth,
      thisMonthVat: thisMonthVat,
      thisMonthCount: thisMonthCount,
      categoryTotals: categoryTotals,
      categories: categories,
      budgetAlerts: budgets.where((b) => b.usedFraction >= 0.8).toList(),
      inflationPct: inflationItems > 0 ? inflationPct : null,
      fullName: fullName,
    );
  }

  @override
  void dispose() {
    currentLanguage.removeListener(_onLangChange);
    super.dispose();
  }

  void refresh() => setState(() => _future = _loadData());

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    final identity = user?.phone ?? user?.email ?? 'User';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Balanzo', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddReceiptSheet(context, onDone: refresh),
        backgroundColor: const Color(0xFF1B5E20),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          AppStrings.get('add_receipt', currentLanguage.value),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => refresh(),
        child: FutureBuilder<_HomeData>(
          future: _future,
          builder: (context, snapshot) {
            final data = snapshot.data;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
              children: [
                _GreetingCard(identity: identity, data: data),
                const SizedBox(height: 20),

                if (data != null) ...[
                  if (data.inflationPct != null)
                    _InflationPill(inflationPct: data.inflationPct!),

                  const SizedBox(height: 8),
                  _SectionHeader(
                    title: AppStrings.get('categories', currentLanguage.value),
                    subtitle: AppStrings.spentInMonth(
                      DateTime.now().month,
                      DateTime.now().year,
                      currentLanguage.value,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _CategorySpendSection(
                    totals: data.categoryTotals,
                    categories: data.categories,
                  ),

                  if (data.budgetAlerts.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _SectionHeader(
                      title: AppStrings.get('budget_alerts', currentLanguage.value),
                    ),
                    const SizedBox(height: 8),
                    ...data.budgetAlerts.map((b) => _BudgetAlertCard(budget: b)),
                  ],
                ] else if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (snapshot.hasError)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text(
                        AppStrings.get('error_loading_data', currentLanguage.value),
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────────

class _HomeData {
  final double thisMonthTotal;
  final double lastMonthTotal;
  final double thisMonthVat;
  final int thisMonthCount;
  final Map<String, double> categoryTotals;
  final List<Category> categories;
  final List<Budget> budgetAlerts;
  final double? inflationPct;
  final String? fullName;

  _HomeData({
    required this.thisMonthTotal,
    required this.lastMonthTotal,
    required this.thisMonthVat,
    required this.thisMonthCount,
    required this.categoryTotals,
    required this.categories,
    this.budgetAlerts = const [],
    this.inflationPct,
    this.fullName,
  });
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _GreetingCard extends StatelessWidget {
  final String identity;
  final _HomeData? data;
  const _GreetingCard({required this.identity, required this.data});

  String _firstName(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'User';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final lang = currentLanguage.value;
    final rawName = data?.fullName ?? _shortName(identity);
    final firstName = _firstName(rawName.isNotEmpty ? rawName : 'User');
    final diff = (data?.thisMonthTotal ?? 0) - (data?.lastMonthTotal ?? 0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.waving_hand, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppStrings.warmGreeting(firstName, lang),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            data != null
                ? '${data!.thisMonthTotal.toStringAsFixed(2)} AZN'
                : '0.00 AZN',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.spentInMonth(now.month, now.year, lang),
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          if (data != null) ...[
            const SizedBox(height: 10),
            Text(
              AppStrings.receiptsThisMonth(data!.thisMonthCount, lang),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              AppStrings.vsLastMonthDiff(diff, lang),
              style: TextStyle(
                color: diff >= 0 ? Colors.amber.shade100 : Colors.lightGreen.shade100,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _shortName(String s) {
    if (s.contains('@')) return s.split('@').first;
    if (s.startsWith('+')) return s.substring(0, s.length.clamp(0, 10));
    return s;
  }
}

class _InflationPill extends StatelessWidget {
  final double inflationPct;
  const _InflationPill({required this.inflationPct});

  @override
  Widget build(BuildContext context) {
    final isPositive = inflationPct >= 0;
    final color = isPositive ? Colors.red.shade600 : Colors.green.shade600;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isPositive ? Icons.trending_up : Icons.trending_down, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            'Personal inflation: ${isPositive ? '+' : ''}${inflationPct.toStringAsFixed(1)}% this month',
            style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// HIDDEN: VAT tracker disabled — requires government DVX API (Phase 2). Do not delete.
// ignore: unused_element
class _VatAlertBadge extends StatelessWidget {
  final double vatAmount;
  const _VatAlertBadge({required this.vatAmount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade800),
      ),
      child: Row(
        children: [
          Icon(Icons.receipt_long_outlined, color: Colors.orange.shade400, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'VAT this month: ${vatAmount.toStringAsFixed(2)} AZN',
              style: TextStyle(color: Colors.orange.shade400, fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.orange.shade700, size: 18),
        ],
      ),
    );
  }
}

class _CategorySpendSection extends StatelessWidget {
  final Map<String, double> totals;
  final List<Category> categories;

  const _CategorySpendSection({
    required this.totals,
    required this.categories,
  });

  Category? _cat(String id) {
    if (id == '_other') {
      return categories.where((c) => c.name.toLowerCase() == 'other').firstOrNull;
    }
    return categories.where((c) => c.id == id).firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    if (totals.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Text(
          AppStrings.get('scan_to_start', currentLanguage.value),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
      );
    }

    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final max = entries.first.value;

    return Column(
      children: entries.map((e) {
        final cat = _cat(e.key);
        final name = cat?.name ?? 'Other';
        final color = Color(cat?.color ?? 0xFF9E9E9E);
        final fraction = max > 0 ? (e.value / max).clamp(0.08, 1.0) : 1.0;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            children: [
              Icon(iconForName(cat?.icon ?? 'category'), color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: fraction,
                        minHeight: 5,
                        backgroundColor: color.withValues(alpha: 0.15),
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${e.value.toStringAsFixed(2)} AZN',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;
  const _SectionHeader({required this.title, this.subtitle, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
            if (subtitle != null)
              Text(subtitle!, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            child: Text(AppStrings.get('see_all', currentLanguage.value), style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 13)),
          ),
      ],
    );
  }
}

class _BudgetAlertCard extends StatelessWidget {
  final Budget budget;
  const _BudgetAlertCard({required this.budget});

  @override
  Widget build(BuildContext context) {
    final isOver = budget.isOverBudget;
    final color = isOver ? Colors.red.shade700 : Colors.orange.shade700;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(isOver ? Icons.warning_rounded : Icons.info_outline, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isOver
                  ? '${budget.categoryName ?? 'Budget'}: ${(budget.spent - budget.amount).toStringAsFixed(2)} AZN over limit'
                  : '${budget.categoryName ?? 'Budget'}: ${(budget.usedFraction * 100).toInt()}% used',
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
