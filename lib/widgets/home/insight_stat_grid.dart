import 'package:flutter/material.dart';
import '../../app_state.dart';
import '../../l10n/app_strings.dart';
import '../../models/home_insights.dart';

class InsightStatGrid extends StatelessWidget {
  final HomeInsights insights;

  const InsightStatGrid({super.key, required this.insights});

  @override
  Widget build(BuildContext context) {
    final lang = currentLanguage.value;
    final stats = [
      (
        icon: Icons.receipt_outlined,
        label: AppStrings.get('dash_avg_receipt', lang),
        value: '${insights.avgReceiptAmount.toStringAsFixed(2)} AZN',
        color: const Color(0xFF1B5E20),
      ),
      (
        icon: Icons.storefront_outlined,
        label: AppStrings.get('dash_stores', lang),
        value: '${insights.uniqueStoresThisMonth}',
        color: const Color(0xFF2196F3),
      ),
      (
        icon: Icons.shopping_basket_outlined,
        label: AppStrings.get('dash_items', lang),
        value: '${insights.itemsThisMonth}',
        color: const Color(0xFF808080),
      ),
    ];

    return Row(
      children: [
        for (var i = 0; i < stats.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == stats.length - 1 ? 0 : 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(stats[i].icon, color: stats[i].color, size: 18),
                    const SizedBox(height: 6),
                    Text(
                      stats[i].value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      stats[i].label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.2,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
