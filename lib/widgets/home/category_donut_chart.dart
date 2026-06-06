import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/home_insights.dart';
import '../../utils/currency_data.dart';
import 'home_detail_sheets.dart';

/// Donut chart for category share of monthly spend (top slices + Other).
class CategoryDonutChart extends StatelessWidget {
  final HomeInsights insights;

  const CategoryDonutChart({
    super.key,
    required this.insights,
  });

  List<CategorySpend> get breakdown => insights.categoryBreakdown;
  double get total => insights.thisMonthTotal;

  @override
  Widget build(BuildContext context) {
    if (breakdown.isEmpty) return const SizedBox.shrink();

    final itemSum = breakdown.fold(0.0, (s, c) => s + c.amount);
    final displayTotal = itemSum > 0 ? itemSum : total;
    if (displayTotal <= 0) return const SizedBox.shrink();

    final slices = _slices(displayTotal);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: CustomPaint(
              painter: _DonutPainter(slices: slices),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayTotal.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (currencySymbol(insights.periodCurrency).isNotEmpty)
                      Text(
                        currencySymbol(insights.periodCurrency),
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      )
                    else if (insights.periodCurrency != null)
                      Text(
                        insights.periodCurrency!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: slices.take(8).map((s) {
                final cat = breakdown
                    .where((c) => c.name == s.label)
                    .firstOrNull;
                return InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: cat == null
                      ? null
                      : () => showCategorySheet(
                            context,
                            category: cat,
                            items: insights.itemsForCategory(cat),
                          ),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: s.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Text(
                          '${(s.share * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  List<_Slice> _slices(double displayTotal) {
    const maxSlices = 8;
    final top = breakdown.take(maxSlices).toList();
    final otherAmount = breakdown.skip(maxSlices).fold(0.0, (s, c) => s + c.amount);
    final slices = top
        .map((c) => _Slice(
              label: c.name,
              share: c.share,
              color: Color(c.color),
            ))
        .toList();
    if (otherAmount > 0 && breakdown.length > maxSlices) {
      slices.add(_Slice(
        label: 'Other',
        share: otherAmount / displayTotal,
        color: const Color(0xFF9E9E9E),
      ));
    }
    return slices;
  }
}

class _Slice {
  final String label;
  final double share;
  final Color color;
  const _Slice({required this.label, required this.share, required this.color});
}

class _DonutPainter extends CustomPainter {
  final List<_Slice> slices;
  _DonutPainter({required this.slices});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    const stroke = 18.0;
    var start = -math.pi / 2;

    for (final slice in slices) {
      if (slice.share <= 0) continue;
      final sweep = slice.share * 2 * math.pi;
      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - stroke / 2),
        start,
        sweep,
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.slices != slices;
}
