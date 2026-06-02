import 'package:flutter/material.dart';
import '../app_state.dart';
import '../l10n/app_strings.dart';
import '../services/receipt_service.dart';
import '../models/receipt.dart';
import '../widgets/add_receipt_sheet.dart';
import 'receipt_detail_screen.dart';

class ReceiptsScreen extends StatefulWidget {
  const ReceiptsScreen({super.key});

  @override
  State<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends State<ReceiptsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  String _query = '';
  int _refreshTick = 0;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text.toLowerCase()));
    currentLanguage.addListener(_onLangChange);
  }

  void _onLangChange() => setState(() {});

  void refresh() => setState(() => _refreshTick++);

  @override
  void dispose() {
    currentLanguage.removeListener(_onLangChange);
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  String _personalLabel(String lang) {
    switch (lang) {
      case 'az':
        return 'Şəxsi';
      case 'ru':
        return 'Личные';
      default:
        return 'Personal';
    }
  }

  String _familyLabel(String lang) {
    switch (lang) {
      case 'az':
        return 'Ailə';
      case 'ru':
        return 'Семья';
      default:
        return 'Family';
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = currentLanguage.value;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          AppStrings.get('receipts', lang),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Column(
            children: [
              TabBar(
                controller: _tabCtrl,
                labelColor: const Color(0xFF1B5E20),
                unselectedLabelColor:
                    Theme.of(context).colorScheme.onSurfaceVariant,
                indicatorColor: const Color(0xFF1B5E20),
                tabs: [
                  Tab(text: _personalLabel(lang)),
                  Tab(text: _familyLabel(lang)),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                child: TextField(
                  controller: _searchCtrl,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: AppStrings.get('search_receipts', lang),
                    hintStyle: TextStyle(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant),
                    prefixIcon: Icon(Icons.search,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                        size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                size: 18),
                            onPressed: () => _searchCtrl.clear(),
                          )
                        : null,
                    filled: true,
                    fillColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _ReceiptListTab(
            familyMode: false,
            query: _query,
            refreshTick: _refreshTick,
            onRefresh: refresh,
          ),
          _ReceiptListTab(
            familyMode: true,
            query: _query,
            refreshTick: _refreshTick,
            onRefresh: refresh,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddReceiptSheet(context, onDone: refresh),
        backgroundColor: const Color(0xFF1B5E20),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          AppStrings.get('add_receipt', lang),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _ReceiptListTab extends StatelessWidget {
  final bool familyMode;
  final String query;
  final int refreshTick;
  final VoidCallback onRefresh;

  const _ReceiptListTab({
    required this.familyMode,
    required this.query,
    required this.refreshTick,
    required this.onRefresh,
  });

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> rows) {
    if (query.isEmpty) return rows;
    return rows
        .where((r) =>
            (r['store_name'] as String? ?? '').toLowerCase().contains(query))
        .toList();
  }

  Map<String, List<Map<String, dynamic>>> _groupByDate(
      List<Map<String, dynamic>> rows) {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final r in rows) {
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
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ValueKey('$familyMode-$refreshTick'),
      future: ReceiptService.fetchAll(familyMode: familyMode),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline,
                    size: 48, color: Colors.red.shade300),
                const SizedBox(height: 12),
                Text(
                  AppStrings.get('failed_to_load', currentLanguage.value),
                  style: const TextStyle(color: Color(0xFF8888A0)),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: onRefresh,
                  child: Text(
                      AppStrings.get('retry', currentLanguage.value)),
                ),
              ],
            ),
          );
        }
        final rows = _filtered(snapshot.data ?? []);
        if (rows.isEmpty) {
          return _EmptyState(
            hasSearch: query.isNotEmpty,
            lang: currentLanguage.value,
            familyMode: familyMode,
          );
        }
        final grouped = _groupByDate(rows);
        return RefreshIndicator(
          onRefresh: () async => onRefresh(),
          child: ListView.builder(
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
                    (r) => _ReceiptCard(row: r, onDeleted: onRefresh),
                  ),
                ],
              );
            },
          ),
        );
      },
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
              color: const Color(0xFF1E2F1E),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              hasSearch ? Icons.search_off : Icons.receipt_long,
              size: 44,
              color: const Color(0xFF1B5E20),
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
    const currency = 'AZN';
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
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
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
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: Color(0xFF1B5E20),
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
                              color: Color(0xFF1B5E20),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'e-kassa',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF1B5E20),
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
                '${total.toStringAsFixed(2)} $currency',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B5E20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
