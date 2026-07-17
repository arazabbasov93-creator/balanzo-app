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
  final String? familyName;
  final int periodMonth;
  final int periodYear;
  final void Function(int month, int year) onPeriodChanged;
  final bool periodSelectorEnabled;
  final bool attachedToHeader;
  final bool hidePersonalFinance;

  const HomeGreetingCard({
    super.key,
    required this.identity,
    required this.insights,
    this.incomeTotal = 0,
    this.cachedName,
    this.familyName,
    required this.periodMonth,
    required this.periodYear,
    required this.onPeriodChanged,
    this.periodSelectorEnabled = true,
    this.attachedToHeader = false,
    this.hidePersonalFinance = false,
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
    final greetingText = familyName != null && familyName!.trim().isNotEmpty
        ? familyName!.trim()
        : AppStrings.warmGreeting(firstName, lang);

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
        borderRadius: attachedToHeader ? null : BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                familyName != null ? Icons.family_restroom : Icons.waving_hand,
                color: familyName != null ? Colors.white : Colors.amber,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  greetingText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              HomePeriodPickers(
                month: periodMonth,
                year: periodYear,
                onChanged: onPeriodChanged,
                enabled: periodSelectorEnabled,
              ),
            ],
          ),
          if (!hidePersonalFinance) ...[
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
        ],
      ),
    );
  }
}

class HomePeriodPickers extends StatelessWidget {
  final int month;
  final int year;
  final void Function(int month, int year) onChanged;
  final bool enabled;

  const HomePeriodPickers({
    super.key,
    required this.month,
    required this.year,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final lang = currentLanguage.value;
    final now = DateTime.now();
    final years = [now.year, now.year - 1, now.year - 2];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PeriodChip(
          label: AppStrings.monthName(month, lang),
          enabled: enabled,
          onTap: enabled
              ? () => _showMonthSheet(context, lang, month, year, onChanged)
              : null,
        ),
        const SizedBox(width: 4),
        _PeriodChip(
          label: '$year',
          enabled: enabled,
          onTap: enabled
              ? () => _showYearSheet(context, lang, years, month, year, onChanged)
              : null,
        ),
      ],
    );
  }

  static void _showMonthSheet(
    BuildContext context,
    String lang,
    int currentMonth,
    int currentYear,
    void Function(int month, int year) onChanged,
  ) {
    const itemHeight = 44.0;
    const visibleCount = 3;
    final controller = FixedExtentScrollController(
      initialItem: (currentMonth - 1).clamp(0, 11),
    );

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        var selected = currentMonth;
        return StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppStrings.get('select_month', lang),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: itemHeight * visibleCount,
                    child: ListWheelScrollView.useDelegate(
                      controller: controller,
                      itemExtent: itemHeight,
                      physics: const FixedExtentScrollPhysics(),
                      onSelectedItemChanged: (i) => setSheetState(() => selected = i + 1),
                      childDelegate: ListWheelChildBuilderDelegate(
                        childCount: 12,
                        builder: (_, i) {
                          final m = i + 1;
                          final isSelected = m == selected;
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              setSheetState(() => selected = m);
                              controller.jumpToItem(i);
                            },
                            child: Center(
                              child: Text(
                                AppStrings.monthName(m, lang),
                                style: TextStyle(
                                  fontSize: isSelected ? 16 : 14,
                                  fontWeight:
                                      isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected
                                      ? AppColors.primaryGreenDark
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        onChanged(selected, currentYear);
                        Navigator.pop(ctx);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryGreenDark,
                      ),
                      child: Text(_confirmLabel(lang)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static void _showYearSheet(
    BuildContext context,
    String lang,
    List<int> years,
    int currentMonth,
    int currentYear,
    void Function(int month, int year) onChanged,
  ) {
    const itemHeight = 44.0;
    const visibleCount = 2;
    final initialIndex = years.indexOf(currentYear).clamp(0, years.length - 1);
    final controller = FixedExtentScrollController(initialItem: initialIndex);

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        var selected = currentYear;
        return StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _yearSheetTitle(lang),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: itemHeight * visibleCount,
                    child: ListWheelScrollView.useDelegate(
                      controller: controller,
                      itemExtent: itemHeight,
                      physics: const FixedExtentScrollPhysics(),
                      onSelectedItemChanged: (i) =>
                          setSheetState(() => selected = years[i]),
                      childDelegate: ListWheelChildBuilderDelegate(
                        childCount: years.length,
                        builder: (_, i) {
                          final y = years[i];
                          final isSelected = y == selected;
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              setSheetState(() => selected = y);
                              controller.jumpToItem(i);
                            },
                            child: Center(
                              child: Text(
                                '$y',
                                style: TextStyle(
                                  fontSize: isSelected ? 16 : 14,
                                  fontWeight:
                                      isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected
                                      ? AppColors.primaryGreenDark
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        onChanged(currentMonth, selected);
                        Navigator.pop(ctx);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryGreenDark,
                      ),
                      child: Text(_confirmLabel(lang)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

String _confirmLabel(String lang) => AppStrings.get('confirm', lang);

String _yearSheetTitle(String lang) => AppStrings.get('select_year', lang);

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  const _PeriodChip({
    required this.label,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: enabled ? 0.15 : 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: enabled ? Colors.white : Colors.white54,
                ),
              ),
              Icon(
                Icons.arrow_drop_down,
                color: enabled ? Colors.white : Colors.white38,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
