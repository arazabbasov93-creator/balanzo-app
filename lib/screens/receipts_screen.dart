import 'package:flutter/material.dart';
import '../app_state.dart';
import '../l10n/app_strings.dart';
import '../services/receipt_service.dart';
import '../services/family_service.dart';
import '../models/receipt.dart';
import '../widgets/add_receipt_sheet.dart';
import '../widgets/family_blur_background.dart';
import 'receipt_detail_screen.dart';
import '../config/app_colors.dart';
import '../widgets/balanzo_header_styles.dart';
import '../utils/currency_data.dart';

class ReceiptsScreen extends StatefulWidget {
  final bool isActive;

  const ReceiptsScreen({super.key, this.isActive = true});

  @override
  State<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends State<ReceiptsScreen>
    with TickerProviderStateMixin {
  late TabController _tabCtrl;
  late AnimationController _noFamilyAnim;
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _hasFamily = false;

  List<Map<String, dynamic>> _personalRows = [];
  List<Map<String, dynamic>> _familyRows = [];
  bool _personalLoading = true;
  bool _familyLoading = true;
  bool _familyNoFamily = false;
  Object? _personalError;
  Object? _familyError;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _noFamilyAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _tabCtrl.addListener(_onTabChanged);
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text.toLowerCase()));
    currentLanguage.addListener(_onLangChange);
    receiptsRevision.addListener(_onReceiptsChanged);
    _refreshFamilyStatus();
    _loadPersonal();
  }

  @override
  void didUpdateWidget(ReceiptsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      _reloadVisibleTab();
    }
  }

  void _onTabChanged() {
    if (_tabCtrl.indexIsChanging) return;
    setState(() {});
    _reloadVisibleTab();
  }

  void _reloadVisibleTab() {
    if (_tabCtrl.index == 0) {
      _loadPersonal();
    } else {
      _loadFamily();
    }
  }

  Future<void> _refreshFamilyStatus() async {
    final family = await FamilyService.fetchMyFamily();
    if (mounted) setState(() => _hasFamily = family != null);
  }

  void _onLangChange() => setState(() {});

  void _onReceiptsChanged() => refresh();

  Future<void> refresh() async {
    await _refreshFamilyStatus();
    await Future.wait([_loadPersonal(), _loadFamily()]);
  }

  Future<void> _loadPersonal() async {
    if (!mounted) return;
    setState(() {
      _personalLoading = true;
      _personalError = null;
    });
    try {
      final rows = await ReceiptService.fetchAll(familyMode: false);
      if (mounted) {
        setState(() {
          _personalRows = rows;
          _personalLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _personalError = e;
          _personalLoading = false;
        });
      }
    }
  }

  Future<void> _loadFamily() async {
    if (!mounted) return;
    setState(() {
      _familyLoading = true;
      _familyError = null;
    });
    try {
      final family = await FamilyService.fetchMyFamily();
      if (family == null) {
        if (mounted) {
          setState(() {
            _familyRows = [];
            _familyNoFamily = true;
            _familyLoading = false;
          });
        }
        return;
      }
      final rows = await ReceiptService.fetchAll(familyMode: true);
      if (mounted) {
        setState(() {
          _familyRows = rows;
          _familyNoFamily = false;
          _familyLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _familyError = e;
          _familyLoading = false;
        });
      }
    }
  }

  bool get _canScanReceipt => _tabCtrl.index == 0 || _hasFamily;

  @override
  void dispose() {
    _tabCtrl.removeListener(_onTabChanged);
    currentLanguage.removeListener(_onLangChange);
    receiptsRevision.removeListener(_onReceiptsChanged);
    _tabCtrl.dispose();
    _noFamilyAnim.stop();
    _noFamilyAnim.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = currentLanguage.value;
    if (_familyNoFamily && !_noFamilyAnim.isAnimating) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _familyNoFamily && !_noFamilyAnim.isAnimating) {
          _noFamilyAnim.repeat(reverse: true);
        }
      });
    }
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: BalanzoHeaderStyles.toolbarHeight,
        title: Text(
          AppStrings.get('receipts', lang),
          style: BalanzoHeaderStyles.titleStyle.copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.primaryGreen(Theme.of(context).brightness),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          labelStyle: BalanzoHeaderStyles.tabLabelStyle,
          unselectedLabelStyle: BalanzoHeaderStyles.tabUnselectedLabelStyle,
          tabs: [
            Tab(text: AppStrings.get('tab_personal', lang)),
            Tab(text: AppStrings.get('tab_family', lang)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: TextField(
                  controller: _searchCtrl,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: AppStrings.get('search_receipts', lang),
                    hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 20),
                    suffixIcon: _query.isNotEmpty ? IconButton(
                      icon: Icon(Icons.clear, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 18),
                      onPressed: () => _searchCtrl.clear(),
                    ) : null,
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Expanded(child: _ReceiptListBody(
                rows: _personalRows,
                loading: _personalLoading,
                error: _personalError,
                noFamily: false,
                query: _query,
                familyMode: false,
                onRetry: _loadPersonal,
                onRefresh: refresh,
              )),
            ],
          ),
          Stack(
            fit: StackFit.expand,
            children: [
              _ReceiptListBody(
                rows: _familyRows,
                loading: _familyLoading,
                error: _familyError,
                noFamily: _familyNoFamily,
                query: _query,
                familyMode: true,
                onRetry: _loadFamily,
                onRefresh: refresh,
              ),
              if (_familyNoFamily)
                Positioned.fill(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FamilyBlurBackground(animation: _noFamilyAnim),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('👨‍👩‍👧',
                                  style: TextStyle(fontSize: 40)),
                              const SizedBox(height: 16),
                              Text(
                                AppStrings.familySetupHint(
                                    currentLanguage.value),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.45,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  shadows: [
                                    Shadow(
                                        color: Colors.black, blurRadius: 8),
                                    Shadow(
                                        color: Colors.black, blurRadius: 16),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      floatingActionButton: _canScanReceipt
          ? FloatingActionButton.extended(
              heroTag: 'fab_receipts_add_receipt',
              backgroundColor: AppColors.primaryGreen(Theme.of(context).brightness),
              onPressed: () => showAddReceiptSheet(context, onDone: refresh),
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                AppStrings.get('add_receipt', lang),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            )
          : null,
    );
  }
}

class _ReceiptListBody extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final bool loading;
  final Object? error;
  final bool noFamily;
  final String query;
  final bool familyMode;
  final VoidCallback onRetry;
  final Future<void> Function() onRefresh;

  const _ReceiptListBody({
    required this.rows,
    required this.loading,
    required this.error,
    required this.noFamily,
    required this.query,
    required this.familyMode,
    required this.onRetry,
    required this.onRefresh,
  });

  List<Map<String, dynamic>> _filtered() {
    if (query.isEmpty) return rows;
    return rows
        .where((r) =>
            (r['store_name'] as String? ?? '').toLowerCase().contains(query))
        .toList();
  }

  Map<String, List<Map<String, dynamic>>> _groupByDate(
      List<Map<String, dynamic>> list) {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final r in list) {
      final key = r['purchase_date'] as String? ?? '—';
      map.putIfAbsent(key, () => []).add(r);
    }
    final keys = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (final k in keys) k: map[k]!};
  }

  String _formatDateHeader(String dateStr) {
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    const months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'Yesterday';
    }
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} · ${months[date.month]}';
  }

  @override
  Widget build(BuildContext context) {
    if (loading && rows.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && rows.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text(
              AppStrings.get('failed_to_load', currentLanguage.value),
              style: const TextStyle(color: AppColors.darkOnSurfaceVariant),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: Text(AppStrings.get('retry', currentLanguage.value)),
            ),
          ],
        ),
      );
    }
    final filtered = _filtered();
    if (filtered.isEmpty) {
      return _EmptyState(
        hasSearch: query.isNotEmpty,
        lang: currentLanguage.value,
        familyMode: familyMode,
      );
    }
    final grouped = _groupByDate(filtered);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: Stack(
        children: [
          ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
            itemCount: grouped.length,
            itemBuilder: (context, sectionIndex) {
              final dateKey = grouped.keys.elementAt(sectionIndex);
              final sectionRows = grouped[dateKey]!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    child: Text(
                      _formatDateHeader(dateKey),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  ...sectionRows.map(
                    (r) => _ReceiptCard(
                      row: r,
                      onDeleted: () => onRefresh(),
                    ),
                  ),
                ],
              );
            },
          ),
          if (loading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasSearch;
  final String lang;
  final bool familyMode;

  const _EmptyState({
    this.hasSearch = false,
    this.lang = 'en',
    this.familyMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final scopeLabel = familyMode
        ? (lang == 'az'
            ? 'ailə'
            : lang == 'ru'
                ? 'семейных'
                : 'family')
        : (lang == 'az'
            ? 'şəxsi'
            : lang == 'ru'
                ? 'личных'
                : 'personal');
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.tintSurfaceDark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              hasSearch ? Icons.search_off : Icons.receipt_long,
              size: 44,
              color: AppColors.primaryGreenDark,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            hasSearch
                ? AppStrings.get('no_receipts_yet', lang)
                : 'No $scopeLabel receipts yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.get('scan_to_start', lang),
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onDeleted;

  const _ReceiptCard({required this.row, required this.onDeleted});

  @override
  Widget build(BuildContext context) {
    final store = row['store_name'] as String? ?? 'Unknown Store';
    final total = (row['total_amount'] as num?)?.toDouble() ?? 0.0;
    final currency = row['currency'] as String?;
    final dateStr = row['purchase_date'] as String?;
    final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
    final id = row['id'] as String;
    final fiscalId = row['fiscal_id'] as String?;

    final receipt = Receipt(
      store: store,
      date: date,
      items: const [],
      subtotal: total,
      vat: (row['vat_amount'] as num?)?.toDouble() ?? 0.0,
      total: total,
      currency: currency,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(
              builder: (_) =>
                  ReceiptDetailScreen(receiptId: id, receipt: receipt),
            ))
            .then((_) => onDeleted()),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.green100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: AppColors.primaryGreenDark,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (fiscalId != null && fiscalId.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.verified_outlined,
                              size: 12,
                              color: AppColors.primaryGreenDark,
                            ),
                            const SizedBox(width: 4),
                            const Expanded(
                              child: Text(
                                'e-kassa',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.primaryGreenDark,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                formatMoney(total, currency),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreenDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
