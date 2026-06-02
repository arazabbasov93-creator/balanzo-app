import 'package:flutter/material.dart';
import '../services/receipt_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late Future<_AnalyticsData> _future;
  int _monthsBack = 6; // mutable — changed by dropdown

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_AnalyticsData> _load() async {
    final rows = await ReceiptService.fetchAll();
    final now = DateTime.now();

    // Build monthly totals for the last N months
    final Map<String, double> monthlyTotals = {};
    double allTime = 0;
    int totalCount = rows.length;

    for (int i = _monthsBack - 1; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i);
      final key = '${_monthShort(month.month)} ${month.year}';
      monthlyTotals[key] = 0;
    }

    for (final r in rows) {
      final dateStr = r['date'] as String?;
      final total = (r['total'] as num?)?.toDouble() ?? 0.0;
      allTime += total;
      if (dateStr != null) {
        final date = DateTime.tryParse(dateStr);
        if (date != null) {
          final key = '${_monthShort(date.month)} ${date.year}';
          if (monthlyTotals.containsKey(key)) {
            monthlyTotals[key] = (monthlyTotals[key] ?? 0) + total;
          }
        }
      }
    }

    return _AnalyticsData(
      monthlyTotals: monthlyTotals,
      allTimeTotal: allTime,
      totalCount: totalCount,
    );
  }

  String _monthShort(int m) =>
      ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
       'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<_AnalyticsData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SummaryCards(data: data),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Monthly Spending',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  DropdownButton<int>(
                    value: _monthsBack,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 3, child: Text('3 months')),
                      DropdownMenuItem(value: 6, child: Text('6 months')),
                      DropdownMenuItem(value: 12, child: Text('12 months')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _monthsBack = v;
                          _future = _load();
                        });
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _BarChart(monthlyTotals: data.monthlyTotals),
            ],
          );
        },
      ),
    );
  }
}

class _AnalyticsData {
  final Map<String, double> monthlyTotals;
  final double allTimeTotal;
  final int totalCount;
  _AnalyticsData({
    required this.monthlyTotals,
    required this.allTimeTotal,
    required this.totalCount,
  });
}

class _SummaryCards extends StatelessWidget {
  final _AnalyticsData data;
  const _SummaryCards({required this.data});

  @override
  Widget build(BuildContext context) {
    final avg = data.totalCount > 0 ? data.allTimeTotal / data.totalCount : 0.0;
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: 'All Time Spent',
            value: '${data.allTimeTotal.toStringAsFixed(2)} AZN',
            icon: Icons.account_balance_wallet_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            label: 'Avg per Receipt',
            value: '${avg.toStringAsFixed(2)} AZN',
            icon: Icons.receipt_outlined,
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _MetricCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF1B5E20), size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
        ],
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  final Map<String, double> monthlyTotals;
  const _BarChart({required this.monthlyTotals});

  @override
  Widget build(BuildContext context) {
    final maxVal = monthlyTotals.values.fold(0.0, (a, b) => a > b ? a : b);
    if (maxVal == 0) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No data yet', style: TextStyle(color: Colors.black54)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: monthlyTotals.entries.map((e) {
                final fraction = maxVal > 0 ? e.value / maxVal : 0.0;
                final isCurrentMonth = e.key == monthlyTotals.keys.last;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (e.value > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              e.value.toStringAsFixed(0),
                              style: const TextStyle(fontSize: 9, color: Colors.black54),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          height: (fraction * 120).clamp(4.0, 120.0),
                          decoration: BoxDecoration(
                            color: isCurrentMonth
                                ? const Color(0xFF1B5E20)
                                : const Color(0xFF81C784),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: monthlyTotals.keys
                .map(
                  (k) => Expanded(
                    child: Text(
                      k.split(' ').first,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        color: k == monthlyTotals.keys.last
                            ? const Color(0xFF1B5E20)
                            : Colors.black54,
                        fontWeight: k == monthlyTotals.keys.last
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
