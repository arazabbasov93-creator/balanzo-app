import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app_state.dart';
import '../../l10n/app_strings.dart';
import '../../models/budget.dart';
import '../../models/family.dart';
import '../../models/family_period_summary.dart';
import '../../models/home_insights.dart';
import '../../models/income.dart';
import '../../services/auth_service.dart';
import '../../services/budget_service.dart';
import '../../services/family_preferences.dart';
import '../../services/family_service.dart';
import '../../services/home_data_cache.dart';
import '../../services/income_service.dart';
import '../../services/notification_service.dart';
import '../../services/receipt_service.dart';
import '../../widgets/family_budget_header_card.dart';
import '../../widgets/add_receipt_sheet.dart';
import '../../widgets/family_blur_background.dart';
import 'home_greeting_card.dart';
import 'category_donut_chart.dart';
import 'home_budget_section.dart';
import 'home_insight_sections.dart';
import 'insight_stat_grid.dart';
import 'last_week_spend_card.dart';
import '../../config/app_colors.dart';
import '../../utils/currency_data.dart';

typedef HomeScopeData = ({
  HomeInsights? insights,
  List<Budget> budgets,
  List<Budget> budgetAlerts,
  bool noFamily,
  List<IncomeEntry> incomeEntries,
  double incomeTotal,
  List<MemberMonthSummary>? familyMembers,
  Family? family,
  FamilyPeriodSummary? familyPeriodSummary,
});

typedef HomeHeaderSnapshot = ({
  HomeInsights? insights,
  double incomeTotal,
  String? cachedName,
  bool periodSelectorEnabled,
  bool noFamily,
  String? familyName,
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
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  Future<HomeScopeData> _future = Future.value((
        insights: null as HomeInsights?,
        budgets: <Budget>[],
        budgetAlerts: <Budget>[],
        noFamily: false,
        incomeEntries: <IncomeEntry>[],
        incomeTotal: 0.0,
        familyMembers: null as List<MemberMonthSummary>?,
        family: null as Family?,
        familyPeriodSummary: null as FamilyPeriodSummary?,
      ));
  HomeScopeData? _cached;
  bool _itemsLoading = false;
  bool _startedLoad = false;
  bool _monthlySummaryChecked = false;
  bool _sharePersonalBudget = false;
  HomeHeaderSnapshot? _lastHeaderPublished;
  late AnimationController _blurAnim;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _blurAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    currentLanguage.addListener(_onLangChange);
    receiptsRevision.addListener(_onReceiptsChanged);
    _loadSharePref();
    if (widget.isActive) _startLoad();
  }

  Future<void> _loadSharePref() async {
    final share = await FamilyPreferences.sharePersonalBudgetWithFamily();
    if (mounted) setState(() => _sharePersonalBudget = share);
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
    setState(() {
      _future = _load(force: force);
    });
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
          budgets: const [],
          budgetAlerts: const [],
          noFamily: _cached?.noFamily ?? false,
          incomeEntries: const [],
          incomeTotal: 0.0,
          familyMembers: _cached?.familyMembers,
          family: _cached?.family,
          familyPeriodSummary: _cached?.familyPeriodSummary,
        );
      });
      _publishHeader(_cached, instant);
    }
    final pack = await _loadAuxiliary(
      month: widget.periodMonth,
      year: widget.periodYear,
      familyMode: familyMode,
      insights: instant,
    );
    if (mounted) {
      setState(() => _cached = pack);
      _maybeSendMonthlySummary(pack);
    }
  }

  Future<void> _maybeSendMonthlySummary(HomeScopeData pack) async {
    if (_monthlySummaryChecked || widget.scopeIndex != 0) return;
    _monthlySummaryChecked = true;
    final insights = pack.insights;
    if (insights == null) return;
    final now = DateTime.now();
    if (widget.periodMonth != now.month || widget.periodYear != now.year) {
      return;
    }
    try {
      final prevMonth = now.month == 1 ? 12 : now.month - 1;
      final prevYear = now.month == 1 ? now.year - 1 : now.year;
      final key = '$prevYear-${prevMonth.toString().padLeft(2, '0')}';
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString('last_monthly_summary_sent') == key) return;
      if (insights.lastMonthTotal <= 0 && insights.receiptsLastMonth <= 0) return;
      await NotificationService.sendMonthlySummary(
        total: insights.lastMonthTotal,
        receiptCount: insights.receiptsLastMonth,
      );
      await prefs.setString('last_monthly_summary_sent', key);
    } catch (e, st) {
      debugPrint('[HomeScope] monthly summary notification skipped: $e\n$st');
    }
  }

  @override
  void dispose() {
    _blurAnim.stop();
    _blurAnim.dispose();
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
        incomeTotal: 0.0,
        familyMembers: null as List<MemberMonthSummary>?,
        family: null as Family?,
        familyPeriodSummary: null as FamilyPeriodSummary?,
      );
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
          incomeTotal: 0.0,
          familyMembers: null as List<MemberMonthSummary>?,
          family: null as Family?,
          familyPeriodSummary: null as FamilyPeriodSummary?,
        );
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
          incomeTotal: _cached?.incomeTotal ?? 0.0,
          familyMembers: _cached?.familyMembers,
          family: _cached?.family,
          familyPeriodSummary: _cached?.familyPeriodSummary,
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

    final pack = await _loadAuxiliary(
      month: month,
      year: year,
      familyMode: familyMode,
      insights: insights,
    );
    if (mounted) _maybeSendMonthlySummary(pack);
    if (mounted) {
      setState(() => _cached = pack);
      _publishHeader(pack, insights);
    }
    return pack;
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
    FamilyPeriodSummary? familyPeriodSummary;

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
          familyMembers.add(MemberMonthSummary(
            userId: m.userId,
            displayName: m.displayName,
            income: 0,
            spend: spend,
            spendLimit: m.spendLimit,
          ));
          if (m.role == 'member' &&
              m.spendLimit != null &&
              spend > m.spendLimit! &&
              family.createdBy == AuthService.currentUser?.id) {
            try {
              final prefs = await SharedPreferences.getInstance();
              final alertKey =
                  'family_budget_alert_${m.userId}_${year}_${month.toString().padLeft(2, '0')}';
              if (prefs.getBool(alertKey) != true) {
                await NotificationService.sendFamilyBudgetAlert(
                  memberName: m.displayName,
                  overspend: spend - m.spendLimit!,
                );
                await prefs.setBool(alertKey, true);
              }
            } catch (e, st) {
              debugPrint('[HomeScope] family budget alert skipped: $e\n$st');
            }
          }
        }
        familyPeriodSummary = await FamilyService.fetchFamilyPeriodSummary(
          familyId: family.id,
          familyName: family.name,
          month: month,
          year: year,
        );
        if (await FamilyPreferences.sharePersonalBudgetWithFamily()) {
          incomeEntries = await IncomeService.fetchForMonth(month, year);
          incomeTotal = incomeEntries.fold<double>(0, (s, e) => s + e.amount);
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
      familyPeriodSummary: familyPeriodSummary,
    );
  }

  void _publishHeader(HomeScopeData? pack, HomeInsights? insights) {
    if (widget.onHeaderUpdate == null) return;
    final snapshot = (
      insights: insights,
      incomeTotal: pack?.incomeTotal ?? 0,
      cachedName: insights?.fullName ?? cachedDisplayName.value,
      periodSelectorEnabled: pack?.noFamily != true,
      noFamily: pack?.noFamily == true,
      familyName: widget.scopeIndex == 1 ? pack?.family?.name : null,
    );
    if (_lastHeaderPublished != null &&
        _lastHeaderPublished!.insights == snapshot.insights &&
        _lastHeaderPublished!.incomeTotal == snapshot.incomeTotal &&
        _lastHeaderPublished!.cachedName == snapshot.cachedName &&
        _lastHeaderPublished!.periodSelectorEnabled == snapshot.periodSelectorEnabled &&
        _lastHeaderPublished!.noFamily == snapshot.noFamily &&
        _lastHeaderPublished!.familyName == snapshot.familyName) {
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
        final pack = _cached;
        final noFamily = pack?.noFamily == true;
        if (noFamily && !_blurAnim.isAnimating) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _cached?.noFamily == true && !_blurAnim.isAnimating) {
              _blurAnim.repeat(reverse: true);
            }
          });
        }
        final insights = pack?.insights;

        final receiptsInPeriod = insights?.receiptsThisMonth ?? 0;
        final hasAnyReceipts = (insights?.totalReceiptsInScope ?? 0) > 0;

        return Stack(
          fit: StackFit.expand,
          children: [
            RefreshIndicator(
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
                        familyName: widget.scopeIndex == 1 ? pack?.family?.name : null,
                        periodMonth: widget.periodMonth,
                        periodYear: widget.periodYear,
                        onPeriodChanged: widget.onPeriodChanged,
                        periodSelectorEnabled: true,
                        hidePersonalFinance: widget.scopeIndex == 1,
                      ),
                    ),
                  if (widget.embedGreeting) const SizedBox(height: 12),

                  if (widget.scopeIndex == 1 &&
                      pack?.familyPeriodSummary != null &&
                      !noFamily) ...[
                    FamilyBudgetHeaderCard(
                      summary: pack!.familyPeriodSummary!,
                      onPeriodChanged: widget.onPeriodChanged,
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (hasAnyReceipts && receiptsInPeriod == 0 && widget.scopeIndex == 0)
                    _NoPeriodSpendBanner(
                      month: widget.periodMonth,
                      year: widget.periodYear,
                      lang: lang,
                    ),
                  if (hasAnyReceipts && receiptsInPeriod == 0 && widget.scopeIndex == 0)
                    const SizedBox(height: 12),

                  if (pack != null && !noFamily && widget.scopeIndex == 0)
                    HomeBudgetSection(
                      insights: insights,
                      budgets: pack.budgets,
                      incomeEntries: pack.incomeEntries,
                      incomeTotal: pack.incomeTotal,
                      familyMembers: null,
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
                  if (pack != null &&
                      !noFamily &&
                      widget.scopeIndex == 1 &&
                      _sharePersonalBudget) ...[
                    HomeBudgetSection(
                      insights: insights,
                      budgets: const [],
                      incomeEntries: pack.incomeEntries,
                      incomeTotal: pack.incomeTotal,
                      familyMembers: null,
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
                    const SizedBox(height: 16),
                  ],
                  if (pack != null && !noFamily && widget.scopeIndex == 0)
                    const SizedBox(height: 16),

                  if (widget.scopeIndex == 1 &&
                      pack != null &&
                      !noFamily &&
                      pack.familyMembers != null &&
                      pack.familyMembers!.isNotEmpty) ...[
                    _SectionHeader(title: AppStrings.get('family_members', lang)),
                    const SizedBox(height: 8),
                    ...pack.familyMembers!.map(
                      (m) => _FamilyMemberRow(
                        member: m,
                        currency: insights?.periodCurrency,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (insights != null &&
                      hasAnyReceipts &&
                      !noFamily &&
                      widget.scopeIndex == 0) ...[
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
                          periodCurrency: insights.periodCurrency,
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
                  ] else if (!hasAnyReceipts && !noFamily)
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
            ),
            if (noFamily)
              Positioned.fill(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    FamilyBlurBackground(animation: _blurAnim),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: _FamilySetupPrompt(lang: lang),
                      ),
                    ),
                  ],
                ),
              ),
          ],
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('👨‍👩‍👧', style: TextStyle(fontSize: 40)),
        const SizedBox(height: 16),
        Text(
          AppStrings.familySetupHint(lang),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            height: 1.45,
            color: Colors.white,
            fontWeight: FontWeight.w600,
            shadows: const [
              Shadow(color: Colors.black, blurRadius: 8),
              Shadow(color: Colors.black, blurRadius: 16),
            ],
          ),
        ),
      ],
    );
  }
}

class _FamilyMemberRow extends StatelessWidget {
  final MemberMonthSummary member;
  final String? currency;

  const _FamilyMemberRow({required this.member, this.currency});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              member.displayName,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${AppStrings.get('family_member_spend', currentLanguage.value)}: ${formatMoney(member.spend, currency)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (member.spendLimit != null)
                Text(
                  '${AppStrings.get('family_member_limit', currentLanguage.value)}: ${formatMoney(member.spendLimit!, currency)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
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
          Icon(Icons.document_scanner_outlined,
              size: 48, color: AppColors.primaryGreen(Theme.of(context).brightness)),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          if (showAddButton && onScan != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onScan,
              icon: const Icon(Icons.add),
              label: Text(AppStrings.get('add_receipt', lang)),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primaryGreen(Theme.of(context).brightness)),
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
