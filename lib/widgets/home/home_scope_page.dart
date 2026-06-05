import 'package:flutter/material.dart';
import '../../app_state.dart';
import '../../l10n/app_strings.dart';
import '../../models/budget.dart';
import '../../models/family.dart';
import '../../models/home_insights.dart';
import '../../models/income.dart';
import '../../services/auth_service.dart';
import '../../services/budget_service.dart';
import '../../services/family_service.dart';
import '../../services/home_data_cache.dart';
import '../../services/income_service.dart';
import '../../services/notification_service.dart';
import '../../services/receipt_service.dart';
import '../../widgets/add_receipt_sheet.dart';
import 'home_greeting_card.dart';
import 'category_donut_chart.dart';
import 'home_budget_section.dart';
import 'home_insight_sections.dart';
import 'insight_stat_grid.dart';
import 'last_week_spend_card.dart';

typedef HomeScopeData = ({
  HomeInsights? insights,
  List<Budget> budgets,
  List<Budget> budgetAlerts,
  bool noFamily,
  List<IncomeEntry> incomeEntries,
  double incomeTotal,
  List<MemberMonthSummary>? familyMembers,
  Family? family,
});

typedef HomeHeaderSnapshot = ({
  HomeInsights? insights,
  double incomeTotal,
  String? cachedName,
  bool periodSelectorEnabled,
  bool noFamily,
});

class HomeScopePage extends StatefulWidget {
  final int scopeIndex;
  final int periodMonth;
  final int periodYear;
  final void Function(int month, int year) onPeriodChanged;
  final VoidCallback onGlobalRefresh;
  final VoidCallback? onFamilyStatusChanged;
  final bool hasFamily;
  final bool isActive;
  final bool embedGreeting;
  final void Function(HomeHeaderSnapshot snapshot)? onHeaderUpdate;

  const HomeScopePage({
    super.key,
    required this.scopeIndex,
    required this.periodMonth,
    required this.periodYear,
    required this.onPeriodChanged,
    required this.onGlobalRefresh,
    this.onFamilyStatusChanged,
    this.hasFamily = true,
    this.isActive = true,
    this.embedGreeting = true,
    this.onHeaderUpdate,
  });

  @override
  State<HomeScopePage> createState() => _HomeScopePageState();
}

class _HomeScopePageState extends State<HomeScopePage>
    with AutomaticKeepAliveClientMixin {
  late Future<HomeScopeData> _future;
  HomeScopeData? _cached;
  bool _itemsLoading = false;
  bool _startedLoad = false;
  HomeHeaderSnapshot? _lastHeaderPublished;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    currentLanguage.addListener(_onLangChange);
    receiptsRevision.addListener(_onReceiptsChanged);
    if (widget.isActive) _startLoad();
  }

  @override
  void didUpdateWidget(HomeScopePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive && !_startedLoad) {
      _startLoad();
    }
    if (oldWidget.scopeIndex != widget.scopeIndex) {
      _reload(force: false);
      return;
    }
    if (oldWidget.periodMonth != widget.periodMonth ||
        oldWidget.periodYear != widget.periodYear) {
      _switchPeriod();
    }
  }

  void _startLoad() {
    _startedLoad = true;
    _future = _load();
    setState(() {});
  }

  void _reload({bool force = true}) {
    if (force) HomeDataCache.invalidate();
    setState(() => _future = _load(force: force));
  }

  Future<void> _switchPeriod() async {
    final familyMode = widget.scopeIndex == 1;
    final lang = currentLanguage.value;
    final instant = HomeDataCache.tryInstant(
      periodMonth: widget.periodMonth,
      periodYear: widget.periodYear,
      familyMode: familyMode,
      locale: lang,
      fullName: cachedDisplayName.value,
      rowsOnly: !HomeDataCache.isScopeReady(familyMode),
    );
    if (instant == null) {
      _reload(force: false);
      return;
    }
    if (mounted) {
      setState(() {
        _cached = (
          insights: instant,
          budgets: _cached?.budgets ?? [],
          budgetAlerts: _cached?.budgetAlerts ?? [],
          noFamily: _cached?.noFamily ?? false,
          incomeEntries: _cached?.incomeEntries ?? [],
          incomeTotal: _cached?.incomeTotal ?? 0,
          familyMembers: _cached?.familyMembers,
          family: _cached?.family,
        ) as HomeScopeData;
      });
    }
    final pack = await _loadAuxiliary(
      month: widget.periodMonth,
      year: widget.periodYear,
      familyMode: familyMode,
      insights: instant,
    );
    if (mounted) setState(() => _cached = pack);
  }

  @override
  void dispose() {
    currentLanguage.removeListener(_onLangChange);
    receiptsRevision.removeListener(_onReceiptsChanged);
    super.dispose();
  }

  void _onLangChange() => _switchPeriod();

  void _onReceiptsChanged() => _reload(force: true);

  Future<HomeScopeData> _load({bool force = false}) async {
    final familyMode = widget.scopeIndex == 1;
    final lang = currentLanguage.value;
    final month = widget.periodMonth;
    final year = widget.periodYear;

    if (familyMode && !widget.hasFamily) {
      widget.onFamilyStatusChanged?.call();
      return (
        insights: null as HomeInsights?,
        budgets: <Budget>[],
        budgetAlerts: <Budget>[],
        noFamily: true,
        incomeEntries: <IncomeEntry>[],
        incomeTotal: 0,
        familyMembers: null as List<MemberMonthSummary>?,
        family: null as Family?,
      ) as HomeScopeData;
    }

    if (familyMode) {
      final family = await FamilyService.fetchMyFamily();
      if (family == null) {
        widget.onFamilyStatusChanged?.call();
        return (
          insights: null as HomeInsights?,
          budgets: <Budget>[],
          budgetAlerts: <Budget>[],
          noFamily: true,
          incomeEntries: <IncomeEntry>[],
          incomeTotal: 0,
          familyMembers: null as List<MemberMonthSummary>?,
          family: null as Family?,
        ) as HomeScopeData;
      }
      widget.onFamilyStatusChanged?.call();
    }

    await HomeDataCache.ensureRows(familyMode, force: force);
    var insights = HomeDataCache.tryInstant(
      periodMonth: month,
      periodYear: year,
      familyMode: familyMode,
      locale: lang,
      fullName: cachedDisplayName.value,
      rowsOnly: true,
    );

    if (insights != null && mounted) {
      setState(() {
        _itemsLoading = true;
        _cached = (
          insights: insights,
          budgets: _cached?.budgets ?? [],
          budgetAlerts: _cached?.budgetAlerts ?? [],
          noFamily: false,
          incomeEntries: _cached?.incomeEntries ?? [],
          incomeTotal: _cached?.incomeTotal ?? 0,
          familyMembers: _cached?.familyMembers,
          family: _cached?.family,
        );
      });
      _publishHeader(_cached, insights);
    }

    await HomeDataCache.ensureItems(familyMode);
    insights = await HomeDataCache.loadInsights(
      periodMonth: month,
      periodYear: year,
      familyMode: familyMode,
      locale: lang,
      fullName: cachedDisplayName.value,
      force: false,
    );

    if (mounted) setState(() => _itemsLoading = false);

    return _loadAuxiliary(
      month: month,
      year: year,
      familyMode: familyMode,
      insights: insights,
    );
  }

  Future<HomeScopeData> _loadAuxiliary({
    required int month,
    required int year,
    required bool familyMode,
    required HomeInsights insights,
  }) async {
    List<Budget> budgets = [];
    List<Budget> budgetAlerts = [];
    List<IncomeEntry> incomeEntries = [];
    double incomeTotal = 0;
    List<MemberMonthSummary>? familyMembers;
    Family? family;

    if (familyMode) {
      family = await FamilyService.fetchMyFamily();
      if (family != null) {
        final members = await FamilyService.fetchMembers(family.id);
        final receipts = HomeDataCache.rowsFor(true) ??
            await ReceiptService.fetchFamily();
        familyMembers = [];
        for (final m in members) {
          var spend = 0.0;
          for (final r in receipts) {
            final date = DateTime.tryParse(r['purchase_date']?.toString() ?? '');
            if (date != null &&
                date.year == year &&
                date.month == month &&
                r['user_id'] == m.userId) {
              spend += (r['total_amount'] as num?)?.toDouble() ?? 0;
            }
          }
          final income =
              await IncomeService.totalForMonth(month, year, userId: m.userId);
          familyMembers.add(MemberMonthSummary(
            userId: m.userId,
            displayName: m.displayName,
            income: income,
            spend: spend,
          ));
          if (m.role == 'member' &&
              income > 0 &&
              spend > income &&
              family.createdBy == AuthService.currentUser?.id) {
            await NotificationService.sendFamilyBudgetAlert(
              memberName: m.displayName,
              overspend: spend - income,
            );
          }
        }
        try {
          budgets =
              await BudgetService.fetchForMonth(month, year, familyId: family.id);
          final spent =
              await BudgetService.spentByCategory(month, year, familyId: family.id);
          for (final b in budgets) {
            b.spent = spent[b.categoryId ?? 'uncategorized'] ?? 0;
          }
          budgetAlerts = budgets.where((b) => b.usedFraction >= 0.8).toList();
        } catch (_) {}
      }
    } else {
      incomeEntries = await IncomeService.fetchForMonth(month, year);
      incomeTotal = incomeEntries.fold<double>(0, (s, e) => s + e.amount);
      try {
        budgets = await BudgetService.fetchForMonth(month, year);
        final spent = await BudgetService.spentByCategory(month, year);
        for (final b in budgets) {
          b.spent = spent[b.categoryId ?? 'uncategorized'] ?? 0;
        }
        budgetAlerts = budgets.where((b) => b.usedFraction >= 0.8).toList();
      } catch (_) {}
    }

    return (
      insights: insights,
      budgets: budgets,
      budgetAlerts: budgetAlerts,
      noFamily: false,
      incomeEntries: incomeEntries,
      incomeTotal: incomeTotal,
      familyMembers: familyMembers,
      family: family,
    ) as HomeScopeData;
  }

  void _publishHeader(HomeScopeData? pack, HomeInsights? insights) {
    if (widget.onHeaderUpdate == null) return;
    final snapshot = (
      insights: insights,
      incomeTotal: pack?.incomeTotal ?? 0,
      cachedName: insights?.fullName ?? cachedDisplayName.value,
      periodSelectorEnabled: pack?.noFamily != true,
      noFamily: pack?.noFamily == true,
    );
    if (_lastHeaderPublished != null &&
        _lastHeaderPublished!.insights == snapshot.insights &&
        _lastHeaderPublished!.incomeTotal == snapshot.incomeTotal &&
        _lastHeaderPublished!.cachedName == snapshot.cachedName &&
        _lastHeaderPublished!.periodSelectorEnabled == snapshot.periodSelectorEnabled &&
        _lastHeaderPublished!.noFamily == snapshot.noFamily) {
      return;
    }
    _lastHeaderPublished = snapshot;
    widget.onHeaderUpdate!(snapshot);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final user = AuthService.currentUser;
    final identity = user?.phone ?? user?.email ?? 'User';
    final lang = currentLanguage.value;

    return FutureBuilder<HomeScopeData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final data = snapshot.data!;
          final insights = data.insights;
          if (insights == null ||
              (insights.periodMonth == widget.periodMonth &&
                  insights.periodYear == widget.periodYear)) {
            _cached = data;
            _publishHeader(data, insights);
          }
        }
        final pack = _cached;
        final insights = pack?.insights;

        if (pack?.noFamily == true) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              _FamilySetupPrompt(lang: lang),
            ],
          );
        }

        final receiptsInPeriod = insights?.receiptsThisMonth ?? 0;
        final hasAnyReceipts = (insights?.totalReceiptsInScope ?? 0) > 0;

        return RefreshIndicator(
          onRefresh: () async {
            _reload();
            widget.onGlobalRefresh();
          },
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, widget.embedGreeting ? 20 : 12, 16, 100),
            children: [
              if (widget.embedGreeting)
                ValueListenableBuilder<String?>(
                  valueListenable: cachedDisplayName,
                  builder: (_, cached, child) => HomeGreetingCard(
                    identity: identity,
                    insights: insights,
                    incomeTotal: pack?.incomeTotal ?? 0,
                    cachedName: cached ?? insights?.fullName,
                    periodMonth: widget.periodMonth,
                    periodYear: widget.periodYear,
                    onPeriodChanged: widget.onPeriodChanged,
                    periodSelectorEnabled: true,
                  ),
                ),
              if (widget.embedGreeting) const SizedBox(height: 12),

              if (hasAnyReceipts && receiptsInPeriod == 0)
                _NoPeriodSpendBanner(
                  month: widget.periodMonth,
                  year: widget.periodYear,
                  lang: lang,
                ),
              if (hasAnyReceipts && receiptsInPeriod == 0)
                const SizedBox(height: 12),

              if (pack != null)
                HomeBudgetSection(
                  insights: insights,
                  budgets: pack.budgets,
                  incomeEntries: pack.incomeEntries,
                  incomeTotal: pack.incomeTotal,
                  familyMembers: pack.familyMembers,
                  onEditIncome: () async {
                    await showIncomeEditorSheet(
                      context,
                      month: widget.periodMonth,
                      year: widget.periodYear,
                      initial: pack.incomeEntries,
                      onSaved: _reload,
                    );
                    _reload();
                  },
                ),
              if (pack != null) const SizedBox(height: 16),

              if (insights != null && hasAnyReceipts) ...[
                LastWeekSpendCard(insights: insights),
                if (_itemsLoading) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(minHeight: 2),
                ],
                const SizedBox(height: 16),
                if (insights.hasPeriodSpend) ...[
                  if (insights.inflationPct != null)
                    _InflationPill(inflationPct: insights.inflationPct!),
                  if (insights.inflationPct != null) const SizedBox(height: 12),
                  TopCategoryInsight(insights: insights),
                  const SizedBox(height: 12),
                  InsightStatGrid(insights: insights),
                  const SizedBox(height: 14),
                  _SectionHeader(
                    title: AppStrings.get('categories', lang),
                    subtitle: AppStrings.spentInMonth(
                      insights.periodMonth,
                      insights.periodYear,
                      lang,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CategoryDonutChart(insights: insights),
                  const SizedBox(height: 8),
                  CategorySpendList(
                    breakdown: insights.categoryBreakdown,
                    insights: insights,
                  ),
                  if (insights.topStores.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _SectionHeader(title: AppStrings.get('dash_top_stores', lang)),
                    const SizedBox(height: 4),
                    TopStoresSection(
                      stores: insights.topStores,
                      allStores: insights.allStores,
                    ),
                  ],
                  if (insights.topProductsByQuantity.isNotEmpty ||
                      insights.topProductsByValue.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _SectionHeader(title: AppStrings.get('dash_most_bought', lang)),
                    const SizedBox(height: 6),
                    MostBoughtInsights(
                      byQuantity: insights.topProductsByQuantity,
                      byValue: insights.topProductsByValue,
                      insights: insights,
                    ),
                  ],
                ],
                if (pack!.budgetAlerts.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _SectionHeader(title: AppStrings.get('budget_alerts', lang)),
                  const SizedBox(height: 8),
                  ...pack.budgetAlerts.map((b) => _BudgetAlertCard(budget: b)),
                ],
              ] else if (!hasAnyReceipts && pack?.noFamily != true)
                _EmptyHomePrompt(
                  familyMode: widget.scopeIndex == 1,
                  showAddButton: widget.scopeIndex == 0,
                  onScan: () => showAddReceiptSheet(context, onDone: () {
                    _reload();
                    widget.onGlobalRefresh();
                  }),
                )
              else if (snapshot.connectionState == ConnectionState.waiting &&
                  pack == null)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _FamilySetupPrompt extends StatelessWidget {
  final String lang;
  const _FamilySetupPrompt({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Text(
        AppStrings.familySetupHint(lang),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 15,
          height: 1.45,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _EmptyHomePrompt extends StatelessWidget {
  final VoidCallback? onScan;
  final bool familyMode;
  final bool showAddButton;
  const _EmptyHomePrompt({
    this.onScan,
    this.familyMode = false,
    this.showAddButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final lang = currentLanguage.value;
    final message = familyMode
        ? AppStrings.familyEmptyHint(lang)
        : AppStrings.get('scan_first_receipt', lang);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          const Icon(Icons.document_scanner_outlined,
              size: 48, color: Color(0xFF1B5E20)),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          if (showAddButton && onScan != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onScan,
              icon: const Icon(Icons.add),
              label: Text(AppStrings.get('add_receipt', lang)),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1B5E20)),
            ),
          ],
        ],
      ),
    );
  }
}

class _NoPeriodSpendBanner extends StatelessWidget {
  final int month;
  final int year;
  final String lang;
  const _NoPeriodSpendBanner({
    required this.month,
    required this.year,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade800, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${AppStrings.get('no_receipts_in_period', lang)} · ${AppStrings.spentInMonth(month, year, lang)}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InflationPill extends StatelessWidget {
  final double inflationPct;
  const _InflationPill({required this.inflationPct});

  @override
  Widget build(BuildContext context) {
    final lang = currentLanguage.value;
    final isPositive = inflationPct >= 0;
    final color = isPositive ? Colors.red.shade600 : Colors.green.shade600;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isPositive ? Icons.trending_up : Icons.trending_down, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            '${AppStrings.get('dash_inflation', lang)}: ${isPositive ? '+' : ''}${inflationPct.toStringAsFixed(1)}%',
            style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _SectionHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface)),
        if (subtitle != null)
          Text(subtitle!,
              style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _BudgetAlertCard extends StatelessWidget {
  final Budget budget;
  const _BudgetAlertCard({required this.budget});

  @override
  Widget build(BuildContext context) {
    final isOver = budget.isOverBudget;
    final color = isOver ? Colors.red.shade700 : Colors.orange.shade700;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(isOver ? Icons.warning_rounded : Icons.info_outline, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isOver
                  ? '${budget.categoryName ?? 'Budget'}: ${(budget.spent - budget.amount).toStringAsFixed(2)} AZN over'
                  : '${budget.categoryName ?? 'Budget'}: ${(budget.usedFraction * 100).toInt()}% used',
              style: TextStyle(color: color, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
