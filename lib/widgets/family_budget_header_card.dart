import 'package:flutter/material.dart';
import '../app_state.dart';
import '../config/app_colors.dart';
import '../l10n/app_strings.dart';
import '../models/family_period_summary.dart';
import '../utils/currency_data.dart';
import 'home/home_greeting_card.dart';

/// Family budget summary card — same layout on Profile → Family and Home → Family.
class FamilyBudgetHeaderCard extends StatelessWidget {
  final FamilyPeriodSummary summary;
  final bool showPeriodPicker;
  final void Function(int month, int year)? onPeriodChanged;

  const FamilyBudgetHeaderCard({
    super.key,
    required this.summary,
    this.showPeriodPicker = true,
    this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context) {
    final lang = currentLanguage.value;
    final budgetText = summary.hasBudget
        ? formatMoney(summary.availableBudget, null)
        : AppStrings.get('family_budget_not_set', lang);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryGreen(Theme.of(context).brightness),
            AppColors.gradientEnd(Theme.of(context).brightness),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.home, color: Colors.white, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  summary.familyName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (showPeriodPicker && onPeriodChanged != null)
                HomePeriodPickers(
                  month: summary.month,
                  year: summary.year,
                  onChanged: onPeriodChanged!,
                ),
            ],
          ),
          const SizedBox(height: 16),
          _BudgetLine(
            label: AppStrings.get('family_available_budget', lang),
            value: budgetText,
            bold: true,
          ),
          const SizedBox(height: 6),
          _BudgetLine(
            label: AppStrings.get('family_spent_label', lang),
            value: formatMoney(summary.spent, null),
          ),
          const SizedBox(height: 6),
          _BudgetLine(
            label: AppStrings.get('remaining_balance', lang),
            value: summary.hasBudget
                ? formatMoney(summary.remaining, null)
                : AppStrings.get('family_budget_not_set', lang),
            valueColor: summary.hasBudget
                ? (summary.remaining >= 0
                    ? Colors.lightGreen.shade100
                    : Colors.amber.shade100)
                : Colors.white70,
          ),
        ],
      ),
    );
  }
}

class _BudgetLine extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  const _BudgetLine({
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: bold ? 16 : 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
