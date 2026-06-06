import 'package:flutter/material.dart';
import '../../app_state.dart';
import '../../l10n/app_strings.dart';
import '../../models/home_insights.dart';
import '../../utils/icon_mapper.dart';
import 'home_detail_sheets.dart';
import '../../config/app_colors.dart';
import '../../utils/currency_data.dart';

class TopCategoryInsight extends StatelessWidget {
  final HomeInsights insights;

  const TopCategoryInsight({super.key, required this.insights});

  @override
  Widget build(BuildContext context) {
    final top = insights.topCategory;
    if (top == null || insights.thisMonthTotal <= 0) return const SizedBox.shrink();
    final lang = currentLanguage.value;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => showCategorySheet(
        context,
        category: top,
        items: insights.itemsForCategory(top),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Color(top.color).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(top.color).withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(iconForName(top.icon), color: Color(top.color), size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.get('dash_top_category', lang),
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '${top.name} · ${(top.share * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    formatMoney(top.amount, insights.periodCurrency),
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(top.color),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class CategorySpendList extends StatelessWidget {
  final List<CategorySpend> breakdown;
  final HomeInsights insights;

  const CategorySpendList({
    super.key,
    required this.breakdown,
    required this.insights,
  });

  @override
  Widget build(BuildContext context) {
    if (breakdown.isEmpty) return const SizedBox.shrink();

    return Column(
      children: breakdown.map((c) {
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => showCategorySheet(
            context,
            category: c,
            items: insights.itemsForCategory(c),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              children: [
                Icon(iconForName(c.icon), color: Color(c.color), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              c.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          Text(
                            '${(c.share * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: c.share.clamp(0.05, 1.0),
                          minHeight: 4,
                          backgroundColor: Color(c.color).withValues(alpha: 0.15),
                          color: Color(c.color),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatMoney(c.amount, insights.periodCurrency),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(c.color),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class TopStoresSection extends StatelessWidget {
  final List<StoreSpend> stores;
  final List<StoreSpend> allStores;
  final String? periodCurrency;

  const TopStoresSection({
    super.key,
    required this.stores,
    this.allStores = const [],
    this.periodCurrency,
  });

  @override
  Widget build(BuildContext context) {
    if (stores.isEmpty) return const SizedBox.shrink();
    final lang = currentLanguage.value;
    final fullList = allStores.isNotEmpty ? allStores : stores;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => showStoresSheet(context, fullList),
      child: Column(
        children: [
          ...stores.take(4).map((s) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.green100,
                  child: Text(
                    s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: AppColors.primaryGreen(Theme.of(context).brightness),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                title: Text(
                  s.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  AppStrings.visitCount(s.visitCount, lang),
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: Text(
                  formatMoney(s.amount, periodCurrency),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: AppColors.primaryGreen(Theme.of(context).brightness),
                  ),
                ),
              )),
          if (fullList.length > 4)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                AppStrings.get('see_all', lang),
                style: const TextStyle(
                  color: AppColors.green400,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class MostBoughtInsights extends StatelessWidget {
  final List<ProductSpend> byQuantity;
  final List<ProductSpend> byValue;
  final HomeInsights insights;

  const MostBoughtInsights({
    super.key,
    required this.byQuantity,
    required this.byValue,
    required this.insights,
  });

  @override
  Widget build(BuildContext context) {
    if (byQuantity.isEmpty && byValue.isEmpty) return const SizedBox.shrink();
    final lang = currentLanguage.value;

    return Column(
      children: [
        if (byQuantity.isNotEmpty)
          _QuantityHeroCard(
            product: byQuantity.first,
            lang: lang,
            insights: insights,
            onTap: () => showProductDetailSheet(
              context,
              product: byQuantity.first,
              insights: insights,
              byQuantity: true,
            ),
          ),
        if (byQuantity.isNotEmpty && byValue.isNotEmpty) const SizedBox(height: 10),
        if (byValue.isNotEmpty)
          _ValueHeroCard(
            product: byValue.first,
            lang: lang,
            insights: insights,
            onTap: () => showProductsSheet(
              context,
              title: AppStrings.get('dash_most_by_value', lang),
              products: byValue,
              byQuantity: false,
              insights: insights,
            ),
          ),
      ],
    );
  }
}

class _QuantityHeroCard extends StatelessWidget {
  final ProductSpend product;
  final String lang;
  final HomeInsights insights;
  final VoidCallback onTap;

  const _QuantityHeroCard({
    required this.product,
    required this.lang,
    required this.insights,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final qtyLabel = _fmtQty(product.totalQuantity);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF2196F3).withValues(alpha: 0.18),
              const Color(0xFF2196F3).withValues(alpha: 0.06),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2196F3).withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF2196F3), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.get('dash_most_by_qty', lang),
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    AppStrings.purchaseCount(product.purchaseCount, lang),
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  qtyLabel,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2196F3),
                  ),
                ),
                Text(
                  AppStrings.get('dash_qty_unit', lang),
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmtQty(double q) =>
      q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toStringAsFixed(1);
}

class _ValueHeroCard extends StatelessWidget {
  final ProductSpend product;
  final String lang;
  final HomeInsights insights;
  final VoidCallback onTap;

  const _ValueHeroCard({
    required this.product,
    required this.lang,
    required this.insights,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primaryGreen(Theme.of(context).brightness).withValues(alpha: 0.22),
              AppColors.primaryGreen(Theme.of(context).brightness).withValues(alpha: 0.06),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryGreen(Theme.of(context).brightness).withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen(Theme.of(context).brightness).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.payments_outlined, color: AppColors.primaryGreen(Theme.of(context).brightness), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.get('dash_most_by_value', lang),
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    AppStrings.purchaseCount(product.purchaseCount, lang),
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  product.amount.toStringAsFixed(2),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen(Theme.of(context).brightness),
                  ),
                ),
                Text(
                  'AZN',
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
