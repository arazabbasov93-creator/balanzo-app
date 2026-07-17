import 'package:flutter/material.dart';
import '../app_state.dart';
import '../l10n/app_strings.dart';
import '../config/app_colors.dart';
import '../services/support_service.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  late Future<List<Map<String, dynamic>>> _reportsFuture;

  @override
  void initState() {
    super.initState();
    _reportsFuture = SupportService.fetchMyReports();
  }

  void _refresh() => setState(() => _reportsFuture = SupportService.fetchMyReports());

  String _statusLabel(String status, String lang) {
    if (status == 'resolved') {
      return AppStrings.get('support_status_resolved', lang);
    }
    return AppStrings.get('support_status_open', lang);
  }

  String _formatTimestamp(String? raw) {
    if (raw == null) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final local = dt.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$d.$m.${local.year} $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    final lang = currentLanguage.value;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          AppStrings.get('support', lang),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryGreen(Theme.of(context).brightness),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _reportsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    '${snapshot.error}',
                    style: TextStyle(color: cs.error),
                  ),
                ],
              );
            }
            final reports = snapshot.data ?? [];
            if (reports.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  Icon(
                    Icons.support_agent,
                    size: 56,
                    color: AppColors.primaryGreenDark,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppStrings.get('support_intro', lang),
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    AppStrings.get('support_no_reports', lang),
                    style: TextStyle(
                      fontSize: 14,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: reports.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final report = reports[index];
                final status = report['status'] as String? ?? 'open';
                final isResolved = status == 'resolved';
                final seq = (report['sequence_number'] as num?)?.toInt();
                final description = report['description'] as String? ?? '';
                final snippet = description.length > 120
                    ? '${description.substring(0, 120)}…'
                    : description;

                return Material(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _showReportDetail(context, report, lang),
                    child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: cs.outlineVariant),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: isResolved
                                    ? cs.primaryContainer
                                    : Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _statusLabel(status, lang),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isResolved
                                      ? cs.onPrimaryContainer
                                      : Colors.orange.shade900,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _formatTimestamp(report['created_at'] as String?),
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        if (seq != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${AppStrings.get('receipt_number', lang)}$seq',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                          ),
                        ],
                        if (snippet.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            snippet,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showReportDetail(
    BuildContext context,
    Map<String, dynamic> report,
    String lang,
  ) {
    final cs = Theme.of(context).colorScheme;
    final status = report['status'] as String? ?? 'open';
    final seq = (report['sequence_number'] as num?)?.toInt();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.get('support_detail_title', lang)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _statusLabel(status, lang),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: status == 'resolved' ? cs.primary : Colors.orange.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _formatTimestamp(report['created_at'] as String?),
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
              if (seq != null) ...[
                const SizedBox(height: 12),
                Text(
                  '${AppStrings.get('receipt_number', lang)}$seq',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                report['description'] as String? ?? '',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.get('cancel', lang)),
          ),
        ],
      ),
    );
  }
}
