import 'package:flutter/material.dart';
import '../../app_state.dart';
import '../../l10n/app_strings.dart';
import '../../models/budget.dart';
import '../../models/income.dart';
import '../../models/home_insights.dart';
import '../../services/income_service.dart';
import '../../config/app_colors.dart';
import '../../utils/currency_data.dart';

class MemberMonthSummary {
  final String userId;
  final String displayName;
  final double income;
  final double spend;
  final double? spendLimit;

  const MemberMonthSummary({
    required this.userId,
    required this.displayName,
    required this.income,
    required this.spend,
    this.spendLimit,
  });

  double get remaining => income - spend;
}

class HomeBudgetSection extends StatelessWidget {
  final HomeInsights? insights;
  final List<Budget> budgets;
  final List<IncomeEntry> incomeEntries;
  final double incomeTotal;
  final List<MemberMonthSummary>? familyMembers;
  final VoidCallback onEditIncome;

  const HomeBudgetSection({
    super.key,
    required this.insights,
    required this.budgets,
    required this.incomeEntries,
    required this.incomeTotal,
    this.familyMembers,
    required this.onEditIncome,
  });

  @override
  Widget build(BuildContext context) {
    final lang = currentLanguage.value;
    final spend = insights?.thisMonthTotal ?? 0;
    final remaining = incomeTotal - spend;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: AppStrings.get('budget_section', lang)),
        const SizedBox(height: 8),
        if (familyMembers != null && familyMembers!.isNotEmpty) ...[
          ...familyMembers!.map((m) => _MemberBalanceCard(member: m, lang: lang)),
          const SizedBox(height: 8),
          _TotalsRow(
            income: familyMembers!.fold(0.0, (s, m) => s + m.income),
            spend: familyMembers!.fold(0.0, (s, m) => s + m.spend),
            lang: lang,
          ),
        ] else ...[
          if (incomeEntries.isNotEmpty) ...[
            ...incomeEntries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        e.recurring ? Icons.repeat : Icons.event,
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          e.label,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Text(
                        '${e.amount.toStringAsFixed(2)} AZN',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 6),
          ],
          _PersonalBalanceCard(
            income: incomeTotal,
            spend: spend,
            remaining: remaining,
            lang: lang,
            onEditIncome: onEditIncome,
          ),
        ],
        if (budgets.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            AppStrings.get('budget_limits', lang),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          ...budgets.take(4).map((b) => _BudgetRow(budget: b, lang: lang)),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

class _PersonalBalanceCard extends StatelessWidget {
  final double income;
  final double spend;
  final double remaining;
  final String lang;
  final VoidCallback onEditIncome;

  const _PersonalBalanceCard({
    required this.income,
    required this.spend,
    required this.remaining,
    required this.lang,
    required this.onEditIncome,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          _MoneyRow(
            label: AppStrings.get('income_total', lang),
            value: income,
            onTap: onEditIncome,
            actionLabel: AppStrings.get('edit', lang),
          ),
          const SizedBox(height: 8),
          _MoneyRow(label: AppStrings.get('spend_total', lang), value: spend),
          const Divider(height: 20),
          _MoneyRow(
            label: AppStrings.get('remaining_balance', lang),
            value: remaining,
            bold: true,
            valueColor: remaining >= 0 ? AppColors.primaryGreen(Theme.of(context).brightness) : Colors.red.shade700,
          ),
        ],
      ),
    );
  }
}

class _MemberBalanceCard extends StatelessWidget {
  final MemberMonthSummary member;
  final String lang;

  const _MemberBalanceCard({required this.member, required this.lang});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            member.displayName,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 6),
          _MoneyRow(label: AppStrings.get('income_total', lang), value: member.income),
          _MoneyRow(label: AppStrings.get('spend_total', lang), value: member.spend),
          _MoneyRow(
            label: AppStrings.get('remaining_balance', lang),
            value: member.remaining,
            valueColor: member.remaining >= 0
                ? AppColors.primaryGreen(Theme.of(context).brightness)
                : Colors.red.shade700,
          ),
        ],
      ),
    );
  }
}

class _TotalsRow extends StatelessWidget {
  final double income;
  final double spend;
  final String lang;

  const _TotalsRow({
    required this.income,
    required this.spend,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen(Theme.of(context).brightness).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _MoneyRow(label: AppStrings.get('family_income_total', lang), value: income, bold: true),
          _MoneyRow(label: AppStrings.get('family_spend_total', lang), value: spend, bold: true),
          _MoneyRow(
            label: AppStrings.get('remaining_balance', lang),
            value: income - spend,
            bold: true,
            valueColor: income - spend >= 0
                ? AppColors.primaryGreen(Theme.of(context).brightness)
                : Colors.red.shade700,
          ),
        ],
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  final String label;
  final double value;
  final bool bold;
  final Color? valueColor;
  final VoidCallback? onTap;
  final String? actionLabel;

  const _MoneyRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
    this.onTap,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (onTap != null && actionLabel != null) ...[
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(actionLabel!, style: const TextStyle(fontSize: 11)),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            formatMoney(value, null),
            style: TextStyle(
              fontSize: bold ? 14 : 12,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  final Budget budget;
  final String lang;

  const _BudgetRow({required this.budget, required this.lang});

  @override
  Widget build(BuildContext context) {
    final frac = budget.usedFraction.clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  budget.categoryName ?? AppStrings.get('budget_section', lang),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                '${budget.spent.toStringAsFixed(0)} / ${budget.amount.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: frac,
            minHeight: 4,
            backgroundColor: Colors.grey.shade300,
            color: budget.isOverBudget ? Colors.red : AppColors.primaryGreen(Theme.of(context).brightness),
          ),
        ],
      ),
    );
  }
}

Future<void> showIncomeEditorSheet(
  BuildContext context, {
  required int month,
  required int year,
  required List<IncomeEntry> initial,
  required VoidCallback onSaved,
}) async {
  final lang = currentLanguage.value;
  final labelCtrl = TextEditingController();
  final amountCtrl = TextEditingController();
  var entries = List<IncomeEntry>.from(initial);
  var editingId = '';
  var isRecurring = true;

  void resetForm() {
    editingId = '';
    isRecurring = true;
    labelCtrl.clear();
    amountCtrl.clear();
  }

  void startEdit(IncomeEntry e) {
    editingId = e.id;
    isRecurring = e.recurring;
    labelCtrl.text = e.label;
    amountCtrl.text = e.amount.toStringAsFixed(2);
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: StatefulBuilder(
        builder: (ctx, setLocal) {
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    AppStrings.get('income_editor_title', lang),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (entries.isEmpty)
                    Text(
                      AppStrings.get('income_sources', lang),
                      style: TextStyle(
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ...entries.map((e) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          e.recurring ? Icons.repeat : Icons.event,
                          size: 20,
                          color: AppColors.primaryGreen(Theme.of(context).brightness),
                        ),
                        title: Text(e.label),
                        subtitle: Text(
                          e.recurring
                              ? AppStrings.get('income_recurring', lang)
                              : AppStrings.get('income_one_time', lang),
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${e.amount.toStringAsFixed(2)} AZN'),
                            IconButton(
                              icon: Icon(Icons.delete_outline,
                                  color: Colors.red.shade600, size: 20),
                              tooltip: AppStrings.get('income_delete', lang),
                              onPressed: () async {
                                await IncomeService.remove(
                                  month: month,
                                  year: year,
                                  entryId: e.id,
                                  recurring: e.recurring,
                                );
                                entries =
                                    await IncomeService.fetchForMonth(month, year);
                                if (editingId == e.id) resetForm();
                                setLocal(() {});
                                onSaved();
                              },
                            ),
                          ],
                        ),
                        onTap: () => setLocal(() => startEdit(e)),
                      )),
                  const Divider(height: 24),
                  Text(
                    editingId.isEmpty
                        ? AppStrings.get('income_add_source', lang)
                        : AppStrings.get('income_edit_source', lang),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    AppStrings.get('income_type_label', lang),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: true,
                        label: Text(AppStrings.get('income_recurring', lang)),
                        icon: const Icon(Icons.repeat, size: 16),
                      ),
                      ButtonSegment(
                        value: false,
                        label: Text(AppStrings.get('income_one_time', lang)),
                        icon: const Icon(Icons.event, size: 16),
                      ),
                    ],
                    selected: {isRecurring},
                    onSelectionChanged: (s) =>
                        setLocal(() => isRecurring = s.first),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: labelCtrl,
                    decoration: InputDecoration(
                      labelText: AppStrings.get('income_label', lang),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: AppStrings.get('income_amount', lang),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () async {
                      final label = labelCtrl.text.trim();
                      final amount =
                          double.tryParse(amountCtrl.text.replaceAll(',', '.'));
                      if (label.isEmpty || amount == null) return;
                      await IncomeService.upsert(
                        month: month,
                        year: year,
                        label: label,
                        amount: amount,
                        recurring: isRecurring,
                        entryId: editingId.isEmpty ? null : editingId,
                      );
                      entries = await IncomeService.fetchForMonth(month, year);
                      resetForm();
                      setLocal(() {});
                      onSaved();
                    },
                    child: Text(
                      editingId.isEmpty
                          ? AppStrings.get('income_add_source', lang)
                          : AppStrings.get('save', lang),
                    ),
                  ),
                  if (editingId.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => setLocal(resetForm),
                      child: Text(AppStrings.get('cancel', lang)),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(AppStrings.get('save', lang)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}
