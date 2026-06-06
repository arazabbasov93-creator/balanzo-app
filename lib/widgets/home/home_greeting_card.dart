import 'package:flutter/material.dart';
import '../../app_state.dart';
import '../../l10n/app_strings.dart';
import '../../models/home_insights.dart';
import '../../services/user_profile_service.dart';
import '../../config/app_colors.dart';
import '../../utils/currency_data.dart';

class HomeGreetingCard extends StatelessWidget {
  final String identity;
  final HomeInsights? insights;
  final double incomeTotal;
  final String? cachedName;
  final int periodMonth;
  final int periodYear;
  final void Function(int month, int year) onPeriodChanged;
  final bool periodSelectorEnabled;
  final bool attachedToHeader;

  const HomeGreetingCard({
    super.key,
    required this.identity,
    required this.insights,
    this.incomeTotal = 0,
    this.cachedName,
    required this.periodMonth,
    required this.periodYear,
    required this.onPeriodChanged,
    this.periodSelectorEnabled = true,
    this.attachedToHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    final lang = currentLanguage.value;
    final firstName = UserProfileService.displayFirstName(
      cachedName ?? insights?.fullName ?? identity,
      identity,
    );
    final periodMatches = insights != null &&
        insights!.periodMonth == periodMonth &&
        insights!.periodYear == periodYear;
    final spend = periodMatches ? insights!.thisMonthTotal : 0.0;
    final remaining = incomeTotal - spend;
    final years = List.generate(5, (i) => DateTime.now().year - i);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, attachedToHeader ? 8 : 16, 16, attachedToHeader ? 12 : 16),
      decoration: BoxDecoration(
        gradient: attachedToHeader
            ? null
            : LinearGradient(
          colors: [
            AppColors.primaryGreen(Theme.of(context).brightness),
            AppColors.gradientEnd(Theme.of(context).brightness),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        color: attachedToHeader ? Colors.transparent : null,
        borderRadius: attachedToHeader
            ? null
            : BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.waving_hand, color: Colors.amber, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  AppStrings.warmGreeting(firstName, lang),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              HomePeriodDropdowns(
                month: periodMonth,
                year: periodYear,
                years: years,
                onChanged: onPeriodChanged,
                enabled: periodSelectorEnabled,
              ),
            ],
          ),
          if (incomeTotal > 0) ...[
            const SizedBox(height: 6),
            Text(
              '${AppStrings.get('income_total', lang)}: ${formatMoney(incomeTotal, insights?.periodCurrency)}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            formatMoney(spend, insights?.periodCurrency),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
            ),
          ),
          Text(
            AppStrings.spentInMonth(periodMonth, periodYear, lang),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          if (incomeTotal > 0) ...[
            const SizedBox(height: 4),
            Text(
              '${AppStrings.get('remaining_balance', lang)}: ${formatMoney(remaining, insights?.periodCurrency)}',
              style: TextStyle(
                color: remaining >= 0 ? Colors.lightGreen.shade100 : Colors.amber.shade100,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class HomePeriodDropdowns extends StatelessWidget {
  final int month;
  final int year;
  final List<int> years;
  final void Function(int month, int year) onChanged;
  final bool enabled;

  const HomePeriodDropdowns({
    super.key,
    required this.month,
    required this.year,
    required this.years,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final lang = currentLanguage.value;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MiniDropdown<int>(
          value: month,
          enabled: enabled,
          items: List.generate(12, (i) => i + 1)
              .map((m) => DropdownMenuItem(
                    value: m,
                    child: Text(
                      AppStrings.monthName(m, lang),
                      style: const TextStyle(fontSize: 11, color: Colors.white),
                    ),
                  ))
              .toList(),
          onChanged: enabled
              ? (m) {
                  if (m != null) onChanged(m, year);
                }
              : null,
        ),
        const SizedBox(width: 4),
        _MiniDropdown<int>(
          value: year,
          enabled: enabled,
          items: years
              .map((y) => DropdownMenuItem(
                    value: y,
                    child: Text('$y',
                        style: const TextStyle(fontSize: 11, color: Colors.white)),
                  ))
              .toList(),
          onChanged: enabled
              ? (y) {
                  if (y != null) onChanged(month, y);
                }
              : null,
        ),
      ],
    );
  }
}

class _MiniDropdown<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool enabled;

  const _MiniDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          dropdownColor: AppColors.gradientEnd(Theme.of(context).brightness),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
          isDense: true,
        ),
      ),
    );
  }
}
