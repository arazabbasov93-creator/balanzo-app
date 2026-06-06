import 'package:flutter/material.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../services/budget_service.dart';
import '../services/category_service.dart';
import '../config/app_colors.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final now = DateTime.now();
  late Future<_BudgetPageData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_BudgetPageData> _load() async {
    final budgets = await BudgetService.fetchForMonth(now.month, now.year);
    final categories = await CategoryService.fetchAll();
    final spent = await BudgetService.spentByCategory(now.month, now.year);

    // Inject spent amounts into budgets
    for (final b in budgets) {
      final catKey = b.categoryId ?? 'uncategorized';
      b.spent = spent[catKey] ?? 0;
    }

    return _BudgetPageData(budgets: budgets, categories: categories);
  }

  void _refresh() => setState(() => _future = _load());

  Future<void> _addBudget(List<Category> categories) async {
    Category? selected;
    final amountCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Set Budget'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Category>(
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                    .toList(),
                onChanged: (c) => setS(() => selected = c),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Monthly limit (AZN)',
                  border: OutlineInputBorder(),
                  prefixText: '₼ ',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen(
                  Theme.of(context).brightness,
                ),
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    final amount = double.tryParse(amountCtrl.text.trim());
    if (amount == null || amount <= 0) return;

    try {
      await BudgetService.upsert(
        categoryId: selected?.id,
        amount: amount,
        month: now.month,
        year: now.year,
      );
      if (mounted) _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.scaffoldDark : AppColors.scaffoldLight,
      appBar: AppBar(
        title: const Text('Budget', style: TextStyle(fontWeight: FontWeight.bold)),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<_BudgetPageData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _MonthHeader(month: now.month, year: now.year),
                const SizedBox(height: 16),
                if (data.budgets.isEmpty)
                  _EmptyBudgetHint(
                    onAdd: () => _addBudget(data.categories),
                  )
                else ...[
                  ...data.budgets.map(
                    (b) => _BudgetCard(budget: b, onDeleted: _refresh),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _addBudget(data.categories),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Budget'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryGreenDark,
                      side: const BorderSide(color: AppColors.primaryGreenDark),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BudgetPageData {
  final List<Budget> budgets;
  final List<Category> categories;
  _BudgetPageData({required this.budgets, required this.categories});
}

class _MonthHeader extends StatelessWidget {
  final int month;
  final int year;
  const _MonthHeader({required this.month, required this.year});

  @override
  Widget build(BuildContext context) {
    const names = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return Text(
      '${names[month]} $year',
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }
}

class _EmptyBudgetHint extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyBudgetHint({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.green100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.pie_chart_outline, size: 40, color: AppColors.primaryGreenDark),
            ),
            const SizedBox(height: 16),
            const Text('No budgets yet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Set monthly limits per category\nto track your spending.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Set First Budget'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen(
                  Theme.of(context).brightness,
                ),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final Budget budget;
  final VoidCallback onDeleted;
  const _BudgetCard({required this.budget, required this.onDeleted});

  @override
  Widget build(BuildContext context) {
    final pct = (budget.usedFraction * 100).toInt();
    final color = budget.isOverBudget
        ? Colors.red
        : budget.usedFraction > 0.8
            ? Colors.orange
            : AppColors.primaryGreenDark;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    budget.categoryName ?? 'General',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () async {
                    await BudgetService.delete(budget.id);
                    onDeleted();
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: budget.usedFraction,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${budget.spent.toStringAsFixed(2)} / ${budget.amount.toStringAsFixed(2)} AZN',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                Text(
                  '$pct%',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
