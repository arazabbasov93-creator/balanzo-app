import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../services/receipt_service.dart';
import '../config/app_colors.dart';

class ShareScreen extends StatefulWidget {
  const ShareScreen({super.key});

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  final _controller = ScreenshotController();
  int _selectedCard = 0;
  double _totalSpend = 0;
  // VAT TRACKER: Hidden — requires government ƏDV
  // API integration. Do not delete.
  // Re-enable when API is available.
  // double _totalVat = 0;
  int _receiptCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final rows = await ReceiptService.monthlySummary();
      final now = DateTime.now();
      double spend = 0;
      int count = 0;
      for (final r in rows) {
        final dateStr = r['purchase_date'] as String?;
        final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
        if (date != null && date.year == now.year && date.month == now.month) {
          spend += (r['total_amount'] as num?)?.toDouble() ?? 0;
          count++;
        }
      }
      if (!mounted) return;
      setState(() {
        _totalSpend = spend;
        _receiptCount = count;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _shareCard() async {
    final bytes = await _controller.capture();
    if (bytes == null) return;
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/balanzo_share.png';
    final file = File(path);
    await file.writeAsBytes(bytes);
    final xfile = XFile(path);
    await Share.shareXFiles([xfile], subject: 'Balanzo Stats');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.scaffoldDark : AppColors.scaffoldLight,
      appBar: AppBar(
        title: const Text('Share Stats', style: TextStyle(fontWeight: FontWeight.bold)),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const SizedBox(height: 16),
                // Card selector
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _Chip(label: 'Monthly Spend', selected: _selectedCard == 0, onTap: () => setState(() => _selectedCard = 0)),
                      const SizedBox(width: 8),
                      // VAT TRACKER: Hidden — requires government ƏDV
                      // API integration. Do not delete.
                      // Re-enable when API is available.
                      // _Chip(label: 'VAT Savings', selected: _selectedCard == 1, onTap: () => setState(() => _selectedCard = 1)),
                      // const SizedBox(width: 8),
                      _Chip(label: 'Inflation Impact', selected: _selectedCard == 1, onTap: () => setState(() => _selectedCard = 1)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Preview card
                Screenshot(
                  controller: _controller,
                  child: _buildCard(),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _shareCard,
                          icon: const Icon(Icons.share),
                          label: const Text('Share'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen(
                              Theme.of(context).brightness,
                            ),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCard() {
    switch (_selectedCard) {
      // VAT TRACKER: Hidden — requires government ƏDV
      // API integration. Do not delete.
      // Re-enable when API is available.
      // case 1:
      //   return _VatCard(vatAmount: _totalVat);
      case 1:
        return _InflationCard(receiptCount: _receiptCount, totalSpend: _totalSpend);
      default:
        return _MonthlySpendCard(total: _totalSpend, receiptCount: _receiptCount);
    }
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryGreenDark : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryGreenDark),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.primaryGreenDark,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// T105: Monthly Spend Card
class _MonthlySpendCard extends StatelessWidget {
  final double total;
  final int receiptCount;
  const _MonthlySpendCard({required this.total, required this.receiptCount});

  @override
  Widget build(BuildContext context) {
    final month = _currentMonth();
    return Container(
      width: 320,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryGreen(Theme.of(context).brightness),
            AppColors.gradientEnd(Theme.of(context).brightness),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('BALANZO', style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                child: const Text('Monthly Spend', style: TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(month, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            '${total.toStringAsFixed(2)} â‚¼',
            style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(height: 8),
          Text('$receiptCount receipts tracked', style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }
}

// VAT TRACKER: Hidden — requires government ƏDV
// API integration. Do not delete.
// Re-enable when API is available.
// T106: VAT Savings Card
/*
class _VatCard extends StatelessWidget {
  final double vatAmount;
  const _VatCard({required this.vatAmount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryGreen(Theme.of(context).brightness),
            AppColors.gradientEnd(Theme.of(context).brightness),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('BALANZO', style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                child: const Text('VAT Tracked', style: TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('VAT on receipts this month', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            '${vatAmount.toStringAsFixed(2)} â‚¼',
            style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(height: 8),
          const Text('Tracked automatically by Balanzo', style: TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }
}
*/

// T104: Inflation Impact Card
class _InflationCard extends StatelessWidget {
  final int receiptCount;
  final double totalSpend;
  const _InflationCard({required this.receiptCount, required this.totalSpend});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryGreen(Theme.of(context).brightness),
            AppColors.gradientEnd(Theme.of(context).brightness),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('BALANZO', style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                child: const Text('Inflation Tracker', style: TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Spending tracked this month', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            '${totalSpend.toStringAsFixed(2)} â‚¼',
            style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(height: 8),
          Text('Across $receiptCount scanned receipts Â· Balanzo', style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }
}

String _currentMonth() {
  final now = DateTime.now();
  const months = ['January', 'February', 'March', 'April', 'May', 'June',
                  'July', 'August', 'September', 'October', 'November', 'December'];
  return '${months[now.month - 1]} ${now.year}';
}
