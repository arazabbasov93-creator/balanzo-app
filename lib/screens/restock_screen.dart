import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_state.dart';
import '../l10n/app_strings.dart';
import '../services/notification_service.dart';

class RestockScreen extends StatefulWidget {
  const RestockScreen({super.key});

  @override
  State<RestockScreen> createState() => _RestockScreenState();
}

class _RestockScreenState extends State<RestockScreen> {
  List<_RestockItem> _items = [];
  bool _loading = true;
  final Set<String> _bought = {};

  @override
  void initState() {
    super.initState();
    currentLanguage.addListener(_onLangChange);
    _load();
  }

  void _onLangChange() => setState(() {});

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        setState(() => _loading = false);
        return;
      }

      // Fetch all receipt items with their receipt dates
      final rows = await client
          .from('receipt_items')
          .select('name_raw, total_price, receipts!inner(purchase_date, user_id)')
          .eq('receipts.user_id', userId)
          .order('name_raw');

      // Group by item name and compute purchase frequency
      final Map<String, List<DateTime>> byName = {};
      for (final row in rows as List) {
        final name = (row['name_raw'] as String? ?? '').trim();
        if (name.isEmpty) continue;
        final dateStr = (row['receipts'] as Map?)?['purchase_date'] as String?;
        if (dateStr == null) continue;
        final date = DateTime.tryParse(dateStr);
        if (date == null) continue;
        byName.putIfAbsent(name, () => []).add(date);
      }

      final items = <_RestockItem>[];
      final now = DateTime.now();

      for (final entry in byName.entries) {
        if (entry.value.length < 2) continue;
        final dates = entry.value..sort();
        // Average gap between purchases in days
        double totalGap = 0;
        for (int i = 1; i < dates.length; i++) {
          totalGap += dates[i].difference(dates[i - 1]).inDays;
        }
        final avgDays = totalGap / (dates.length - 1);
        if (avgDays <= 0) continue;

        final lastBought = dates.last;
        final nextDue = lastBought.add(Duration(days: avgDays.round()));
        final daysUntilDue = nextDue.difference(now).inDays;

        items.add(_RestockItem(
          name: entry.key,
          lastBought: lastBought,
          avgDays: avgDays.round(),
          nextDue: nextDue,
          daysUntilDue: daysUntilDue,
          purchaseCount: entry.value.length,
        ));
      }

      // Sort: overdue first, then soonest due
      items.sort((a, b) => a.daysUntilDue.compareTo(b.daysUntilDue));

      setState(() {
        _items = items;
        _loading = false;
      });

      // Send notification for items overdue
      final overdue = items.where((i) => i.daysUntilDue < 0).toList();
      if (overdue.isNotEmpty) {
        await NotificationService.sendRestockReminder(overdue.first.name);
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading restock data: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _shareWhatsApp() async {
    final due = _items.where((i) => !_bought.contains(i.name) && i.daysUntilDue <= 3).toList();
    if (due.isEmpty) return;
    final list = due.map((i) => '• ${i.name}').join('\n');
    final msg = Uri.encodeComponent('Shopping List (Balanzo):\n$list');
    final url = Uri.parse('https://wa.me/?text=$msg');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    currentLanguage.removeListener(_onLangChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = currentLanguage.value;
    final dueItems = _items.where((i) => !_bought.contains(i.name)).toList();
    final boughtItems = _items.where((i) => _bought.contains(i.name)).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(AppStrings.get('restock', lang), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
          if (dueItems.any((i) => i.daysUntilDue <= 3))
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Share shopping list',
              onPressed: _shareWhatsApp,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : dueItems.isEmpty && boughtItems.isEmpty
              ? _EmptyState(onRefresh: _load, lang: lang)
              : RefreshIndicator(
                  onRefresh: () => _load(),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (dueItems.isNotEmpty) ...[
                        _SectionHeader(
                          title: AppStrings.get('due_for_restock', lang),
                          subtitle: '${dueItems.length} items',
                        ),
                        const SizedBox(height: 8),
                        // Estimated basket cost
                        _BasketCostCard(items: dueItems.take(5).toList()),
                        const SizedBox(height: 12),
                        ...dueItems.map((item) => _RestockCard(
                              item: item,
                              onBought: () => setState(() => _bought.add(item.name)),
                            )),
                      ],
                      if (boughtItems.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _SectionHeader(
                          title: AppStrings.get('marked_as_bought', lang),
                          subtitle: '${boughtItems.length} items',
                          action: TextButton(
                            onPressed: () => setState(() => _bought.clear()),
                            child: const Text('Clear', style: TextStyle(color: Color(0xFF8888A0))),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...boughtItems.map((item) => _BoughtCard(item: item)),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _RestockItem {
  final String name;
  final DateTime lastBought;
  final int avgDays;
  final DateTime nextDue;
  final int daysUntilDue;
  final int purchaseCount;

  _RestockItem({
    required this.name,
    required this.lastBought,
    required this.avgDays,
    required this.nextDue,
    required this.daysUntilDue,
    required this.purchaseCount,
  });
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
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFF2F2F5))),
              if (subtitle != null)
                Text(subtitle!, style: const TextStyle(fontSize: 12, color: Color(0xFF8888A0))),
            ],
          ),
        ),
        ?action,
      ],
    );
  }
}

class _BasketCostCard extends StatelessWidget {
  final List<_RestockItem> items;
  const _BasketCostCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.shopping_basket_outlined, color: Colors.white, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${min(items.length, 5)} items due for restock',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Tap items to mark as bought',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RestockCard extends StatelessWidget {
  final _RestockItem item;
  final VoidCallback onBought;
  const _RestockCard({required this.item, required this.onBought});

  @override
  Widget build(BuildContext context) {
    final isOverdue = item.daysUntilDue < 0;
    final isDueSoon = item.daysUntilDue >= 0 && item.daysUntilDue <= 3;
    final color = isOverdue
        ? Colors.red.shade600
        : isDueSoon
            ? Colors.orange.shade600
            : Colors.green.shade600;

    String urgencyText;
    if (isOverdue) {
      urgencyText = '${item.daysUntilDue.abs()} days overdue';
    } else if (item.daysUntilDue == 0) {
      urgencyText = 'Due today';
    } else {
      urgencyText = 'Due in ${item.daysUntilDue} days';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF18181C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isOverdue ? Icons.warning_rounded : Icons.shopping_cart_outlined,
            color: color,
            size: 22,
          ),
        ),
        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(urgencyText, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
            Text(
              'Every ${item.avgDays} days  •  ${item.purchaseCount}x bought',
              style: const TextStyle(color: Color(0xFF8888A0), fontSize: 11),
            ),
          ],
        ),
        trailing: TextButton(
          onPressed: onBought,
          style: TextButton.styleFrom(
            backgroundColor: const Color(0xFFE8F5E9),
            foregroundColor: const Color(0xFF1B5E20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
          child: const Text('Bought', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

class _BoughtCard extends StatelessWidget {
  final _RestockItem item;
  const _BoughtCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF18181C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF1B5E20), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(item.name, style: const TextStyle(color: Color(0xFF8888A0), fontSize: 14, decoration: TextDecoration.lineThrough, decorationColor: Color(0xFF8888A0))),
          ),
        ],
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
              color: const Color(0xFF1E2F1E),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.shopping_cart_outlined, size: 44, color: Color(0xFF1B5E20)),
          ),
          const SizedBox(height: 20),
          Text(AppStrings.get('no_restock_yet', lang), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFF2F2F5))),
          const SizedBox(height: 8),
          Text(
            AppStrings.get('restock_scan_hint', lang),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Color(0xFF8888A0)),
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
