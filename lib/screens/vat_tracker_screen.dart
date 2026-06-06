// VAT TRACKER: Hidden — requires government ƏDV
// API integration. Do not delete.
// Re-enable when API is available.

// VAT TRACKER: Hidden — requires government ƏDV
// API integration. Do not delete.
// Re-enable when API is available.

import 'package:flutter/material.dart';
import '../services/supabase_access.dart';
import '../app_state.dart';
import '../l10n/app_strings.dart';
import '../config/app_colors.dart';

class VatTrackerScreen extends StatefulWidget {
  const VatTrackerScreen({super.key});

  @override
  State<VatTrackerScreen> createState() => _VatTrackerScreenState();
}

class _VatTrackerScreenState extends State<VatTrackerScreen> {
  List<_VatEntry> _entries = [];
  bool _loading = true;
  final Set<String> _claimed = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final supabase = SupabaseAccess.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        setState(() => _loading = false);
        return;
      }

      final rows = await supabase
          .from('receipts')
          .select('id, store_name, purchase_date, vat_amount, total_amount')
          .eq('user_id', userId)
          .gt('vat_amount', 0)
          .order('purchase_date', ascending: false);

      final entries = (rows as List).map((r) {
        return _VatEntry(
          id: r['id'] as String,
          store: r['store_name'] as String? ?? 'Unknown',
          date: DateTime.tryParse(r['purchase_date'] as String? ?? ''),
          vat: (r['vat_amount'] as num?)?.toDouble() ?? 0,
          total: (r['total_amount'] as num?)?.toDouble() ?? 0,
        );
      }).toList();

      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  double get _totalVat => _entries.fold(0.0, (s, e) => s + e.vat);
  double get _claimedVat =>
      _entries.where((e) => _claimed.contains(e.id)).fold(0.0, (s, e) => s + e.vat);
  double get _unclaimedVat => _totalVat - _claimedVat;

  @override
  Widget build(BuildContext context) {
    final unclaimed = _entries.where((e) => !_claimed.contains(e.id)).toList();
    final claimed = _entries.where((e) => _claimed.contains(e.id)).toList();

    return Scaffold(
      backgroundColor: AppColors.darkSurface,
      appBar: AppBar(
        title: Text(AppStrings.get('vat_tracker', currentLanguage.value), style: const TextStyle(fontWeight: FontWeight.bold)),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? _EmptyState()
              : RefreshIndicator(
                  onRefresh: () => _load(),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _SummaryCard(
                        total: _totalVat,
                        claimed: _claimedVat,
                        unclaimed: _unclaimedVat,
                      ),
                      const SizedBox(height: 16),
                      if (unclaimed.isNotEmpty) ...[
                        _Header(
                          title: AppStrings.get('unclaimed_vat', currentLanguage.value),
                          subtitle: '${unclaimed.length} receipts',
                        ),
                        const SizedBox(height: 8),
                        ...unclaimed.map(
                          (e) => _VatCard(
                            entry: e,
                            onClaim: () => setState(() => _claimed.add(e.id)),
                          ),
                        ),
                      ],
                      if (claimed.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _Header(
                          title: AppStrings.get('claimed', currentLanguage.value),
                          subtitle: '${claimed.length} receipts',
                          action: TextButton(
                            onPressed: () => setState(() => _claimed.clear()),
                            child: const Text('Clear', style: TextStyle(color: AppColors.darkOnSurfaceVariant)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...claimed.map((e) => _ClaimedCard(entry: e)),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _VatEntry {
  final String id;
  final String store;
  final DateTime? date;
  final double vat;
  final double total;

  _VatEntry({
    required this.id,
    required this.store,
    required this.date,
    required this.vat,
    required this.total,
  });
}

class _SummaryCard extends StatelessWidget {
  final double total;
  final double claimed;
  final double unclaimed;
  const _SummaryCard({required this.total, required this.claimed, required this.unclaimed});

  @override
  Widget build(BuildContext context) {
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
          Text(AppStrings.get('total_vat_paid', currentLanguage.value), style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            '${total.toStringAsFixed(2)} AZN',
            style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatChip(
                  label: AppStrings.get('unclaimed', currentLanguage.value),
                  value: '${unclaimed.toStringAsFixed(2)} AZN',
                  color: Colors.orange.shade200,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatChip(
                  label: AppStrings.get('claimed', currentLanguage.value),
                  value: '${claimed.toStringAsFixed(2)} AZN',
                  color: Colors.greenAccent.shade100,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 11)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  const _Header({required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkOnSurface)),
              if (subtitle != null)
                Text(subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.darkOnSurfaceVariant)),
            ],
          ),
        ),
        ?action,
      ],
    );
  }
}

class _VatCard extends StatelessWidget {
  final _VatEntry entry;
  final VoidCallback onClaim;
  const _VatCard({required this.entry, required this.onClaim});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.darkElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade900.withValues(alpha: 0.4)),
      ),
      child: ListTile(
        tileColor: Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.orange.shade900.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.receipt_long_outlined, color: Colors.orange.shade400, size: 20),
        ),
        title: Text(entry.store, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.darkOnSurface)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.date != null)
              Text(
                '${entry.date!.day.toString().padLeft(2, '0')}.${entry.date!.month.toString().padLeft(2, '0')}.${entry.date!.year}',
                style: const TextStyle(fontSize: 11, color: AppColors.darkOnSurfaceVariant),
              ),
            Text(
              'VAT: ${entry.vat.toStringAsFixed(2)} AZN',
              style: TextStyle(color: Colors.orange.shade400, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        trailing: TextButton(
          onPressed: onClaim,
          style: TextButton.styleFrom(
            backgroundColor: AppColors.primaryGreenDark.withValues(alpha: 0.2),
            foregroundColor: AppColors.green400,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
          child: const Text('Claim', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

class _ClaimedCard extends StatelessWidget {
  final _VatEntry entry;
  const _ClaimedCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.darkElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkOutline),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.primaryGreenDark, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              entry.store,
              style: const TextStyle(color: AppColors.darkOnSurfaceVariant, fontSize: 14, decoration: TextDecoration.lineThrough, decorationColor: AppColors.darkOnSurfaceVariant),
            ),
          ),
          Text(
            '${entry.vat.toStringAsFixed(2)} AZN',
            style: const TextStyle(color: AppColors.darkOnSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
            child: const Icon(Icons.receipt_long_outlined, size: 44, color: AppColors.primaryGreenDark),
          ),
          const SizedBox(height: 20),
          Text(AppStrings.get('no_vat_data', currentLanguage.value), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkOnSurface)),
          const SizedBox(height: 8),
          Text(
            AppStrings.get('vat_scan_hint', currentLanguage.value),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.darkOnSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
