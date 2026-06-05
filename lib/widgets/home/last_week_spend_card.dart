import 'package:flutter/material.dart';
import '../../app_state.dart';
import '../../l10n/app_strings.dart';
import '../../models/home_insights.dart';

class LastWeekSpendCard extends StatelessWidget {
  final HomeInsights insights;

  const LastWeekSpendCard({super.key, required this.insights});

  @override
  Widget build(BuildContext context) {
    final lang = currentLanguage.value;
    final rows = <_CompareRow>[
      _CompareRow(
        label: AppStrings.get('dash_this_week', lang),
        current: insights.thisWeekSpend,
        previous: insights.lastWeekSpend,
        previousLabel: AppStrings.get('dash_last_week', lang),
        show: insights.thisWeekSpend > 0 || insights.lastWeekSpend > 0,
      ),
      _CompareRow(
        label: AppStrings.get('dash_this_month', lang),
        current: insights.thisMonthTotal,
        previous: insights.lastMonthTotal,
        previousLabel: AppStrings.get('dash_last_month', lang),
        show: insights.thisMonthTotal > 0 || insights.lastMonthTotal > 0,
      ),
      _CompareRow(
        label: AppStrings.get('dash_this_month', lang),
        current: insights.thisMonthTotal,
        previous: insights.lastYearSameMonthTotal,
        previousLabel: AppStrings.get('dash_last_year_month', lang),
        show: insights.lastYearSameMonthTotal > 0,
      ),
    ].where((r) => r.show).toList();

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1, color: Theme.of(context).dividerColor),
              ),
            _ComparisonRow(row: rows[i], lang: lang),
          ],
        ],
      ),
    );
  }
}

class _CompareRow {
  final String label;
  final double current;
  final double previous;
  final String previousLabel;
  final bool show;

  const _CompareRow({
    required this.label,
    required this.current,
    required this.previous,
    required this.previousLabel,
    required this.show,
  });
}

class _ComparisonRow extends StatelessWidget {
  final _CompareRow row;
  final String lang;

  const _ComparisonRow({required this.row, required this.lang});

  @override
  Widget build(BuildContext context) {
    final diff = row.current - row.previous;
    final hasDiff = row.previous > 0 || row.current > 0;

    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${row.current.toStringAsFixed(2)} AZN',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.previousLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${row.previous.toStringAsFixed(2)} AZN',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (hasDiff)
          Icon(
            diff >= 0 ? Icons.north_east : Icons.south_east,
            size: 16,
            color: diff >= 0 ? Colors.orange.shade700 : Colors.green.shade700,
          ),
      ],
    );
  }
}
