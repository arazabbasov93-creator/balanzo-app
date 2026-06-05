import 'package:flutter/material.dart';
import '../../app_state.dart';
import '../../l10n/app_strings.dart';
import '../../models/home_insights.dart';

void showStoresSheet(BuildContext context, List<StoreSpend> stores) {
  if (stores.isEmpty) return;
  final lang = currentLanguage.value;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (_, scroll) => _SheetScaffold(
        title: AppStrings.get('dash_top_stores', lang),
        subtitle: '${stores.length} ${AppStrings.get('dash_stores', lang).toLowerCase()}',
        scrollController: scroll,
        children: stores
            .map((s) => _StoreRow(store: s, lang: lang))
            .toList(),
      ),
    ),
  );
}

void showProductsSheet(
  BuildContext context, {
  required String title,
  required List<ProductSpend> products,
  required bool byQuantity,
  HomeInsights? insights,
}) {
  if (products.isEmpty) return;
  final lang = currentLanguage.value;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (_, scroll) => _SheetScaffold(
        title: title,
        subtitle: AppStrings.get('dash_tap_for_details', lang),
        scrollController: scroll,
        children: products
            .asMap()
            .entries
            .map((e) => _ProductRow(
                  rank: e.key + 1,
                  product: e.value,
                  byQuantity: byQuantity,
                  lang: lang,
                  onTap: insights != null
                      ? () {
                          Navigator.pop(ctx);
                          showProductDetailSheet(
                            context,
                            product: e.value,
                            insights: insights,
                            byQuantity: byQuantity,
                          );
                        }
                      : null,
                ))
            .toList(),
      ),
    ),
  );
}

void showProductDetailSheet(
  BuildContext context, {
  required ProductSpend product,
  required HomeInsights insights,
  required bool byQuantity,
}) {
  final lang = currentLanguage.value;
  final breakdown = insights.purchaseBreakdownFor(product.name);
  if (breakdown == null || breakdown.thisPeriod.isEmpty) return;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (_, scroll) {
        final buys = _groupPurchaseLines(breakdown.thisPeriod);
        final children = <Widget>[
          _ProductSummaryHeader(
            product: product,
            breakdown: breakdown,
            byQuantity: byQuantity,
            lang: lang,
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.productBuysThisPeriod(buys.length, breakdown.periodQuantity, lang),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(ctx).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          ...buys.map((b) => _ProductBuyRow(buy: b, lang: lang, byQuantity: byQuantity)),
        ];

        if (breakdown.lastMonth.isNotEmpty) {
          children.addAll([
            const SizedBox(height: 16),
            Text(
              AppStrings.get('dash_vs_last_month', lang),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Theme.of(ctx).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppStrings.productPeriodSummary(
                _groupPurchaseLines(breakdown.lastMonth).length,
                breakdown.lastMonthQuantity,
                lang,
              ),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
          ]);
        }

        if (breakdown.lastYearSameMonth.isNotEmpty) {
          children.addAll([
            const SizedBox(height: 12),
            Text(
              AppStrings.get('dash_vs_last_year', lang),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Theme.of(ctx).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppStrings.productPeriodSummary(
                _groupPurchaseLines(breakdown.lastYearSameMonth).length,
                breakdown.lastYearQuantity,
                lang,
              ),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
          ]);
        }

        return _SheetScaffold(
          title: product.name,
          subtitle: byQuantity
              ? '${_fmtQty(product.totalQuantity)} ${AppStrings.get('dash_qty_unit', lang)}'
              : '${product.amount.toStringAsFixed(2)} AZN',
          scrollController: scroll,
          children: children,
        );
      },
    ),
  );
}

class _ProductBuyGroup {
  final DateTime? date;
  final String store;
  final double quantity;
  final double amount;

  const _ProductBuyGroup({
    this.date,
    this.store = '',
    required this.quantity,
    required this.amount,
  });
}

List<_ProductBuyGroup> _groupPurchaseLines(List<ProductPurchaseLine> lines) {
  final map = <String, _ProductBuyGroup>{};
  for (final line in lines) {
    final day = line.date;
    final key = '${day?.toIso8601String().substring(0, 10) ?? '?'}|${line.store}';
    final existing = map[key];
    if (existing == null) {
      map[key] = _ProductBuyGroup(
        date: day,
        store: line.store,
        quantity: line.quantity,
        amount: line.amount,
      );
    } else {
      map[key] = _ProductBuyGroup(
        date: existing.date,
        store: existing.store,
        quantity: existing.quantity + line.quantity,
        amount: existing.amount + line.amount,
      );
    }
  }
  final groups = map.values.toList()
    ..sort((a, b) {
      final ad = a.date ?? DateTime(1970);
      final bd = b.date ?? DateTime(1970);
      return bd.compareTo(ad);
    });
  return groups;
}

class _ProductSummaryHeader extends StatelessWidget {
  final ProductSpend product;
  final ProductPurchaseBreakdown breakdown;
  final bool byQuantity;
  final String lang;

  const _ProductSummaryHeader({
    required this.product,
    required this.breakdown,
    required this.byQuantity,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              AppStrings.purchaseCount(
                _groupPurchaseLines(breakdown.thisPeriod).length,
                lang,
              ),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            byQuantity
                ? '${_fmtQty(breakdown.periodQuantity)} ${AppStrings.get('dash_qty_unit', lang)}'
                : '${product.amount.toStringAsFixed(2)} AZN',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B5E20),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductBuyRow extends StatelessWidget {
  final _ProductBuyGroup buy;
  final String lang;
  final bool byQuantity;

  const _ProductBuyRow({
    required this.buy,
    required this.lang,
    required this.byQuantity,
  });

  @override
  Widget build(BuildContext context) {
    final dateLabel = buy.date != null
        ? '${buy.date!.day.toString().padLeft(2, '0')}.${buy.date!.month.toString().padLeft(2, '0')}.${buy.date!.year}'
        : '—';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(dateLabel),
      subtitle: buy.store.isNotEmpty ? Text(buy.store, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
      trailing: Text(
        byQuantity
            ? '${_fmtQty(buy.quantity)} ${AppStrings.get('dash_qty_unit', lang)}'
            : '${buy.amount.toStringAsFixed(2)} AZN',
        style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1B5E20)),
      ),
    );
  }
}

String _fmtQty(double q) =>
    q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toStringAsFixed(1);

void showCategorySheet(
  BuildContext context, {
  required CategorySpend category,
  required List<CategoryItemDetail> items,
}) {
  final lang = currentLanguage.value;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (_, scroll) => _SheetScaffold(
        title: category.name,
        subtitle:
            '${category.amount.toStringAsFixed(2)} AZN · ${(category.share * 100).toStringAsFixed(0)}%',
        scrollController: scroll,
        header: _CategoryHeader(category: category, lang: lang),
        children: items.isEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    AppStrings.get('dash_no_category_items', lang),
                    style: TextStyle(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ]
            : items
                .map((i) => _CategoryItemRow(item: i, lang: lang))
                .toList(),
      ),
    ),
  );
}

class _SheetScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final ScrollController scrollController;
  final Widget? header;
  final List<Widget> children;

  const _SheetScaffold({
    required this.title,
    this.subtitle,
    required this.scrollController,
    this.header,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
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
        if (header != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: header!),
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: children,
          ),
        ),
      ],
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  final CategorySpend category;
  final String lang;
  const _CategoryHeader({required this.category, required this.lang});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Color(category.color).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(category.color).withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              AppStrings.get('dash_category_spend', lang),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            '${category.amount.toStringAsFixed(2)} AZN',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(category.color),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreRow extends StatelessWidget {
  final StoreSpend store;
  final String lang;
  const _StoreRow({required this.store, required this.lang});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFE8F5E9),
        child: Text(
          store.name.isNotEmpty ? store.name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Color(0xFF1B5E20),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(store.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(AppStrings.visitCount(store.visitCount, lang)),
      trailing: Text(
        '${store.amount.toStringAsFixed(2)} AZN',
        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  final int rank;
  final ProductSpend product;
  final bool byQuantity;
  final String lang;
  final VoidCallback? onTap;

  const _ProductRow({
    required this.rank,
    required this.product,
    required this.byQuantity,
    required this.lang,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final trailing = byQuantity
        ? '${_fmtQty(product.totalQuantity)} ${AppStrings.get('dash_qty_unit', lang)}'
        : '${product.amount.toStringAsFixed(2)} AZN';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: byQuantity
            ? const Color(0xFF2196F3).withValues(alpha: 0.15)
            : const Color(0xFF1B5E20).withValues(alpha: 0.15),
        child: Text(
          '$rank',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: byQuantity ? const Color(0xFF2196F3) : const Color(0xFF1B5E20),
          ),
        ),
      ),
      title: Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(AppStrings.purchaseCount(product.purchaseCount, lang)),
      trailing: Text(
        trailing,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: byQuantity ? const Color(0xFF2196F3) : const Color(0xFF1B5E20),
        ),
      ),
    );
  }

  String _fmtQty(double q) =>
      q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toStringAsFixed(1);
}

class _CategoryItemRow extends StatelessWidget {
  final CategoryItemDetail item;
  final String lang;
  const _CategoryItemRow({required this.item, required this.lang});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${_fmtQty(item.quantity)} ${AppStrings.get('dash_qty_unit', lang)}',
      ),
      trailing: Text(
        '${item.amount.toStringAsFixed(2)} AZN',
        style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1B5E20)),
      ),
    );
  }

  String _fmtQty(double q) =>
      q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toStringAsFixed(1);
}
