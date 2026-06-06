import 'package:flutter/material.dart';
import '../services/supabase_access.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_state.dart';
import '../l10n/app_strings.dart';
import '../services/notification_service.dart';
import '../services/receipt_service.dart';
import '../config/app_colors.dart';

class RestockScreen extends StatefulWidget {
  const RestockScreen({super.key});

  @override
  State<RestockScreen> createState() => _RestockScreenState();
}

class _RestockScreenState extends State<RestockScreen> {
  List<_RestockItem> _items = [];
  bool _loading = true;
  final Set<String> _bought = {};
  final Set<String> _ignored = {};

  @override
  void initState() {
    super.initState();
    currentLanguage.addListener(_onLangChange);
    receiptsRevision.addListener(_onReceiptsChanged);
    _load();
  }

  void _onLangChange() => setState(() {});

  void _onReceiptsChanged() => _load();

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final client = SupabaseAccess.clientOrNull;
      if (client == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        setState(() => _loading = false);
        return;
      }

      final receipts = await ReceiptService.fetchPersonal();
      if (receipts.isEmpty) {
        setState(() {
          _items = [];
          _loading = false;
        });
        return;
      }

      final receiptDates = <String, DateTime>{};
      for (final r in receipts) {
        final id = r['id'] as String?;
        final date = DateTime.tryParse(r['purchase_date']?.toString() ?? '');
        if (id != null && date != null) {
          receiptDates[id] = date;
        }
      }

      final ids = receiptDates.keys.toList();
      final rows = await ReceiptService.fetchItemsForReceipts(
        ids,
        select:
            'name_raw, product_name, quantity, unit_price, total_price, purchase_id',
      );

      final byName = <String, List<_Purchase>>{};
      for (final row in rows) {
        final name = (row['product_name'] as String? ?? row['name_raw'] as String? ?? '')
            .trim();
        if (name.isEmpty) continue;
        final purchaseId = row['purchase_id'] as String?;
        final date = purchaseId != null ? receiptDates[purchaseId] : null;
        if (date == null) continue;
        final qty = (row['quantity'] as num?)?.toDouble() ?? 1;
        final unit = (row['unit_price'] as num?)?.toDouble() ?? 0;
        final total = (row['total_price'] as num?)?.toDouble() ?? 0;
        final unitPrice = unit > 0 ? unit : (qty > 0 ? total / qty : total);
        byName.putIfAbsent(name, () => []).add(
              _Purchase(date: date, quantity: qty, unitPrice: unitPrice),
            );
      }

      final items = <_RestockItem>[];
      final now = DateTime.now();

      for (final entry in byName.entries) {
        if (entry.value.length < 2) continue;
        final purchases = entry.value..sort((a, b) => a.date.compareTo(b.date));

        double totalGap = 0;
        for (int i = 1; i < purchases.length; i++) {
          totalGap += purchases[i].date.difference(purchases[i - 1].date).inDays;
        }
        final avgDays = totalGap / (purchases.length - 1);
        if (avgDays <= 0) continue;

        final last = purchases.last;
        final nextDue = last.date.add(Duration(days: avgDays.round()));
        final daysUntilDue = nextDue.difference(now).inDays;
        final avgQty =
            purchases.fold(0.0, (s, p) => s + p.quantity) / purchases.length;

        items.add(_RestockItem(
          name: entry.key,
          lastBought: last.date,
          avgDays: avgDays.round(),
          nextDue: nextDue,
          daysUntilDue: daysUntilDue,
          purchaseCount: purchases.length,
          avgQuantity: avgQty,
          latestUnitPrice: last.unitPrice,
        ));
      }

      items.sort((a, b) => a.daysUntilDue.compareTo(b.daysUntilDue));

      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });

      final overdue = items.where((i) => i.daysUntilDue < 0).toList();
      if (overdue.isNotEmpty) {
        try {
          await NotificationService.sendRestockReminder(overdue.first.name);
        } catch (e, st) {
          debugPrint('[Restock] notification skipped: $e\n$st');
        }
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading restock data: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _shareWhatsApp() async {
    final due = _activeItems;
    if (due.isEmpty) return;
    final lang = currentLanguage.value;
    final lines = due.map((i) {
      final qty = i.avgQuantity == i.avgQuantity.roundToDouble()
          ? i.avgQuantity.toStringAsFixed(0)
          : i.avgQuantity.toStringAsFixed(1);
      final unit = i.latestUnitPrice.toStringAsFixed(2);
      final line = i.estimatedLineCost.toStringAsFixed(2);
      return '• ${i.name}\n  qty: $qty × $unit AZN = $line AZN';
    }).join('\n');
    final total = due.fold(0.0, (s, i) => s + i.estimatedLineCost);
    final header = AppStrings.get('restock_share_header', lang);
    final totalLabel = AppStrings.get('restock_share_est_total', lang);
    final body = '$header\n$lines\n\n$totalLabel ${total.toStringAsFixed(2)} AZN';
    final msg = Uri.encodeComponent(body);
    final url = Uri.parse('https://wa.me/?text=$msg');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  List<_RestockItem> get _activeItems =>
      _items.where((i) => !_bought.contains(i.name) && !_ignored.contains(i.name)).toList();

  @override
  void dispose() {
    currentLanguage.removeListener(_onLangChange);
    receiptsRevision.removeListener(_onReceiptsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = currentLanguage.value;
    final dueItems = _activeItems;
    final boughtItems = _items.where((i) => _bought.contains(i.name)).toList();
    final ignoredItems = _items.where((i) => _ignored.contains(i.name)).toList();
    final estBudget =
        dueItems.fold(0.0, (s, i) => s + i.estimatedLineCost);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          AppStrings.get('restock', lang),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.onSurface),
            onPressed: _load,
          ),
          if (dueItems.isNotEmpty)
            IconButton(
              icon: Icon(Icons.share, color: Theme.of(context).colorScheme.onSurface),
              tooltip: AppStrings.get('share_shopping_list', lang),
              onPressed: _shareWhatsApp,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : dueItems.isEmpty && boughtItems.isEmpty && ignoredItems.isEmpty
              ? _EmptyState(onRefresh: _load, lang: lang)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (dueItems.isNotEmpty) ...[
                        _SectionHeader(
                          title: AppStrings.get('due_for_restock', lang),
                          subtitle: '${dueItems.length} ${AppStrings.get('restock_items_due', lang)}',
                        ),
                        const SizedBox(height: 8),
                        _BasketCostCard(
                          itemCount: dueItems.length,
                          estBudget: estBudget,
                          lang: lang,
                        ),
                        const SizedBox(height: 12),
                        ...dueItems.map((item) => _RestockCard(
                              item: item,
                              lang: lang,
                              onBought: () => setState(() => _bought.add(item.name)),
                              onIgnore: () => setState(() => _ignored.add(item.name)),
                            )),
                      ],
                      if (boughtItems.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _SectionHeader(
                          title: AppStrings.get('marked_as_bought', lang),
                          subtitle: '${boughtItems.length}',
                          action: TextButton(
                            onPressed: () => setState(() => _bought.clear()),
                            child: Text(
                              AppStrings.get('restock_clear', lang),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...boughtItems.map((item) => _MutedItemRow(item: item, lang: lang)),
                      ],
                      if (ignoredItems.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _SectionHeader(
                          title: AppStrings.get('restock_ignored', lang),
                          subtitle: '${ignoredItems.length}',
                          action: TextButton(
                            onPressed: () => setState(() => _ignored.clear()),
                            child: Text(
                              AppStrings.get('restock_clear', lang),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...ignoredItems.map((item) => _MutedItemRow(item: item, lang: lang)),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _Purchase {
  final DateTime date;
  final double quantity;
  final double unitPrice;
  const _Purchase({
    required this.date,
    required this.quantity,
    required this.unitPrice,
  });
}

class _RestockItem {
  final String name;
  final DateTime lastBought;
  final int avgDays;
  final DateTime nextDue;
  final int daysUntilDue;
  final int purchaseCount;
  final double avgQuantity;
  final double latestUnitPrice;

  _RestockItem({
    required this.name,
    required this.lastBought,
    required this.avgDays,
    required this.nextDue,
    required this.daysUntilDue,
    required this.purchaseCount,
    required this.avgQuantity,
    required this.latestUnitPrice,
  });

  double get estimatedLineCost => latestUnitPrice * avgQuantity;
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  const _SectionHeader({required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        ?action,
      ],
    );
  }
}

class _BasketCostCard extends StatelessWidget {
  final int itemCount;
  final double estBudget;
  final String lang;
  const _BasketCostCard({
    required this.itemCount,
    required this.estBudget,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryGreen(Theme.of(context).brightness),
            AppColors.gradientEnd(Theme.of(context).brightness),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.shopping_basket_outlined, color: Colors.white, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$itemCount ${AppStrings.get('restock_items_due', lang)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  AppStrings.get('restock_tap_hint', lang),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                AppStrings.get('restock_est_budget', lang),
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
              Text(
                '${estBudget.toStringAsFixed(2)} AZN',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RestockCard extends StatelessWidget {
  final _RestockItem item;
  final String lang;
  final VoidCallback onBought;
  final VoidCallback onIgnore;

  const _RestockCard({
    required this.item,
    required this.lang,
    required this.onBought,
    required this.onIgnore,
  });

  String _urgencyText() {
    if (item.daysUntilDue < 0) {
      return '${item.daysUntilDue.abs()} ${AppStrings.get('restock_days_overdue', lang)}';
    }
    if (item.daysUntilDue == 0) {
      return AppStrings.get('restock_due_today', lang);
    }
    return '${AppStrings.get('restock_due_in', lang)} ${item.daysUntilDue} ${AppStrings.get('restock_days', lang)}';
  }

  @override
  Widget build(BuildContext context) {
    final isOverdue = item.daysUntilDue < 0;
    final isDueSoon = item.daysUntilDue >= 0 && item.daysUntilDue <= 3;
    final color = isOverdue
        ? Colors.red.shade600
        : isDueSoon
            ? Colors.orange.shade600
            : Colors.green.shade600;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isOverdue ? Icons.warning_rounded : Icons.shopping_cart_outlined,
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        _urgencyText(),
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${item.estimatedLineCost.toStringAsFixed(2)} AZN',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${AppStrings.get('restock_every', lang)} ${item.avgDays} ${AppStrings.get('restock_days', lang)} · '
              '${AppStrings.get('restock_avg_qty', lang)} ${item.avgQuantity.toStringAsFixed(1)} · '
              '${AppStrings.get('restock_latest_price', lang)} ${item.latestUnitPrice.toStringAsFixed(2)} AZN',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onIgnore,
                  child: Text(AppStrings.get('restock_ignore', lang)),
                ),
                const SizedBox(width: 4),
                FilledButton.tonal(
                  onPressed: onBought,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.green100,
                    foregroundColor: AppColors.primaryGreenDark,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  ),
                  child: Text(
                    AppStrings.get('restock_bought', lang),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MutedItemRow extends StatelessWidget {
  final _RestockItem item;
  final String lang;
  const _MutedItemRow({required this.item, required this.lang});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        item.name,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 14,
          decoration: TextDecoration.lineThrough,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onRefresh;
  final String lang;
  const _EmptyState({required this.onRefresh, this.lang = 'en'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.tintSurfaceDark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.shopping_cart_outlined, size: 44, color: AppColors.primaryGreenDark),
          ),
          const SizedBox(height: 20),
          Text(
            AppStrings.get('no_restock_yet', lang),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              AppStrings.get('restock_scan_hint', lang),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: Text(AppStrings.get('refresh', lang)),
          ),
        ],
      ),
    );
  }
}
